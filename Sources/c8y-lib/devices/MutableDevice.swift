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

/**
Presents a `C8Device` device that can be observed for changed within in a SwiftUI View directly.
Static device data is still available via the wrapped `device` attribute.
In addition it provides dynamic data such as gps position, battery level, measurements etc  that can be observed for changes

Use the `EditableDevice` class if you want to provide a view to allow a user to edit a device.
*/
public class C8yMutableDevice: ObservableObject  {
  
	/**
	Wrapped device to which we want to add dynamic data
	*/
    @Published public var device: C8yDevice
    
	/**
	Current GPS location of device
	*/
    @Published public var position: CLLocationCoordinate2D? = nil {
        didSet {
            if (position != nil) {
                device.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
            }
        }
    }

	/**
	Returns a list of the move recent movement for this device based on emitted events for `C8yLocationUpdate_EVENT`
	This will return an empty set if no recent movement has been detected i.e. no recent events have been sent.
	
	- returns: List of `CLLocationCoordinate2D` with most recent being at the end of the array
	*/
	public var positionHistory: [CLLocationCoordinate2D] {
		get {
			var h: [CLLocationCoordinate2D] = []
			
			for o in self.events {
					
				if (o.type == C8yLocationUpdate_EVENT && o.position != nil) {
					h.insert(CLLocationCoordinate2D(latitude: o.position!.lat, longitude: o.position!.lng), at: 0)
				}
			}
			
			return h
		}
	}
	
	/**
	Set to true if you want to load latest metrics for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadMetrics: Bool = false {
        didSet {
            
            if (self.reloadMetrics) {
                self.updateMetricsForToday()
            }
        }
    }
    
	/**
	Set to true if you want to load latest logs for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadLogs: Bool = false {
        didSet {
               
            if (self.reloadLogs) {
                self.updateEventLogsForToday()
            }
        }
    }
    
	/**
	Set to true if you want to load latest alarms for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadAlarms: Bool = false {
        didSet {
            if (self.reloadAlarms) {
                self.updateAlarmsForToday()
            }
        }
    }
    
	/**
	Set to true if you want to load latest operations history for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadOperations: Bool = false {
        didSet {
            if (self.reloadOperations) {
                self.updateOperationHistory()
            }
        }
    }
	
	/**
	Returns the current battery level if available (returns -2 if not applicable)
	*/
	@Published public private(set) var batteryLevel: Double = -2
    
	/**
	Returns the primary metric for this device e.g. Temperature, ambiance etc.
	This attribute is not observable as it can change too frequently, instead use the method `primaryMetricPublisher(preferredMetric:refreshInterval:)`
	along with the 'onReceive' SwiftUI event to ensure you can update your view fragment efficiently e.g.
	
	```
	VStack(alignment: .leading) {
		Text("termperature is \(self.$primaryMeasurement.min)")
	}.onReceive(self.deviceWrapper.primaryMetricPublisher(preferredMetric: self.preferredMetric, refreshInterval: self.deviceRefreshInterval)) { v in
		
		print("received measurement: \(v) for \(self.deviceWrapper.device.name)")
		self.primaryMeasurement = v
	}
	```
	*/
    public private(set) var primaryMetric: Measurement = Measurement()
	
	/**
	Returns the primary metric history
	*/
    @Published public private(set) var primaryMetricHistory: MeasurementSeries = MeasurementSeries()
    
	/**
	Returns all available measurements captured by Cumulocity for this device
	*/
    @Published public var measurements: [String:[C8yMeasurement]] = [:]

	/**
	Returns all the latest events received by Cumulocity for the device
	*/
    @Published public var events: [C8yEvent] = []
    
	/**
	Returns all the latest alarms received by Cumulocity for the device
	*/
    @Published public var alarms: [C8yAlarm] = []
    
	/**
	Returns a list of all operations that are pending or completed that have been submitted to Cumulocity for this device
	*/
    @Published public var operationHistory: [C8yOperation] = []
    
