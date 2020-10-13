//
//  DeviceManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 13/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

import CoreLocation

public class C8yMutableDevice: ObservableObject  {
    
    @Published public var device: C8yDevice
    
    @Published public var position: CLLocationCoordinate2D? = nil {
        didSet {
            if (position != nil) {
                device.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
            }
        }
    }

    @Published public var reloadMetrics: Bool = false {
        didSet {
            
            if (self.reloadMetrics) {
                self.updateMetricsForToday()
            }
        }
    }
    
    @Published public var reloadLogs: Bool = false {
        didSet {
               
            if (self.reloadLogs) {
                self.updateEventLogsForToday()
            }
        }
    }
    
    @Published public var reloadAlarms: Bool = false {
        didSet {
            if (self.reloadAlarms) {
                self.updateAlarmsForToday()
            }
        }
    }
    
    @Published public var reloadOperations: Bool = false {
        didSet {
            if (self.reloadOperations) {
                self.updateOperationHistory()
            }
        }
    }
	
	@Published public private(set) var batteryLevel: Double = -2
    
    public private(set) var primaryMetric: Measurement = Measurement()
	
    @Published public private(set) var primaryMetricHistory: MeasurementSeries = MeasurementSeries()
    
    @Published public var measurements: [String:[C8yMeasurement]] = [:]

    @Published public var events: [C8yEvent] = []
    
    @Published public var alarms: [C8yAlarm] = []
    
    @Published public var operationHistory: [C8yOperation] = []
    
    public private(set) var isMonitoring: Bool = false
    
	@Published public var isRestarting: Bool = false {
		didSet {
			if (self.isRestarting) {
				self._restartTime = Date()
			} else {
				self._restartTime = nil
			}
		}
	}
	private var _restartTime: Date? = nil
	
    public internal(set) var lastAttachment: JcMultiPartContent.ContentPart? = nil

    public var conn: C8yCumulocityConnection?
    
    private var _deviceMetricsTimer: JcRepeatingTimer?
	private var _deviceOperationHistoryTimer: JcRepeatingTimer?
	
    private var _refreshInterval: TimeInterval = -1
    private var _cancellable: [AnyCancellable] = []
    private var _monitorPublisher: CurrentValueSubject<Measurement, Never>?
    
	private var _cachedResponseInterval: Int = 30

    public init() {
        self.device = C8yDevice()
    }
    
    public init(_ device: C8yDevice, connection: C8yCumulocityConnection) {
        
        self.device = device
        self.conn = connection
        
        if (self.device.position != nil) {
            self.position = CLLocationCoordinate2D(latitude: device.position!.lat, longitude: device.position!.lng)
        }
    }
    
    deinit {
        self.stopMonitoring()
    }
	
	private var _loadBatteryAndPrimaryMetricValuesDONE: Bool = false
	private var _preferredMetric: String? = nil
	
	public func primaryMetricPublisher(preferredMetric: String?, refreshInterval: Double = -1) -> AnyPublisher<Measurement, Never> {
	
		if (_loadBatteryAndPrimaryMetricValuesDONE && self._preferredMetric == preferredMetric) {
			return self._monitorPublisher!.eraseToAnyPublisher()
		}
		
		print("setting up thread for primary metric '\(preferredMetric ?? "nil")' for \(self.device.model)")
		
		self._loadBatteryAndPrimaryMetricValuesDONE = true
		self._preferredMetric = preferredMetric
		
		if (device.externalIds.count == 0) {
			self.getExternalIds()
		}
		
		// setup monitoring
		
		self.startMonitorForPrimaryMetric(preferredMetric, refreshInterval: refreshInterval)

		// get battery level
		
		self.getMeasurementSeries(self.device, type: C8Y_MEASUREMENT_BATTERY, series: C8Y_MEASUREMENT_BATTERY_TYPE, interval: 5, connection: self.conn!).sink { completion in
			switch completion {
				case .failure:
					self.batteryLevel = -1
				case .finished:
					// do nothing
					print("nowt")
			}
		} receiveValue: { series in
			if (series.values.count > 0) {
				self.batteryLevel = series.values.last!.values[0].min
			}
		}.store(in: &self._cancellable)
		
		return _monitorPublisher!.eraseToAnyPublisher()
	}
	        
