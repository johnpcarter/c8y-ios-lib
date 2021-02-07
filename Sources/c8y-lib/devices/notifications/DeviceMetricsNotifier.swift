//
//  DeviceMetricsNotifier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 05/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yDeviceMetricsNotifier {
	
	var deviceWrapper: C8yMutableDevice? = nil {
		didSet {
			self._primaryMeasurementInterval = Double(self.deviceWrapper!.device.requiredResponseInterval == nil ? 60 : self.deviceWrapper!.device.requiredResponseInterval! * 60)
		}
	}
		
	private var _monitorPublisher: CurrentValueSubject<Measurement, Never>?

	private var _loadBatteryAndPrimaryMetricValuesDONE: Bool = false
	private var _preferredMetric: String? = nil
	
	private var _primaryMeasurementInterval: TimeInterval = -1
	private var _attempts: Int = 0
	private var _disableBatteryFetcher: Bool = false
	
	private var _deviceMetricsTimer: JcRepeatingTimer?
	private var _cancellable: [AnyCancellable] = []

	init() {
		
	}
	
	deinit {
		self.stopMonitoring()
	}
	
	func reload(_ deviceWrapper: C8yMutableDevice) {
		
		self.deviceWrapper = deviceWrapper
		
		self.updateMetricsForToday()
	}
	
	/**
	Fetches latest device metrics, views will be updated automatically via published  attribute `measurements`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
	func updateMetricsForToday() {
		
		if (self.deviceWrapper == nil) {
			return
		}
		
		self.fetchAllMetricsForToday()
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { (completion) in
				
				self.deviceWrapper!.reloadMetrics = false
				
				switch completion {
				case .failure(let error):
					print("failed due to \(error)")
				default:
					print("done")
				}
				
			}, receiveValue: { results in
				self.deviceWrapper!.measurements = results
		}))
	}
	
	/**
	Stops the background thread for the preferred metric refresh and operation history. The thread must have been started by either `startMonitorForPrimaryMetric(_:refreshInterval)` or
	`primaryMetricPublisher(preferredMetric:refreshInterval:)`
	*/
	public func stopMonitoring() {
		
		if (self._deviceMetricsTimer != nil) {
			
			if (self._monitorPublisher != nil) {
				self._monitorPublisher!.send(completion: .finished)
			}
			
			for c in self._cancellable {
				c.cancel()
			}
			
			self._deviceMetricsTimer?.suspend()
		}
	}
	
	/**
	Provides a publisher that can be used to listen for periodic updates to primary metric
	The refresh is based on the devices `C8yDevice.requiredResponseInterval` property
	
	- parameter preferredMetric: label of the measurement to periodically fetched requires both name and series separated by a dot '.' e.g. 'Temperature.T'
	- parameter autoRefresh: set to true if you want the value to be refreshed automatically, false to only update once
	- returns: Publisher that will issue updated metrics periodically
	*/
	public func primaryMetricPublisher(preferredMetric: String?, autoRefresh: Bool = false) -> AnyPublisher<Measurement, Never> {
		
		let value = preferredMetric != nil ? self.deviceWrapper!.device.wrappedManagedObject.properties[preferredMetric!] : nil
		
		if (value != nil && value is C8yStringCustomAsset) {
			
			// latest metric is included in c8y managed object, use it!
			
			let v: String = (value as! C8yStringCustomAsset).value
			let t = self.deviceWrapper!.model.operationTemplate(for: preferredMetric!)
			
			return Just(Measurement(value: v, unit: t.uom ?? "", label: t.label ?? "", type: preferredMetric!)).eraseToAnyPublisher()
		} else if (value != nil && value is C8yDoubleCustomAsset) {
			
			// latest metric is included in c8y managed object, use it!
			
			var v: Double = (value as! C8yDoubleCustomAsset).value
			let t = self.deviceWrapper!.model.dataPointTemplate(for: preferredMetric!.lowercased())
				
			let m: Measurement
			
			if (t != nil) {
				var uom = t!.unit ?? ""

				if (t!.valueAsPercentage != nil && t!.valueAsPercentage!) {
					v = round((v / (t!.max! - t!.min!)) * 100)
					uom = "%"
				}
				
				m = Measurement(min: v, max: v, unit: uom, label: t!.label, type: preferredMetric!)
			} else {
				// no template
				
				m = Measurement(min: v, max: v, unit: "", label: "", type: preferredMetric!)
			}
			
			//self.setupRepeatingTask() // will only be used for battery monitoring
				
			return Just(m).eraseToAnyPublisher()
			
		} else if (_loadBatteryAndPrimaryMetricValuesDONE && self._preferredMetric == preferredMetric) {
			
			// need to fetch metric via c8y measurements API but can send pre-existing monitor
			
			return self._monitorPublisher!.eraseToAnyPublisher()
		} else {
			// need to fetch metric via c8y measurements API
		
			self._loadBatteryAndPrimaryMetricValuesDONE = true
			self._preferredMetric = preferredMetric
						
			print("setting up for primary metric '\(preferredMetric ?? "nil")' for \(self.deviceWrapper!.device.name) to \(autoRefresh)")

			self.startMonitorForPrimaryMetric(preferredMetric, refreshInterval: self._primaryMeasurementInterval)
		}
		
		return _monitorPublisher!.eraseToAnyPublisher()
	}
	
	/**
	Fetches latest device metrics from Cumulocity
	- returns: Publisher containing latest device measurements
	*/
	public func fetchAllMetricsForToday() -> AnyPublisher<[String:[C8yMeasurement]], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
					
		return C8yMeasurementsService(self.deviceWrapper!.conn!).get(forSource: self.deviceWrapper!.device.c8yId!, pageNum: 0, from: Date().advanced(by: -86400), to: Date(), reverseDateOrder: true).map({response in
			
			var results: [String:[C8yMeasurement]] = [:]
			
			for m in response.content!.measurements {
				let type = self.generaliseType(type: m.type!)
				var measurements: [C8yMeasurement]? = results[type]
				
				if (measurements == nil) {
					measurements = []
				}
				
				measurements!.append(m)
				results[type] = measurements
			}
			
			return results

			}).eraseToAnyPublisher()
	}
	
	private func populatePrimaryMetric(_ m: C8yMeasurementSeries?, type: String) -> Measurement {
	 
		if (m != nil && m!.values.count > 0) {
			self.deviceWrapper!.primaryMetric = Measurement(min: m!.values.last!.values[0].min, max: m!.values.last!.values[0].max, unit: m!.series.last!.unit, label: m!.series.last!.name, type: type)
			
			var v: [Double] = []
			var t: [String] = []
			
			for r in m!.values {
				v.append(r.values[0].min)
				t.append(r.time.timeString())
			}
			
			DispatchQueue.main.async {
				self.deviceWrapper!.primaryMetricHistory = MeasurementSeries(name: m!.series.last!.name, label: type, unit: m!.series.last!.unit, yValues: v, xValues: t)
			}
		}

		print("setting primary metric to \(String(describing: self.deviceWrapper!.primaryMetric.min)) for \(self.deviceWrapper!.device.name)")
	
		return self.deviceWrapper!.primaryMetric
	}
	
	public func fetchBatteryStatus(_ interval: Double) {
		
		self._fetchBatteryStatus(interval, label: C8Y_MEASUREMENT_BATTERY, series: C8Y_MEASUREMENT_BATTERY_TYPE)
	}
	
	private func _fetchBatteryStatus(_ interval: Double, label: String, series: String) {
	
		// get battery level

		self.getMeasurementSeries(self.deviceWrapper!.device, type: label, series: series, interval: interval, connection: self.deviceWrapper!.conn!)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				switch completion {
					case .failure:
						self.deviceWrapper!.batteryLevel = -1
						self._disableBatteryFetcher = true
					case .finished:
						// do nothing
						print("nowt")
				}
			}, receiveValue: { series in
				if (series != nil && series!.values.count > 0) {
					self.deviceWrapper!.batteryLevel = series!.values.last!.values[0].min
				} else if (label != C8Y_ALT_MEASUREMENT_BATTERY) {
					// try with alternative label
					
					self._fetchBatteryStatus(interval, label: C8Y_ALT_MEASUREMENT_BATTERY, series: C8Y_ALT_MEASUREMENT_BATTERY_TYPE)
				}
			}))
	}
	
	private func getMeasurementSeries(_ device: C8yDevice, type: String, series: String, interval: Double, connection: C8yCumulocityConnection, retries: Int? = nil) -> AnyPublisher<C8yMeasurementSeries?, Never> {
		
		print("Fetching metrics for device \(device.name), \(type), \(series)")
		
		var rinterval = interval
		
		return C8yMeasurementsService(connection).getSeries(forSource: device.c8yId!, type: type, series: series, from: Date().addingTimeInterval(-rinterval), to: Date(), aggregrationType: .MINUTELY)
			.map{response in
				return response.content!
			}.catch { error in
				return Just(nil).eraseToAnyPublisher()
			}.flatMap { s -> AnyPublisher<C8yMeasurementSeries?, Never> in
			
				if (s == nil) {
					// error
					
					return Just(nil).eraseToAnyPublisher()
				} else if (s!.values.count == 0) {
					
					let r = retries != nil ? retries! : 0
					
				// perhaps we need to look back further
					rinterval = rinterval * 2
				
					if (r < 3) {
						return self.getMeasurementSeries(device, type: type, series: series, interval: rinterval, connection: connection, retries: r+1)
					} else {
						return Just(nil).eraseToAnyPublisher()
					}
				} else {
					return Just(s).eraseToAnyPublisher()
				}
			}.eraseToAnyPublisher()
	}
	
	/**
	Fetches latest device prefered metric from Cumulocity
	- returns: Publisher containing latest preferred metric
	*/
	public func fetchMostRecentPrimaryMetric(_ preferredMetric: String) -> AnyPublisher<Measurement, Never> {
		   
		if (self.deviceWrapper!.device.c8yId! != "_new_") {
			
			var mType: String? = nil
			var mSeries: String? = nil
			
			if (preferredMetric.contains(".")) {
				let parts = preferredMetric.split(separator: ".")
				
				if (parts.count >= 2) {
					mType = String(parts[0])
					mSeries = String(parts[1])
				}
			}
			
			if (mType != nil) {
				return self.getMeasurementSeries(self.deviceWrapper!.device, type: mType!, series: mSeries!, interval: self._primaryMeasurementInterval, connection: self.deviceWrapper!.conn!)
					.receive(on: RunLoop.main)
					.map {series in
						
						return self.populatePrimaryMetric(series, type: mType!)

					}.catch { error -> AnyPublisher<Measurement, Never> in
						return Just(Measurement()).eraseToAnyPublisher()
					}.eraseToAnyPublisher()
			} else {
				return Just(Measurement()).eraseToAnyPublisher() // dummy
			}
		} else {
			return Just(Measurement()).eraseToAnyPublisher() // dummy
		}
	}
	
	/**
	Initiates a background thread to periodically refetch the preferred metric from Cumulocity.
	Changes will be issued via the publisher returned from the method `primaryMetricPublisher(preferredMetric:refreshInterval:)`
	- parameter preferredMetric: label of the measurement to periodically fetched requires both name and series separated by a dot '.' e.g. 'Temperature.T', if not provided will attempt to use first data point in `dataPoints`
	- parameter refreshInterval: period in seconds in which to refresh values, cannot be smaller than the devices indicated required response interval property
	- parameter onFirstLoad: callback, executed once first metrics have been successfully fetched, successful interval value is given
	*/
	public func startMonitorForPrimaryMetric(_ preferredMetric: String?, refreshInterval: Double, onFirstLoad: ((Double) -> Void)? = nil) {
		
		self._monitorPublisher = CurrentValueSubject<Measurement, Never>(Measurement())
		
		if (preferredMetric != nil) {
			self.fetchMostRecentPrimaryMetric(preferredMetric!)
				.receive(on: RunLoop.main)
				.replaceError(with: Measurement())
				.sink(receiveValue: { (v) in
					self._monitorPublisher?.send(self.deviceWrapper!.primaryMetric)
					
					if (v.type != nil && onFirstLoad != nil) {
						onFirstLoad!(self._primaryMeasurementInterval)
					}
				}).store(in: &self._cancellable)
			
			if (refreshInterval != -1) {
				self._primaryMeasurementInterval = refreshInterval
			}
			
			if (self._primaryMeasurementInterval > -1) {
				self.setupRepeatingTask(preferredMetric)
			}
		}
	}
	
	private func setupRepeatingTask(_ preferredMetric: String? = nil) {
	
		if (self._deviceMetricsTimer != nil) {
			self._deviceMetricsTimer!.suspend()
		}
		
		self._deviceMetricsTimer = JcRepeatingTimer(timeInterval: self._primaryMeasurementInterval)
					
		self._deviceMetricsTimer!.eventHandler = {
			
			if (preferredMetric != nil) {
				self.fetchMostRecentPrimaryMetric(preferredMetric!)
					.receive(on: RunLoop.main)
					.replaceError(with: Measurement())
					.sink(receiveValue: { (v) in
						self._monitorPublisher?.send(self.deviceWrapper!.primaryMetric)
					}).store(in: &self._cancellable)
			}
			
			if (!self._disableBatteryFetcher) {
				self.fetchBatteryStatus(self._primaryMeasurementInterval)
			}
		}
		
		self._deviceMetricsTimer!.resume()
	}
	
	private func generaliseType(type: String) -> String {
		
		if (type.lowercased().starts(with: "min") || type.lowercased().starts(with:"max") || type.lowercased().starts(with:"avg")) {
			return type.subString(from: 4)
		} else if (type.lowercased().starts(with: "mean")) {
			return type.subString(from: 5)
		} else if (type.lowercased().starts(with: "average")) {
			return type.subString(from: 8) // TODO: Find labels for average, mean, median and standard deviation)
		} else {
			return type
		}
	}
	
	public struct MeasurementSeries {
		public var name: String?
		public var label: String?
		public var unit: String?
		public var yValues: [Double] = []
		public var xValues: [String] = []
	}
	
	public struct Measurement {
		
		public var value: String?
		
		public var min: Double?
		public var max: Double?
		public var unit: String?
		public var label: String?
		public var type: String?
		
		public init() {
			
		}
		
		public init(value: String, unit: String, label: String, type: String) {
		
			self.value = value
			self.unit = unit
			self.label = label
			self.type = type
		}
		
		public init(min: Double, max: Double, unit: String, label: String, type: String) {
			self.min = min
			self.max = max
			self.unit = unit
			self.label = label
			self.type = type
		}
	}
}