	/**
	Indicates whether there is currently a background thread in place to periodically fetch the latest preferred metric and battery level
	Use the method `startMonitorForPrimaryMetric(_:refreshInterval:)`
	*/
    public private(set) var isMonitoring: Bool = false
    
	/**
	Convenience attribute to try and detect if a device is currently being restarted, i.e. someone submitted a 'c8y_Restart' operation
	that is now flagged in Cumulocity as in the state 'PENDING' or 'EXECUTING', in which case this attribute returns true.
	Will be false once we receive an operation update for 'c8y_Restart' in `operationHistory` with an ulterior date and the state of either 'COMPLETED' or 'FAILED'
	*/
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
	
	/**
	Convenience attribute that caches the last binary file associated with the device that was fetched from Cumulocity
	via the method `attachmentForId(id)` or posted via the method `addAttachment(filename:fileType:content:)`
	*/
    public internal(set) var lastAttachment: JcMultiPartContent.ContentPart? = nil

	/**
	Associated Cumulocity connection info that allows this object to fetch/post data
	*/
    public var conn: C8yCumulocityConnection?
    
    private var _deviceMetricsTimer: JcRepeatingTimer?
	private var _deviceOperationHistoryTimer: JcRepeatingTimer?
	
    private var _refreshInterval: TimeInterval = -1
    private var _cancellable: [AnyCancellable] = []
    private var _monitorPublisher: CurrentValueSubject<Measurement, Never>?
    
	private var _cachedResponseInterval: Int = 30

	/**
	Default constructor representing a new `C8yDevice`
	*/
    public init() {
        self.device = C8yDevice()
    }
	
    /**
	Constructor to create a mutable device for the give device
	- parameter device: Device to which we want to fetch mutable data
	- parameter connection: Connection details in order to connect to Cumulocity
	*/
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
	
	/**
	Provides a publisher that can be used to listen for periodic updates to primary metric
	- parameter preferredMetric: label of the measurement to periodically fetched requires both name and series separated by a dot '.' e.g. 'Temperature.T'
	- parameter refreshInterval: period in seconds in which to refresh values
	- returns: Publisher that will issue updated metrics periodically
	*/
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
		
		let interval: Double = Double(device.requiredResponseInterval == nil ? 60 : device.requiredResponseInterval! * 60)

		self.getMeasurementSeries(self.device, type: C8Y_MEASUREMENT_BATTERY, series: C8Y_MEASUREMENT_BATTERY_TYPE, interval: interval, connection: self.conn!)
			.receive(on: RunLoop.main)
			.sink { completion in
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
	        
	/**
	Submits an operation to Cumulocity to ask the device to restart
	*NOTE* This will only work if supported by the device and its agent and might take several minutes or even hours before it is enacted
	*/
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
		
	/**
	Sets the device's requiredResponseInterval to -1 to trigger Cumulocity's maintenance mode.
	Maintenance mode deactivates all of the devices alarms to avoid false flags.
	Calling this method if already in maintenance mode sets the requiredResponseInterval back to the last know value or 30 minutes if not known.
	*/
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
    
	/**
	Submits an operation to switch the relay and also synchronises the device relay attribute `C8yDevice.relayState`.
	*NOTE* - Only applicable if the device or agent supports it.
	*/
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
    
	/**
	Updates the server side Cumulocity Managed Object based on the properties provided here.
	- parameter withKey: name of the managed object attribute to updated/added
	- parameter value: The value to be assigned
	- throws: Invalid key/value pair
	*/
	public func updateDeviceProperty(withKey key: String, value: String) throws  {
		
		try C8yManagedObjectsService(self.conn!).put(C8yManagedObject.init(self.device.c8yId!, properties: Dictionary(uniqueKeysWithValues: zip([key], [value]))))
			.receive(on: RunLoop.main)
			.sink(receiveCompletion: { error in
				self.objectWillChange.send()
			}, receiveValue: { obj in
				// do nothing
			}).store(in: &self._cancellable)
	}
		
	/**
	Provisions the netwok connection for the device.
	The implementation is provided via the appropriate network type `C8yNetworks.provision(_:conn)`
	
	This method does nothing If no specific network type is specified i.e. the device connects over standard ip public network
	
	- returns: Publisher with updated device
	- throws: If network is invalid or not recognised
	*/
	public func provision() throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
    
		return try C8yNetworks.provision(device, conn: self.conn!)
			.receive(on: RunLoop.main)
			.map({device -> C8yDevice in
				self.device = device
				return device
			}).eraseToAnyPublisher()
    }
    
