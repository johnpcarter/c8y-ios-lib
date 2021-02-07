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
			if (position != nil && (position!.latitude != device.position?.lat || position!.longitude != device.position?.lng)) {
                device.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
            }
        }
    }

	@Published public var model: C8yModel
	
	/**
	Returns a list of the move recent movement for this device based on emitted events for `C8yLocationUpdate_EVENT`
	This will return an empty set if no recent movement has been detected i.e. no recent events have been sent.
	
	- returns: List of `CLLocationCoordinate2D` with most recent being at the end of the array
	*/
	@Published public var tracking: [CLLocationCoordinate2D] = []
	
	/**
	Set to true if you want reload all device data and associated values, will reset back to false once reload has completed
	*/
	@Published public var reload: Bool = false {
		didSet {
			
			if (self.reload) {
				self.reloadDevice()
			}
		}
	}
	
	/**
	Set to true if you want to load latest metrics for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadMetrics: Bool = false {
        didSet {
            
            if (self.reloadMetrics) {
				self._deviceMetricsNotifier.reload(self)
            }
        }
    }
    
	/**
	Set to true if you want to load latest logs for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadLogs: Bool = false {
        didSet {
               
            if (self.reloadLogs) {
				self._deviceEventsNotifier.reload(self)
            }
        }
    }
    
	/**
	Set to true if you want to load latest alarms for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadAlarms: Bool = false {
        didSet {
            if (self.reloadAlarms) {
				self._deviceAlarmsNotifier.reload(self)
            }
        }
    }
    
	/**
	Set to true if you want to load latest operations history for the device, value will reset back to false once reload has completed
	*/
    @Published public var reloadOperations: Bool = false {
        didSet {
            if (self.reloadOperations) {
				self._deviceOperationsNotifier.reload(self)
            }
        }
    }
	
	private var _ignore: Bool = false
	
	/**
	Set to true to activate maintenance mode for device in Cumulocity.
	@see `toggleMaintenanceMode()`
	*/
	@Published public var maintenanceMode: Bool {
		didSet {
			do {
				if (_ignore) {
					return;
				}
				
				try toggleMaintainanceMode()
			} catch {
				_ignore = true
				self.maintenanceMode = !self.maintenanceMode
				_ignore = false
			}
		}
	}
	
	/**
	Returns true if the device has been provisioned with its network.

	*/
	@Published public private(set) var isDeployed: Bool
	
	/**
	Returns the current battery level if available (returns -2 if not applicable)
	*/
	@Published public internal(set) var batteryLevel: Double = -2
	
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
	public internal(set) var primaryMetric: C8yDeviceMetricsNotifier.Measurement = C8yDeviceMetricsNotifier.Measurement()
	
	/**
	Returns the primary metric history
	*/
	@Published public internal(set) var primaryMetricHistory: C8yDeviceMetricsNotifier.MeasurementSeries = C8yDeviceMetricsNotifier.MeasurementSeries()
    
	/**
	Returns all available measurements captured by Cumulocity for this device
	*/
    @Published public internal(set) var measurements: [String:[C8yMeasurement]] = [:]

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
	
	internal var _restartTime: Date? = nil
	
	/**
	Convenience attribute that caches the last binary file associated with the device that was fetched from Cumulocity
	via the method `attachmentForId(id)` or posted via the method `addAttachment(filename:fileType:content:)`
	*/
    public internal(set) var lastAttachment: JcMultiPartContent.ContentPart? = nil

	/**
	Associated Cumulocity connection info that allows this object to fetch/post data
	*/
    public var conn: C8yCumulocityConnection?
    
	private var _cachedResponseInterval: Int = 30
	
	private var _deviceMetricsNotifier: C8yDeviceMetricsNotifier = C8yDeviceMetricsNotifier()
	private var _deviceOperationsNotifier: C8yDeviceOperationsNotifier = C8yDeviceOperationsNotifier()
	private var _deviceEventsNotifier: C8yDeviceEventsNotifier = C8yDeviceEventsNotifier()
	private var _deviceAlarmsNotifier: C8yDeviceAlarmsNotifier = C8yDeviceAlarmsNotifier()

	/**
	Default constructor representing a new `C8yDevice`
	*/
    public init() {
        self.device = C8yDevice()
		self.maintenanceMode = false;
		self.isDeployed = false;
		self.model = C8yModel()
    }
	
    /**
	Constructor to create a mutable device for the give device
	- parameter device: Device to which we want to fetch mutable data
	- parameter connection: Connection details in order to connect to Cumulocity
	*/
	public init(_ device: C8yDevice, connection: C8yCumulocityConnection, model: C8yModel? = nil) {
        
        self.device = device
        self.conn = connection
		self.model = model != nil ? model! : C8yModel()
		self.maintenanceMode = device.requiredResponseInterval == -1
		self.isDeployed = device.isDeployed;
		
		if (self.device.wrappedManagedObject.properties[C8Y_MEASUREMENT_BATTERY] != nil) {
			self.batteryLevel = (self.device.wrappedManagedObject.properties[C8Y_MEASUREMENT_BATTERY]! as! C8yDoubleCustomAsset).value
		} else if (self.device.wrappedManagedObject.properties[C8Y_ALT_MEASUREMENT_BATTERY] != nil) {
			self.batteryLevel = (self.device.wrappedManagedObject.properties[C8Y_ALT_MEASUREMENT_BATTERY]! as! C8yDoubleCustomAsset).value
		}
		
        if (self.device.position != nil) {
            self.position = CLLocationCoordinate2D(latitude: device.position!.lat, longitude: device.position!.lng)
        }
		
		self._deviceMetricsNotifier.deviceWrapper = self
		self._deviceEventsNotifier.deviceWrapper = self
		self._deviceAlarmsNotifier.deviceWrapper = self
		self._deviceOperationsNotifier.deviceWrapper = self

		self.getExternalIds()
    }
    
    deinit {
		self.stopMonitoring()
    }
	
	public func reloadDevice() {
		
		C8yManagedObjectsService(self.conn!).get(self.device.c8yId!)
			.receive(on:RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				self.reloadAllAssociatedData()
				self.reload = false
			}, receiveValue: { response in
				
				if (response.content != nil) {
					do {
						self.device = try C8yDevice(response.content!)
					} catch {
						//TODO: is it okay to ignore error
					}
				}
			}))
	}
	       
	public func reloadAllAssociatedData() {
	
		self._deviceMetricsNotifier.reload(self)
		self._deviceOperationsNotifier.reload(self)
		self._deviceEventsNotifier.reload(self)
		self._deviceAlarmsNotifier.reload(self)
	}
	
	public func startMonitorForPrimaryMetric(_ preferredMetric: String?, refreshInterval: Double) {
	
		self._deviceMetricsNotifier.deviceWrapper = self
		
		self._deviceMetricsNotifier.startMonitorForPrimaryMetric(preferredMetric, refreshInterval: refreshInterval)
	}
	
	public func stopMonitoring() {
		
		self._deviceMetricsNotifier.stopMonitoring()
		self._deviceOperationsNotifier.stopMonitoring()
		self._deviceEventsNotifier.stopMonitoring()
		self._deviceAlarmsNotifier.stopMonitoring()
	}
	
	public func trackDevice() {
	
		self._deviceEventsNotifier.deviceWrapper = self

		self._deviceEventsNotifier.listenForNewEvents()
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completed in
				
			}, receiveValue: { event in
				
				if (event.type == C8yLocationUpdate_EVENT && event.position != nil) {
					let p = CLLocationCoordinate2D(latitude: event.position!.lat, longitude: event.position!.lng)
					
					self.position = p
					self.tracking.insert(p, at: 0)
				}
			}))
	}
	
	public func stopTracking() {
		self._deviceEventsNotifier.stopMonitoring()
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
			.subscribe(Subscribers.Sink(receiveCompletion: { (completion) in
				// nothing to do
				
				self._ignore = true
				self.maintenanceMode = self.device.requiredResponseInterval == -1
				self._ignore = false
				
			}) { response in
				
				self.device.wrappedManagedObject.availability = C8yManagedObject.Availability(status: self.device.wrappedManagedObject.requiredAvailability!.responseInterval == -1 ? .MAINTENANCE : .AVAILABLE, lastMessage: self.device.wrappedManagedObject.availability?.lastMessage ?? Date())
		})
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
				
			try self.sendOperation(op)
			.subscribe(Subscribers.Sink(receiveCompletion: { (completion) in
					
				switch completion {
					case .failure(let error):
						print(error)
					case .finished:
						print("done")
				}
					
				self.isRestarting = false

			}) { (response) in
				self.operationHistory.insert(op, at: 0)
				self.objectWillChange.send()
			})
		} catch {
			self.isRestarting = false
		}
	}
	
	/**
	Submits an operation to switch the relay and also synchronises the device relay attribute `C8yDevice.relayState`.
	*NOTE* - Only applicable if the device or agent supports it.
	*/
    public func toggleRelay() throws -> AnyPublisher<C8yOperation, Error> {
    
        var state: C8yManagedObject.RelayStateType = .CLOSED
        
		if (self.device.relayState != nil) {
			if (self.device.relayState! == .CLOSED) {
                state = .OPEN
            } else {
                state = .CLOSED
            }
        }
		
		var op = C8yOperation(forSource: self.device.c8yId!, type: C8Y_OPERATION_RELAY, description: "set relay state to '\(state.rawValue)'")
		op.operationDetails = C8yOperation.OperationDetails(C8Y_OPERATION_RELAY_STATE, value: state.rawValue)

		return try self.sendOperation(op).map({ op -> C8yOperation in
			
			self.device.relayState = state
			
			print("========= toggle response")

			do { try self.updateDeviceProperty(withKey: C8Y_OPERATION_RELAY, value: C8yStringCustomAsset(state.rawValue))
			} catch {
				// ignore
				
			}
			
			return op
		}).eraseToAnyPublisher()
	}
    
	/**
	Submits the given operation to Cumulocity and records it in `operationHistory`
	The operation will have an initial status of PENDING
	
	- parameter operation: The `C8yOperation` to be posted to Cumulocity for eventual execution by the device.
	- returns: Publisher with cumulocity internal id of new operation.
	- throws: Invalid operation
	*/
	public func sendOperation(_ op: C8yOperation) throws -> AnyPublisher<C8yOperation, Error> {
					
		return try self._deviceOperationsNotifier.run(op, deviceWrapper: self)
			.receive(on: RunLoop.main)
			.map({ updatedOperation -> C8yOperation in
				
				print("========= send operation responded")
				
				if (updatedOperation.model.value != nil) {
										
					do {
						
						let simpleValue = updatedOperation.operationDetails.values[updatedOperation.model.value!]
												
						if (simpleValue is C8yStringCustomAsset) {
							try self.updateDeviceProperty(withKey: updatedOperation.model.value!, value: simpleValue as! C8yStringCustomAsset)
						} else if (simpleValue is C8yDoubleCustomAsset) {
							try self.updateDeviceProperty(withKey: updatedOperation.model.value!, value: simpleValue as! C8yDoubleCustomAsset)
						} else if (simpleValue is C8yBoolCustomAsset) {
							try self.updateDeviceProperty(withKey: updatedOperation.model.value!, value: simpleValue as! C8yBoolCustomAsset)
						}
					} catch {
						// ignore
					}
				}
				
				return updatedOperation
			}).eraseToAnyPublisher()
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
	Updates the server side Cumulocity Managed Object based on the properties provided here.
	- parameter withKey: name of the managed object attribute to updated/added
	- parameter value: The value to be assigned
	- throws: Invalid key/value pair
	*/
	public func updateDeviceProperty<T:C8ySimpleAsset>(withKey key: String, value: T) throws  {
		
		try C8yManagedObjectsService(self.conn!).put(C8yManagedObject.init(self.device.c8yId!, properties: Dictionary(uniqueKeysWithValues: zip([key], [value]))))
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { error in
				self.objectWillChange.send()
			}, receiveValue: { obj in
				// reflect changes in local copy
				
				self.device.wrappedManagedObject.properties[key] = value
			}))
	}
    
	/**
	Deletes the device from Cumulocity, device must have been deprovisioned beforehand.
	
	NOTE: If you are the using the `C8yAssetCollection` class to present your assets then you will need to also call the AssetCollection
	`remove()` method to remove the device locally.
	
	- returns: Publisher with success/failure of operation
	- throws: if device is provisioned
	*/
	public func delete() throws -> AnyPublisher<Bool, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		guard !self.device.network.provisioned else {
			throw OperationError.deprovisionBeforehand
		}
			
		return C8yManagedObjectsService(self.conn!).delete(id: self.device.c8yId!).map({ response -> Bool in
			return response.content!
		}).eraseToAnyPublisher()
	}
	
	public enum OperationError: Error {
		case deprovisionBeforehand
	}
	
	/**
	Submits the given event to Cumulocity and records it in `events`
	
	*NOTE* - `C8yLocationUpdate_EVENT` type events will also update the devices `C8yMutableDevice.position` attribute as a side effect
	
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
            return Just(self.lastAttachment!).mapError({ _ -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
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
        
        return C8yBinariesService(self.conn!).post(name: "\(device.c8yId!)-\(fname)", contentType: fileType, content: content)
			.receive(on: RunLoop.main)
			.map({ response in
            
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
	
	/**
	Provides a publisher that can be used to listen for periodic updates to primary metric
	The refresh is based on the devices `C8yDevice.requiredResponseInterval` property
	
	- parameter preferredMetric: label of the measurement to periodically fetched requires both name and series separated by a dot '.' e.g. 'Temperature.T'
	- parameter autoRefresh: set to true if you want the value to be refreshed automatically, false to only update once
	- returns: Publisher that will issue updated metrics periodically
	*/
	public func primaryMetricPublisher(preferredMetric: String?, autoRefresh: Bool = false) -> AnyPublisher<C8yDeviceMetricsNotifier.Measurement, Never> {
		
		self._deviceMetricsNotifier.deviceWrapper = self
		
		return self._deviceMetricsNotifier.primaryMetricPublisher(preferredMetric: preferredMetric ?? self.model.preferredMetric, autoRefresh: autoRefresh)
	}
	
    private func primaryDataPoint() -> [C8yDataPoints.DataPoint] {
               
       //TODO: link this to C8yModels
       
        if (device.dataPoints != nil && device.dataPoints!.dataPoints.count > 0) {
            return device.dataPoints!.dataPoints
       } else {
	
            return []
       }
    }
    
	public func operation(for type: String) -> C8yOperation {
		
		let template = self.model.operationTemplate(for: type)
		var op = C8yOperation(forSource: self.device.c8yId!, type: type, description: template.description ?? "Operation sent from c8y iphone app")
		
		op.model = template
		
		if (template.value != nil) {
			let v = self.device.wrappedManagedObject.properties[template.value!]
			
			if (v != nil && v is C8yStringCustomAsset) {
				op.operationDetails = C8yOperation.OperationDetails(template.value!, value: (v as! C8yStringCustomAsset).value)
			} else {
				op.operationDetails = C8yOperation.OperationDetails(template.value!, value: "")
			}
		}
		
		return op
	}
	
	private func getExternalIds() {
	
		C8yManagedObjectsService(self.conn!).externalIDsForManagedObject(device.wrappedManagedObject.id!)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in

		}, receiveValue: { response in
			self.device.setExternalIds(response.content!.externalIds)
			
		}))
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