	public func restart() {
		
		if (self.isRestarting) {
			return
		}
		
		do {
		
			self.isRestarting = true
			
			let op = C8yOperation(forSource: self.device.c8yId!, type: C8Y_OPERATION_RESTART, description: "request made from device manager app")
								  
			try C8yOperationService(self.conn!).post(operation: op)
				.receive(on: RunLoop.main)
				.sink(receiveCompletion: { (completion) in
					
					switch completion {
						case .failure(let error):
							print(error)
							self.isRestarting = false
						case .finished:
							// need to do this so we can find out when restart has completed
							self.startMonitoringForOperationHistory(30)
					}
				}) { (response) in
					self.operationHistory.insert(op, at: 0)
					self.objectWillChange.send()
					
				}.store(in: &self._cancellable)
		} catch {
			self.isRestarting = false
		}
	}
		
    public func toggleMaintainanceMode() throws {
            
        if (device.wrappedManagedObject.requiredAvailability == nil) {
            self.device.wrappedManagedObject.requiredAvailability = C8yManagedObject.RequiredAvailability(responseInterval: -1)
        } else if (device.operationalLevel == .maintenance) {
            self.device.wrappedManagedObject.requiredAvailability!.responseInterval = self._cachedResponseInterval
        } else {
            self._cachedResponseInterval = self.device.wrappedManagedObject.requiredAvailability!.responseInterval
            self.device.wrappedManagedObject.requiredAvailability!.responseInterval = -1
        }
        
        try C8yManagedObjectsService(self.conn!).put(C8yManagedObject.init(self.device.c8yId!, requiredAvailability: self.device.wrappedManagedObject.requiredAvailability!))
			.receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
            }) { response in
                
				self.device.wrappedManagedObject.availability = C8yManagedObject.Availability(status: self.device.wrappedManagedObject.requiredAvailability!.responseInterval == -1 ? .MAINTENANCE : .AVAILABLE, lastMessage: self.device.wrappedManagedObject.availability?.lastMessage ?? Date())
        }.store(in: &self._cancellable)
    }
    
    public func toggleRelay() throws {
    
        var state: C8yManagedObject.RelayStateType = .CLOSED
        
		if (self.device.relayState != nil) {
			if (self.device.relayState! == .CLOSED) {
                state = .OPEN
            } else {
                state = .CLOSED
            }
        }
        
        var op = C8yOperation(forSource: self.device.c8yId!, type: C8Y_OPERATION_RELAY, description: "Relay Operation")
        op.operationDetails = C8yOperation.OperationDetails(C8Y_OPERATION_RELAY_STATE, value: state.rawValue)
        
        try C8yOperationService(self.conn!).post(operation: op)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
				
				print("here")

            }) { (response) in
                if (state == .CLOSED) {
                    self.device.wrappedManagedObject.relayState = .CLOSE_PENDING
                } else {
                    self.device.wrappedManagedObject.relayState = .OPEN_PENDING
                }
                self.operationHistory.insert(op, at: 0)
				
				// update managed object in c8y to reflect relay position
				
				do {
					try C8yManagedObjectsService(self.conn!).put(self.device.wrappedManagedObject)
						.receive(on: RunLoop.main)
						.sink(receiveCompletion: { error in
							self.objectWillChange.send()
						}, receiveValue: { obj in
							// do nothing
						}).store(in: &self._cancellable)
				} catch {
					//do nothing
					print("failed \(error.localizedDescription)")
				}
        }.store(in: &self._cancellable)
    }
    
	public func updateDeviceProperty(withKey key: String, value: String) throws {
		
		try C8yManagedObjectsService(self.conn!).put(C8yManagedObject.init(self.device.c8yId!, properties: Dictionary(uniqueKeysWithValues: zip([key], [value]))))
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { error in
				self.objectWillChange.send()
			}, receiveValue: { obj in
				// do nothing
			}).store(in: &self._cancellable)
	}
		
    public func provision(completionHandler: @escaping (Error?) -> Void) {
    
		do {
			try C8yNetworks.provision(device, conn: self.conn!)
				.receive(on: RunLoop.main)
				.sink(receiveCompletion: { completion in
					switch completion {
					case .failure(let error):
						completionHandler(error)
					case .finished:
						completionHandler(nil)
					}
				}, receiveValue: { device in
					self.device = device
				}).store(in: &self._cancellable)
		} catch {
			completionHandler(error)
		}
    }
    
    public func deprovision(completionHandler: @escaping (Error?) -> Void) {
    
		do {
			try C8yNetworks.deprovision(device, conn: self.conn!)
				.receive(on: RunLoop.main)
				.sink(receiveCompletion: { completion in
					switch completion {
					case .failure(let error):
						completionHandler(error)
					case .finished:
						completionHandler(nil)
					}
				}, receiveValue: { device in
					self.device = device
				}).store(in: &self._cancellable)
		} catch {
			completionHandler(error)
		}
    }
    
    public func runOperation(_ op: C8yOperation) throws -> AnyPublisher<String?, Never> {
    
		let result = PassthroughSubject<String?, Never>()
		
        try C8yOperationService(self.conn!).post(operation: op)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
                switch completion {
                case .failure(let error):
					result.send(error.localizedDescription)
                default:
					result.send(nil)
                }
            }) { (response) in
                self.operationHistory.insert(op, at: 0)
                self.objectWillChange.send()
        }.store(in: &self._cancellable)
		
		return result.eraseToAnyPublisher()
    }
	
	public func postNewAlarm(type: String, severity: C8yAlarm.Severity, text: String, completionHandler: @escaping (C8yAlarm?) -> Void) throws {
		
		var alarm = C8yAlarm(forSource: self.device.c8yId!, type: type, description: text, status: C8yAlarm.Status.ACTIVE, severity: severity)
		
		try C8yAlarmsService(self.conn!).post(alarm)
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { completion in
			
				switch completion {
					case .failure:
						completionHandler(nil)
				default:
					print("done")
				}
				
		}, receiveValue: { response in
			if (response.content != nil) {
				alarm.id = response.content!
				self.alarms.append(alarm)
				
				self.device.alarms = self.alarmSummary(self.alarms)
				
				completionHandler(alarm)
			} else {
				completionHandler(nil)
			}
		}).store(in: &self._cancellable)
	}
	
	public func updateAlarm(_ alarm: C8yAlarm, completionHandler: @escaping (Bool) -> Void) throws {
	
		try C8yAlarmsService(self.conn!).put(alarm)
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: {
				completion in
				switch completion {
				case .failure:
					completionHandler(false)
				default:
					for z in self.alarms.indices {
						if self.alarms[z].id == alarm.id {
							self.alarms[z] = alarm
						}
					}
					
					self.device.alarms = self.alarmSummary(self.alarms)
					
					completionHandler(true)
				}
			}) { (result) in
				// do nothing
		}.store(in: &self._cancellable)
	}
    
    public func toDevicePositionUpdate() -> C8yDevice {
            
        var pd: C8yDevice = C8yDevice(self.device.c8yId!)
        
        if (self.position != nil) {
            pd.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
        } else {
            pd.position = self.device.position
        }
        
        return pd
    }

    public func updateMetricsForToday() {
        self.fetchAllMetricsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                self.reloadMetrics = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.measurements = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchAllMetricsForToday() -> AnyPublisher<[String:[C8yMeasurement]], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                    
        return C8yMeasurementsService(self.conn!).get(forSource: self.device.c8yId!, pageNum: 0, from: Date().advanced(by: -86400), to: Date(), reverseDateOrder: true).map({response in
            
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
    
    public func updateEventLogsForToday() {
        
        self.fetchEventLogsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadLogs = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.events = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchEventLogsForToday() -> AnyPublisher<[C8yEvent], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                    
        return C8yEventsService(self.conn!).get(source: self.device.c8yId!, pageNum: 0).map({response in
            
            return response.content!.events
            
        }).eraseToAnyPublisher()
    }

    public func updateOperationHistory() {
        
        self.fetchOperationHistory()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadOperations = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.operationHistory = results.reversed()
                
                for op in self.operationHistory {
                    if op.type == C8Y_OPERATION_RELAY {
                        if (op.status == .SUCCESSFUL) {
                            self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType(rawValue: op.type!)
                        } else if (op.status == .FAILED) {
                            if (op.type == C8yManagedObject.RelayStateType.OPEN.rawValue) {
                                self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType.CLOSED
                            } else {
                                self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType.OPEN
                            }
                        }
                    }
					
					if (self.isRestarting && op.type == C8Y_OPERATION_RESTART && (op.status == .SUCCESSFUL || op.status == .FAILED) && op.creationTime! > self._restartTime!) {
						self.isRestarting = false
					}
                }
        }.store(in: &self._cancellable)
    }
    
    public func fetchOperationHistory() -> AnyPublisher<[C8yOperation], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                      
        return C8yOperationService(self.conn!).get(self.device.c8yId!).map({response in
            return response.content!.operations
        }).eraseToAnyPublisher()
    }
    
    public func updateAlarmsForToday() {
        
        self.fetchActiveAlarmsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadAlarms = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.alarms = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchActiveAlarmsForToday() -> AnyPublisher<[C8yAlarm], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
            
        return C8yAlarmsService(self.conn!).get(source: self.device.c8yId!, status: .ACTIVE, pageNum: 0)
            .merge(with: C8yAlarmsService(self.conn!).get(source: self.device.c8yId!, status: .ACKNOWLEDGED, pageNum: 0))
            .collect()
            .map({response in
                var array: [C8yAlarm] = []
        
                for p in response {
                    array.append(contentsOf: p.content!.alarms)
                }
                
                return array
        }).eraseToAnyPublisher()
    }
    
    public func fetchMostRecentPrimaryMetric(_ preferredMetric: String?) -> AnyPublisher<C8yMutableDevice.Measurement, Never> {
           
        if (device.c8yId! != "_new_") {
            
            var mType: String? = nil
            var mSeries: String? = nil
            
			if (preferredMetric != nil && preferredMetric!.contains(".")) {
                let parts = preferredMetric!.split(separator: ".")
				
				if (parts.count >= 2) {
					mType = String(parts[0])
					mSeries = String(parts[1])
				}
            } else if (self.primaryDataPoints(device).count > 0) {
                let metric: [C8yDataPoints.DataPoint] = self.primaryDataPoints(device)
                mType = metric[0].reference
                mSeries = metric[0].value.series
            }
            
            if (mType != nil) {
                let interval: Double = Double(device.requiredResponseInterval == nil ? 60 : device.requiredResponseInterval! * 60)
                
                return self.getMeasurementSeries(device, type: mType!, series: mSeries!, interval: interval, connection: self.conn!)
					.receive(on: RunLoop.main)
					.map({response in
                    return self.populatePrimaryMetric(response, type: mType!)
                }).replaceError(with:C8yMutableDevice.Measurement())
                .eraseToAnyPublisher()
            } else {
                return Just(C8yMutableDevice.Measurement()).eraseToAnyPublisher() // dummy
            }
        } else {
            return Just(C8yMutableDevice.Measurement()).eraseToAnyPublisher() // dummy
        }
    }
    
	private func getExternalIds() {
	
		C8yManagedObjectsService(self.conn!).externalIDsForManagedObject(device.wrappedManagedObject.id!).sink(receiveCompletion: { completion in

		}, receiveValue: { response in
			self.device.setExternalIds(response.content!.externalIds)
			
		}).store(in: &self._cancellable)
	}
	
    private func populatePrimaryMetric(_ m: C8yMeasurementSeries, type: String) -> Measurement {
     
        if (m.values.count > 0) {
            self.primaryMetric = Measurement(min: m.values.last!.values[0].min, max: m.values.last!.values[0].max, unit: m.series.last!.unit, label: m.series.last!.name, type: type)
            
            var v: [Double] = []
            var t: [String] = []
            
            for r in m.values {
                v.append(r.values[0].min)
                t.append(r.time.timeString())
            }
            
            DispatchQueue.main.async {
                self.primaryMetricHistory = MeasurementSeries(name: m.series.last!.name, label: type, unit: m.series.last!.unit, yValues: v, xValues: t)
            }
        }

        print("setting primary metric to \(String(describing: self.primaryMetric.min)) for \(self.device.name)")
        
        return self.primaryMetric
    }
    
    private func getMeasurementSeries(_ device: C8yDevice, type: String, series: String, interval: Double, connection: C8yCumulocityConnection) -> AnyPublisher<C8yMeasurementSeries, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
        
        print("Fetching metrics for device \(device.name), \(type), \(series)")
        
        return C8yMeasurementsService(connection).getSeries(forSource: device.c8yId!, type: type, series: series, from: Date().addingTimeInterval(-interval), to: Date(), aggregrationType: .MINUTELY).map({response in
            return response.content!
            }).eraseToAnyPublisher()
    }
        
	public func startMonitorForPrimaryMetric(_ preferredMetric: String?, refreshInterval: Double) {
        
		self._monitorPublisher = CurrentValueSubject<Measurement, Never>(Measurement())
		
		self.fetchMostRecentPrimaryMetric(preferredMetric)
			.receive(on: RunLoop.main)
			.sink(receiveValue: { (v) in
				self._monitorPublisher?.send(self.primaryMetric)
			}).store(in: &self._cancellable)
		
		if (self.device.requiredResponseInterval != nil && self.device.requiredResponseInterval! > 0 && Double(self.device.requiredResponseInterval!*60) > refreshInterval) {
			
			// don't refresh quicker than the device's own
			self._refreshInterval = Double(self.device.requiredResponseInterval!) * 60
		} else if (refreshInterval > -1) {
			self._refreshInterval = refreshInterval
		}
		
		if (self._deviceMetricsTimer != nil) {
			self._deviceMetricsTimer!.suspend()
		}
		
		if (self._refreshInterval > -1 && (preferredMetric != nil || self.primaryDataPoints(device).count > 0)) {
			self._deviceMetricsTimer = JcRepeatingTimer(timeInterval: self._refreshInterval)
			
			self.isMonitoring = true
			
			self._deviceMetricsTimer!.eventHandler = {
				
				self.fetchMostRecentPrimaryMetric(preferredMetric)
					.receive(on: RunLoop.main)
					.sink(receiveValue: { (v) in
						self._monitorPublisher?.send(self.primaryMetric)
					}).store(in: &self._cancellable)
			}
			
			self._deviceMetricsTimer!.resume()
		}
	}
    
    public func stopMonitoring() {
        
        if (self._deviceMetricsTimer != nil) {
            
            if (self._monitorPublisher != nil) {
                self._monitorPublisher!.send(completion: .finished)
            }
            
            for c in self._cancellable {
                c.cancel()
            }
            
            self._deviceMetricsTimer?.suspend()
            self.isMonitoring = false
        }
		
		if (_deviceOperationHistoryTimer != nil) {
			self._deviceOperationHistoryTimer?.suspend()
		}
    }
    
	public func startMonitoringForOperationHistory(_ interval: TimeInterval = -1) {
			
		if (self._deviceOperationHistoryTimer != nil) {
			self._deviceOperationHistoryTimer!.suspend()
		}
		
		self.updateOperationHistory()

		if (self._deviceOperationHistoryTimer == nil && (interval > -1 || self._refreshInterval > -1)) {
			
			self._deviceOperationHistoryTimer = JcRepeatingTimer(timeInterval: self._refreshInterval > -1 ? self._refreshInterval : interval)
			self._deviceOperationHistoryTimer!.eventHandler = {
				
				self.updateOperationHistory()
			}
		}
		
		if (self._deviceOperationHistoryTimer != nil) {
			self._deviceOperationHistoryTimer!.resume()
		}
	}
	
    public func statusForOperation(_ type: String) -> C8yOperation? {
    
        var op: C8yOperation? = nil
        
        for o in self.operationHistory {
            
            if (o.type == type) {
                op = o
                break
            }
        }
        
        return op
    }
    
    public func attachmentForId(id: String) -> AnyPublisher<JcMultiPartContent.ContentPart, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        if (self.lastAttachment == nil || self.lastAttachment?.id != id) {
            
            return C8yBinariesService(self.conn!).get(id).map({ response in
                self.lastAttachment = response.content!.parts[0]
                return self.lastAttachment!
                }).eraseToAnyPublisher()
        } else {
            return Just(self.lastAttachment!).mapError({ never -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
				return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: "won't happen")
            }).eraseToAnyPublisher()
        }
    }

    public func addAttachment(filename: String, fileType: String, content: Data) -> AnyPublisher<JcMultiPartContent.ContentPart, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        var fname = filename
        
        if (!fname.contains(".")) {
            
            if (fname.contains("png")) {
                fname += ".png"
            } else {
                fname += ".jpg"
            }
        }
        
        return C8yBinariesService(self.conn!).post(name: "\(device.c8yId!)-\(fname)", contentType: fileType, content: content).map({ response in
            
            self.lastAttachment = response.content!.parts[0]
            self.device.attachments.insert(self.lastAttachment!.id!, at: 0)

            self.device.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] = C8yStringWrapper(String.make(array: self.device.attachments)!)
            
            return self.lastAttachment!
        }).eraseToAnyPublisher()
    }
    
    public func replaceAttachment(index: Int, filename: String, fileType: String, content: Data) -> AnyPublisher<JcMultiPartContent.ContentPart?, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        return C8yBinariesService(self.conn!).post(name: filename, contentType: fileType, content: content).map({ response in

            let oldRef = self.lastAttachment?.id
                        
            self.lastAttachment = response.content!.parts[0]
            self.device.attachments = self.device.attachments.filter() {
                $0 != oldRef
            }
            
            return response.content!.parts[0]
        }).eraseToAnyPublisher()
    }
    
    func primaryDataPoints(_ device: C8yDevice) -> [C8yDataPoints.DataPoint] {
               
       //TODO: link this to C8yModels
       
        if (device.dataPoints != nil && device.dataPoints!.dataPoints.count > 0) {
            return device.dataPoints!.dataPoints
       } else {
            return []
       }
    }
    
    func makeError<T>(_ response: JcRequestResponse<T>) -> Error? {

        if (response.status != .SUCCESS) {
            if (response.httpMessage != nil) {
                return C8yDeviceUpdateError.reason(response.httpMessage)
            } else if (response.error != nil){
                return C8yDeviceUpdateError.reason(response.error?.localizedDescription)
            } else {
                return C8yDeviceUpdateError.reason("undocumented")
            }
        } else {
            return nil
        }
    }
    
    private func generaliseType(type: String) -> String {
        
        if (type.lowercased().starts(with: "min") || type.lowercased().starts(with:"max") || type.lowercased().starts(with:"avg")) {
            return type.substring(from: 4)
        } else if (type.lowercased().starts(with: "mean")) {
            return type.substring(from: 5)
        } else if (type.lowercased().starts(with: "average")) {
            return type.substring(from: 8) // TODO: Find labels for average, mean, median and standard deviation)
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
        public var min: Double?
        public var max: Double?
        public var unit: String?
        public var label: String?
        public var type: String?
        
        public init() {
            
        }
        
        public init(min: Double, max: Double, unit: String, label: String, type: String) {
            self.min = min
            self.max = max
            self.unit = unit
            self.label = label
            self.type = type
        }
    }
	
	private func alarmSummary(_ alarms: [C8yAlarm]) -> C8yManagedObject.ActiveAlarmsStatus {
		
		var c: Int = 0
		var mj: Int = 0
		var mr: Int = 0
		var w: Int = 0
		
		for a in alarms {
			switch a.severity {
				case .CRITICAL:
					c += a.status != .CLEARED ? 1 : 0
				case .MAJOR:
					mj += a.status != .CLEARED ? 1 : 0
				case .MINOR:
					mr += a.status != .CLEARED ? 1 : 0
				default:
					w += a.status != .CLEARED ? 1 : 0
			}
		}
		
		return C8yManagedObject.ActiveAlarmsStatus(warning: w, minor: mr, major: mj, critical: c)
	}
}