	/**
	Deprovisions the netwok connection from the device.
	The implementation is provided via the appropriate network type `C8yNetworks.deprovision(_:conn)`
	
	This method does nothing If no specific network type is specified i.e. the device connects over standard ip public network

	- returns: Publisher with updated device
	- throws: If network is invalid or not recognised
	*/
	public func deprovision()throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
    
		return try C8yNetworks.deprovision(device, conn: self.conn!)
			.receive(on: RunLoop.main)
			.map({device -> C8yDevice in
				self.device = device
				return device
			}).eraseToAnyPublisher()
    }
    
	/**
	Submits the given operation to Cumulocity and records it in `operationHistory`
	The operation will have an initial status of PENDING
	
	- parameter operation: The `C8yOperation` to be posted to Cumulocity for eventual execution by the device.
	- returns: Publisher with cumulocity internal id of new operation.
	- throws: Invalid operation
	*/
    public func sendOperation(_ op: C8yOperation) throws -> AnyPublisher<String, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
    		
        try C8yOperationService(self.conn!).post(operation: op)
			.receive(on: RunLoop.main)
			.map({ response -> String in
				
				let nop = response.content
				self.operationHistory.insert(nop!, at: 0)
				return nop!.id!
			}).eraseToAnyPublisher()
    }
	
	/**
	Submits the given event to Cumulocity and records it in `events`
	
	*NOTE* - `C8yLocationUpdate_EVENT` type events will also update the devices `C8yMutableDevice.postion` attribute as a side effect
	
	- parameter event: The `C8yEvent` to be posted to Cumulocity for eventual execution by the device.
	- returns: Publisher with cumulocity internal id of new event.
	- throws: Invalid event
	*/
	public func sendEvent(_ event: C8yEvent) throws -> AnyPublisher<C8yEvent, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		var updatedEvent = event
		
		return try C8yEventsService(self.conn!).post(event)
			.receive(on: RunLoop.main)
			.map( { response -> C8yEvent in
				
				updatedEvent = response.content!
				self.events.insert(updatedEvent, at: 0)
				
				return updatedEvent
			}).flatMap({ response -> AnyPublisher<C8yEvent, JcConnectionRequest<C8yCumulocityConnection>.APIError> in
				
				if (event.type == C8yLocationUpdate_EVENT) {
					self.position = CLLocationCoordinate2D(latitude: event.position!.lat, longitude: event.position!.lng)
					do {
						return try C8yManagedObjectsService(self.conn!).put(C8yManagedObject(event.source, withPosition: event.position!))
							.receive(on: RunLoop.main)
							.map({ response -> C8yEvent in
								return updatedEvent
							}).eraseToAnyPublisher()
					} catch {
						return Just(updatedEvent).mapError({ never -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
							return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: "won't happen")
						}).eraseToAnyPublisher()
					}
				} else {
					return Just(updatedEvent).mapError({ never -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
						return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: "won't happen")
					}).eraseToAnyPublisher()
				}
			}).eraseToAnyPublisher()
	}
	
	/**
	Submits the new alarm to Cumulocity and records it in `alarms`
	The alarm will have an initial status of ACTIVE
	
	- parameter type: Describes the type of alarm being submitted.
	- parameter severity: Either CRITICAL, MAJOR, MINOR or WARNING
	- parameter text: Detailed description of alarm
	- returns: Publisher with new cumulocity alarm
	- throws: Invalid alarm
	*/
	public func postNewAlarm(type: String, severity: C8yAlarm.Severity, text: String) throws -> AnyPublisher<C8yAlarm, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		var alarm = C8yAlarm(forSource: self.device.c8yId!, type: type, description: text, status: C8yAlarm.Status.ACTIVE, severity: severity)
		
		return try C8yAlarmsService(self.conn!).post(alarm)
			.receive(on: RunLoop.main)
			.map({ (response) -> C8yAlarm in
			
			alarm.id = response.content!
			self.alarms.append(alarm)
				
			self.device.alarms = self.alarmSummary(self.alarms)

			return alarm
			
		}).eraseToAnyPublisher()
	}
	
	/**
	Updates the existing alarm to Cumulocity and the copy in `alarms`
	
	- parameter alarm: Alarm to be updated in Cumulocity
	- returns: Publisher with updated cumulocity alarm
	- throws: Invalid alarm
	*/
	public func updateAlarm(_ alarm: C8yAlarm) throws -> AnyPublisher<C8yAlarm, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
	
		return try C8yAlarmsService(self.conn!).put(alarm)
			.receive(on: RunLoop.main)
			.map({ response -> C8yAlarm in
				
				for z in self.alarms.indices {
					if self.alarms[z].id == alarm.id {
						self.alarms[z] = alarm
					}
				}
				
				self.device.alarms = self.alarmSummary(self.alarms)
				
				return alarm
			}).eraseToAnyPublisher()
	}
    
	/**
	Convenience method to create a Managed Object containing only the device's GPS position
	- returns: Returns a `C8yDevice` instance referencing only the device internal id and it's GPS position
	*/
    public func toDevicePositionUpdate() -> C8yDevice {
            
        var pd: C8yDevice = C8yDevice(self.device.c8yId!)
        
        if (self.position != nil) {
            pd.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
        } else {
            pd.position = self.device.position
        }
        
        return pd
    }

	/**
	Fetches latest device metrics, views will be updated automatically via published  attribute `measurements`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
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
				
				self.reloadMetrics = false
            }) { results in
                self.measurements = results
        }.store(in: &self._cancellable)
    }
    
	/**
	Fetches latest device metrics from Cumulocity
	- returns: Publisher containing latest device measurements
	*/
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
    
	/**
	Fetches latest device event logs, views will be updated automatically via published  attribute `events`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
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
				
				self.reloadLogs = false
            }) { results in
                self.events = results
        }.store(in: &self._cancellable)
    }
    
	/**
	Fetches latest device events from Cumulocity
	- returns: Publisher containing latest device events
	*/
    public func fetchEventLogsForToday() -> AnyPublisher<[C8yEvent], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                    
        return C8yEventsService(self.conn!).get(source: self.device.c8yId!, pageNum: 0).map({response in
            
            return response.content!.events
            
        }).eraseToAnyPublisher()
    }

	/**
	Fetches latest device operation history, views will be updated automatically via published  attribute `operationHistory`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
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
				
				self.reloadOperations = false
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
    
	/**
	Fetches latest device operation history from Cumulocity
	- returns: Publisher containing latest operation history
	*/
    public func fetchOperationHistory() -> AnyPublisher<[C8yOperation], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                      
        return C8yOperationService(self.conn!).get(self.device.c8yId!).map({response in
            return response.content!.operations
        }).eraseToAnyPublisher()
    }
    
	/**
	Fetches latest device alarms,  views will be updated automatically via published  attribute `alarms`
	You must ensure that your SwiftUI View references this class object either as a @ObservedObject or @StateObject
	*/
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
				
				self.reloadAlarms = false
            }) { results in
                self.alarms = results
        }.store(in: &self._cancellable)
    }
    
	/**
	Fetches latest device alarms from Cumulocity
	- returns: Publisher containing latest alarms
	*/
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
    
	/**
	Fetches latest device prefered metric from Cumulocity
	- returns: Publisher containing latest preferred metric
	*/
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
            } else if (self.primaryDataPoint().count > 0) {
                let metric: [C8yDataPoints.DataPoint] = self.primaryDataPoint()
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
     
	/**
	Initiates a background thread to periodically refetch the preferred metric from Cumulocity.
	Changes will be issued via the publisher returned from the method `primaryMetricPublisher(preferredMetric:refreshInterval:)`
	- parameter preferredMetric: label of the measurement to periodically fetched requires both name and series separated by a dot '.' e.g. 'Temperature.T', if not provided will attempt to use first data point in `dataPoints`
	- parameter refreshInterval: period in seconds in which to refresh values
	*/
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
		
		if (self._refreshInterval > -1 && (preferredMetric != nil || self.primaryDataPoint().count > 0)) {
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
            self.isMonitoring = false
        }
		
		if (_deviceOperationHistoryTimer != nil) {
			self._deviceOperationHistoryTimer?.suspend()
		}
    }
    
	/**
	Starts a background thread to refresh operation history periodically
	- parameter refreshInterval: period in seconds in which to refresh values
	*/
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
	
	/**
	Returns the current status for given operation type, Will return only latest valeu if multiple operations exist for the same type
	- parameter type: The type of operation to be queried
	- returns: The latest operation for the given type or nil if none found
	*/
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
    
	/**
	Downloads a binary attachment with the given id from Cumolocity and also caches the result in `lastAttachment`
	
	You can obtain a list of attachments related to this device via the attribute`C8yDevice.attachments`, If the attachment was uploaded via `addAttachment(filename:fileType:content)`
	
	- parameter id: c8y Internal id of binary attachment to be downloaded
	- returns: Publisher containing binary data
	*/
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

	/**
	Uploads the given binary content to Cumulocity and updates the managed object associated with this device to record the resulting binary attachment id.
	The resulting id can be referenced via the string list attribute `C8yDevice.attachments`, which in turn is stored in Cumulocity via the attribute `C8Y_MANAGED_OBJECTS_ATTACHMENTS`
	- parameter filename: name of file from which data originated
	- parameter fileType: content type e.g. application/json or application/png
	- parameter content: Binary data encoded in a Data object
	- returns: Publisher with cumulocity internal id associated with uploaded binary data
	*/
    public func addAttachment(filename: String, fileType: String, content: Data) -> AnyPublisher<String, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

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

            self.device.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] = C8yStringCustomAsset(String.make(array: self.device.attachments)!)
            
            return self.lastAttachment!.id!
        }).eraseToAnyPublisher()
    }
    
	/**
	Replaces the existing attachment reference and uploades the content to  Cumulocity. The existing attachment reference is replaced with the new one.
	It does delete the existing binary attachment from Cumulocity only the reference to existing attachment contained in the managed object attrbiute `C8Y_MANAGED_OBJECTS_ATTACHMENTS`
	and the device's `C8ytDevice.attachments` attribute
	
	- parameter index: Index into array `C8yDevice.attachments` to indicate which attachment should be replaced.
	- parameter filename: name of file from which data originated
	- parameter fileType: content type e.g. application/json or application/png
	- parameter content: Binary data encoded in a Data object
	- returns: Publisher with cumulocity internal id associated with uploaded binary data
	*/
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
    
    private func primaryDataPoint() -> [C8yDataPoints.DataPoint] {
               
       //TODO: link this to C8yModels
       
        if (device.dataPoints != nil && device.dataPoints!.dataPoints.count > 0) {
            return device.dataPoints!.dataPoints
       } else {
            return []
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
	
    private func makeError<T>(_ response: JcRequestResponse<T>) -> Error? {

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
