//
//  NewDevice.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine
import CoreLocation

import SwiftUI

/**
Use this class directly from a SwiftUI Form View to allow the wrapped device to be edited.

Changes to fields are published to the attribute `onChange` and can be acted on in your View with the following code.
Duplicates are removed and changes are debounced into 1 event every 3 seconds, this means you could automatically
persist changes to Cumulocity via the method `C8yAssetCollection.saveObject(_)` without having it called
on each key press made by the user.

```
VStack {
	...
}.onReceive(self.editableDevice.onChange) { editableDevice in
	
	do {
		try self.assetCollection.saveObject(editableDevice.toDevice()) { success, error in
	
		}
	} catch {
		print("error \(error.localizedDescription)")
	}
}
```
*/
public class C8yEditableDevice: ObservableObject, Equatable {
        
    public static func == (lhs: C8yEditableDevice, rhs: C8yEditableDevice) -> Bool {
        return lhs.c8yId == rhs.c8yId
    }
    
	/**
	true if changes have been made to any of the attributes, you will need to set it back to false explicitly once changed
	e.g. after saving changes via the `onChange` publisher
	*/
    public var haveChanges: Bool = false
    
	/**
	Indicates if underlying device is managed by a parent device recognised by c8y as a router etc.
	*/
	public var isChildDevice: Bool = false
	
	/**
	external id to be modified.
	*/
    @Published public var externalId: String = "" {
        didSet {
            if (!self._ignoreChanges) {
                self.idChanged.send(self.externalId + self.externalIdType)
            }
        }
    }
    
	/**
	associated external id type of external id
	*/
    @Published public var externalIdType: String = C8Y_SERIAL_ID {
        didSet {
            if (!self._ignoreChanges) {
                self.idChanged.send(self.externalId + self.externalIdType)
            }
        }
    }
    
	/**
	Read only copy of Cumulocity internal id for device, empty String if editing a new device that has not yet been
	submitted to Cumulocity
	*/
    @Published public private(set) var c8yId: String = ""
    
	/**
	Name of the device to be edited
	*/
    @Published public var name: String = "" {
        didSet {
            self.emitDidChange(self.name)
        }
    }
    
	/**
	The device type
	*/
    @Published public var type: String = "" {
        didSet {
            self.emitDidChange(self.type)
        }
    }
    
    @Published public var revision: String = "" {
        didSet {
            self.emitDidChange(self.revision)
        }
    }
    
    @Published public var firmware: String = "" {
        didSet {
            self.emitDidChange(self.firmware)
        }
    }
    
	@Published public var notes: String = "" {
		didSet {
			self.emitDidChange(self.notes)
		}
	}
	
	@Published public var requiredResponseInterval: Int = -1 {
		didSet {
			self.emitDidChange(String(self.requiredResponseInterval))
		}
	}

	@Published public var hardware: Hardware = Hardware()
	    
	@Published public var network: Network = Network()
    
    @Published public var category: C8yDevice.Category = .Unknown {
        didSet {
            self.emitDidChange(self.category.rawValue)
        }
    }
    
    @Published public var webLink: String = "" {
		didSet {
			self.emitDidChange(self.webLink)
		}
	}
	
	@Published public var addressLine: String = "" {
		didSet {
			self.emitDidChange(self.addressLine)
		}
	}
	
	@Published public var city: String = "" {
		didSet {
			self.emitDidChange(self.city)
		}
	}
	
	@Published public var postCode: String = "" {
		didSet {
			self.emitDidChange(self.postCode)
		}
	}
	
	@Published public var country: String = "" {
		didSet {
			self.emitDidChange(self.country)
		}
	}
	
	private var _isDeployed: Bool = false
	
	/**
	Returns whether the device has been via the associated network. This field reflects last status from Cumulocity unless the network settings change
	*/
	public var isDeployed: Bool {
		if (self._networkTypeOriginal != self.network.type || self._networkProviderOriginal != self.network.provider || self._networkInstanceOriginal != self.network.instance) {
			return self.network.type == C8Y_NETWORK_NONE ? true : false
		} else {
			return _isDeployed
		}
	}
	
	/**
	Returns true if this device has not been saved to Cumulocity
	*/
    public var isNew: Bool {
        get {
            return c8yId.isEmpty
        }
    }
    
	/**
	Use this publisher to listen for changes to the external id, removes duplicates and debounces to minimise events to maximum 1 every 3 seconds
	*/
    public var externalIdChanged: AnyPublisher<String, Never> {
        return self.idChanged
			.debounce(for: .milliseconds(3000), scheduler: RunLoop.main)
            .removeDuplicates()
            .map { input in
                return self.externalId
            }.eraseToAnyPublisher()
    }
        
	/**
	Use this publisher to listen for changes to any of device attribute, removes duplicates and debounces to minimise events to maximum 1 every 3 seconds.
	*/
    public var onChange: AnyPublisher<C8yEditableDevice, Never> {
        return self.didChange
		.drop(while: { v in
			return !self.haveChanges
		 })
        .debounce(for: .milliseconds(3000), scheduler: RunLoop.main)
        .removeDuplicates()
        .map { input in
            return self
        }.eraseToAnyPublisher()
    }
    
	private let idChanged = PassthroughSubject<String, Never>()
	private let didChange = CurrentValueSubject<String, Never>("")

    private var _ignoreChanges: Bool = false
    private var _lastPosition: C8yManagedObject.Position?
	private var _externalIds: [String:C8yExternalId] = [:]
	private var _networkTypeOriginal: String = ""
	private var _networkProviderOriginal: String = ""
	private var _networkInstanceOriginal: String = ""
	private var _cachedPos: C8yManagedObject.Position? = nil
	private var _isAgent: Bool = false
	private var _deviceWrapper: C8yMutableDevice? = nil
	
	/**
	Default constructor to manage a new blank editable device
	*/
    public init() {
    }
    
	/**
	Constructor to allow an existing device to be edited.
	*/
	public convenience init(_ device: C8yDevice, networkTypes: C8yNetworkAgentManager? = nil) {
        
        self.init()
        
		self.mergeDevices(device, networkTypes: networkTypes)
        
		self.isChildDevice = device.isChildDevice
		self._externalIds = device.externalIds
		self._isDeployed = device.isDeployed
		self._networkTypeOriginal = device.network.type
		
		if (device.network.type != C8Y_NETWORK_NONE) {
			self._networkProviderOriginal = device.network.provider ?? ""
			self._networkInstanceOriginal = device.network.instance ?? ""
		} else {
			self._networkProviderOriginal = device.network.lan?.name ?? ""
			self._networkInstanceOriginal = device.network.wan?.ip ?? ""
		}
		
        if (device.externalIds.count > 0) {
            self.externalId = device.externalIds.values.first!.externalId
            self.externalIdType = device.externalIds.values.first!.type
        } else {
            self.externalId = "-undefined-"
        }
		
		self._isAgent = device.wrappedManagedObject.isAgent
    }
    
	/**
	Constructor to allow an existing device to be edited.
	*/
	public convenience init(deviceWrapper: C8yMutableDevice, networkTypes: C8yNetworkAgentManager? = nil) {
		self.init(deviceWrapper.device, networkTypes: networkTypes)
		self._deviceWrapper = deviceWrapper
	}
	
	/**
	Constructor for new device with the given attributes
	
	*/
    public init(_ id: String, name: String, supplierName: String?, modelName: String, category: C8yDevice.Category, operations: [String], revision: String?, firmware: String?,  requiredResponseInterval: Int, networkTypes: C8yNetworkAgentManager? = nil) {
        
        self.externalId = id
        self.externalIdType = "UUID"
        self.name = name
        
        if (supplierName != nil) {
			self.hardware.supplier = supplierName!
        }
        
		self.hardware.model = modelName
        self.category = category
        self.requiredResponseInterval = requiredResponseInterval
        
        if (revision != nil) {
            self.revision = revision!
        }
        
        if (firmware != nil) {
            self.firmware = firmware!
        }
		
		self.network.set(self, networkTypes: networkTypes)
		self.hardware.set(self, supplier: supplierName, model: modelName)
    }
    
	/**
	Clears all of the editable fields without triggering change event publishers
	*/
    public func clear() {
            
        self._ignoreChanges = true
        
        self.externalId = ""
        self.c8yId = ""
        self.notes = ""
        self.webLink = ""
        self.name = ""
        self.revision = ""
        self.firmware = ""
		self.network.clear()
		self.hardware = Hardware()
		self.hardware.set(self)
		
        self._ignoreChanges = false
    }
    
	/**
	Returns true if the minimum number of fields for a device in Cumulocity have been assigned
	- parameter willDeploy: if set to true network parameters must be fully specified; if false networking fields are ignored
	- returns: true if minimum fields are set,
	*/
	public func isValid(_ willDeploy: Bool) -> Bool {
		return (!self.name.isEmpty || !self.hardware.model.isEmpty) && !self.externalId.isEmpty && !self.externalIdType.isEmpty && self.isValidNetwork(willDeploy)
	}
      
	public func isValidNetwork(_ willDeploy: Bool) -> Bool {
		return self.network.isValid(willDeploy)
	}
	
	/**
	Returns a `C8yDevice` instance with all of the edited fields included
	*/
    public func toDevice() -> C8yDevice {
        return toDevice(_cachedPos)
    }
    
	/**
	Returns a `C8yDevice` instance with all of the edited fields included and the provided GPS position
	*/
	public func toDevice(_ loc: CLLocation?) -> C8yDevice {
	
		var pos: C8yManagedObject.Position? = nil
		
		if (loc != nil) {
			pos = C8yManagedObject.Position(lat: loc!.coordinate.latitude, lng: loc!.coordinate.longitude, alt: loc!.altitude)
		}
		
		return toDevice(pos)
	}
	
	/**
	Returns a `C8yDevice` instance with all of the edited fields included and the provided GPS position
	*/
    public func toDevice(_ position: C8yManagedObject.Position?) -> C8yDevice {
        
        self._cachedPos = position
        
		var device: C8yDevice = C8yDevice(self.c8yId, serialNumber: self.externalIdType == C8Y_SERIAL_ID && self.externalId != "-undefined-" ? self.externalId : nil, withName: self.name, type: self.category.rawValue, supplier: self.hardware.supplier != "generic" ? self.hardware.supplier : nil, model: self.hardware.model, notes: self.notes, requiredResponseInterval: self.requiredResponseInterval, revision: self.revision, category: self.category)
                
        if (self._lastPosition != nil) {
            device.position = self._lastPosition
        }
        
        device.webLink = self.webLink
        
        if (self.type != "") {
            device.wrappedManagedObject.type = self.type
        } else {
            device.wrappedManagedObject.type = "c8yDevice"
        }
        				
		device.externalIds = self._externalIds
		
        if (self.externalId != "-undefined-") {
            device.externalIds[self.externalIdType] = C8yExternalId(withExternalId: self.externalId, ofType: self.externalIdType)
        }
        
        if (position != nil) {
            device.wrappedManagedObject.updatePosition(latitude: position!.lat, longitude: position!.lng, altitude:  position?.alt)
		}
        
		if (self._isAgent) {
			device.wrappedManagedObject.isAgent = true
		}
		
		return self.network.updateNetwork(forDevice: device)
    }
    
	public func mergeDevices(_ device: C8yDevice, group: C8yGroup? = nil, networkTypes: C8yNetworkAgentManager? = nil) {
    
        self._ignoreChanges = true
        
		self._deviceWrapper?.device = device
		
        if (device.c8yId != nil) {
            self.c8yId = device.c8yId ?? ""
        }
    
        if (device.name != device.model && device.name != device.type) {
            self.name = device.name
        }

        if (device.supplier != C8Y_UNDEFINED_SUPPLIER) {
			self.hardware.supplier = device.supplier
        }
        
        if (device.model != C8Y_UNDEFINED_MODEL) {
			self.hardware.model = device.model
        }
        
        if (device.revision != nil) {
            self.revision = device.revision!
        }
        
        if (device.firmware != nil) {
            self.firmware = device.firmware!
        }
        
        if (device.position != nil) {
            self._lastPosition = device.position
		} else if (group != nil && group!.info.address != nil) {
			self.addressLine = group!.info.address!.addressLine1 ?? ""
			self.city = group!.info.address!.city ?? ""
			self.postCode = group!.info.address!.postCode ?? ""
			self.country = group!.info.address!.country ?? ""			
		}
        
        if (device.notes != nil) {
            self.notes = device.notes!
        }
        
        if (device.requiredResponseInterval != nil) {
            self.requiredResponseInterval = device.requiredResponseInterval!
        }
        
        if (device.externalIds.count > 0) {
            self.externalIdType = device.externalIds.keys.first!
            self.externalId = device.externalIds[self.externalIdType]!.externalId
		} else if (device.serialNumber != nil) {
			self.externalId = device.serialNumber!
			self.externalIdType = C8Y_SERIAL_ID
		}
                
        self.type = device.type != nil ? device.type! : ""
        self.category = device.deviceCategory

        if (device.webLink != nil) {
            self.webLink = device.webLink!
        }
        
		self.network.set(self, device: device, networkTypes: networkTypes)
		self.hardware.set(self, device: device)
		
        self._ignoreChanges = false
    }
    
	public func models(_ modelsRef: C8yDeviceModels) -> [String:String] {
		return self.hardware.models(modelsRef)
	}
	
    private func emitDidChange(_ v: String) {
        if (!self._ignoreChanges) {
            self.haveChanges = true
			if (self._deviceWrapper != nil) {
				self._deviceWrapper!.device = self.toDevice()
			}
			self.objectWillChange.send()
            self.didChange.send(v)
        }
    }
	
	public class Network: ObservableObject {
	
		public var networkTypesManager: C8yNetworkAgentManager?
		public var networkType: C8yNetworkAgent?
		
		private var _editableDevice: C8yEditableDevice?

		private var _lastTypeValue: String? = nil
		private var _other: C8yNetwork? = nil
		
		private var _ignore: Bool = false
		
		@Published public var type: String = C8Y_NETWORK_NONE {
			willSet(v) {
				self._lastTypeValue = self.type
			}
			didSet {
				
				if (_ignore) {
					return
				}
				
				if (self.type != self._lastTypeValue) {
					if (type != C8Y_NETWORK_NONE) {
						self.networkType = networkTypesManager?.networkTypes[self.type]
					} else {
						self.networkType = nil
					}
					
					if (self.networkType?.providers.count == 1) {
						self.provider = self.networkType!.providers[0].name
					} else {
						self.provider = ""
					}
					
					self.updateRequiredNetworkProperties(self._editableDevice!.toDevice())
					
					self._editableDevice?.emitDidChange(self.type)
				}
			}
		}
		
		public var providers: [C8yNetworkProvider] {
			return networkType?.providers ?? []
		}
		
		private var _lastProviderValue: String? = nil
		
		@Published  public var provider: String = "" {
			willSet(v) {
				self._lastProviderValue = provider
			}
			didSet {
				
				if (_ignore) {
					return
				}
				
				if (self._lastProviderValue != self.provider) {
					self.instance = ""
					self._editableDevice?.emitDidChange(self.provider)
				}
			}
		}
		
		public var instances: [C8yNetworkProviderInstance] {
			return networkType?.provider(for: self.provider )?.connections ?? []
		}
		
		@Published public var instance: String = "" {
			didSet {
				
				if (_ignore) {
					return
				}
				
				self._editableDevice?.emitDidChange(self.instance)

			}
		}
		
		@Published public var properties: [String:EditableProperty] = [:] {
		
			didSet {
				
				if (_ignore) {
					return
				}
				
				self._editableDevice?.emitDidChange(self.instance)
			}
		}
		
		init() {
			
		}
		
		func isValid(_ willDeploy: Bool) -> Bool {
		
			if (self.type == C8Y_NETWORK_NONE || !willDeploy) {
				return true
				
			} else if (!self.provider.isEmpty && !self.instance.isEmpty) {
				// check props
				
				var isValid = true
				let device = self._editableDevice!.toDevice()
				
				self.networkType?.properties.forEach( { k, p in
					
					if (p.required && (self.properties[k] == nil || self.properties[k]!.value.wrappedValue.isEmpty)) {
						
						// what about derived values
						
						if (p.lookupValue(source: device.wrappedManagedObject) == nil) {
							isValid = false
						}
					}
				})
				
				return isValid
			} else {
				return false
			}
		}
		
		func updateNetwork(forDevice device: C8yDevice) -> C8yDevice {
					
			let network = C8yNetwork(type: self.type, provider: self.provider, instance: self.instance)
			var d = device

			d.network = network
			
			if (self.networkType?.deviceType != nil) {
				d.wrappedManagedObject.type = self.networkType!.deviceType!
			}
			
			// form edited properties
			
			self.properties.forEach({ k, p in
						
				d = self._update(k: k, p: p.info, device: d, value: p.value.wrappedValue)
			})
			
			// what about derived properties
			
			self.networkType?.properties.forEach( { k, p in // k is the name of the attribute
				
				if (self.properties[k] == nil) {
					
					// only used derived value if not set in form

					let v =  p.lookupValue(source: d.wrappedManagedObject)
					
					if (v != nil) {
						d = self._update(k: k, p: p, device: d, value: v!)
					}
				}
			})
			
			return d
		}
		
		func _update(k: String, p: C8yProperty, device: C8yDevice, value: Any?) -> C8yDevice {
			
			if (value == nil) {
				return device
			}
			
			var d = device
			var key = k
			
			if (p.source != nil && p.source!.endsWith(".\(k)")) {
				// assume source attribute should be updated with name value even though path has not been set
				key = p.source!
			}
			
			if (key == "network.provider") {
				d.wrappedManagedObject.network!.provider = value as? String
			} else if (key == "network.instance") {
				d.wrappedManagedObject.network!.instance = value  as? String
			} else if (key == "network.lan.ip") {
				
				if (d.wrappedManagedObject.network!.lan == nil) {
					d.wrappedManagedObject.network!.lan = C8yNetwork.LAN(ip: value as! String, enabled: true)
				} else {
					d.wrappedManagedObject.network!.lan!.ip = value  as! String
				}
			} else if (key == "network.lan.name") {
				
				if (d.wrappedManagedObject.network!.lan == nil) {
					d.wrappedManagedObject.network!.lan = C8yNetwork.LAN(ip: "", name: value as? String, enabled: true)
				} else {
					d.wrappedManagedObject.network!.lan!.name = value as? String
				}
			} else if (key == "network.lan.enabled") {
				
				if (d.wrappedManagedObject.network!.lan == nil) {
					d.wrappedManagedObject.network!.lan = C8yNetwork.LAN(ip: "", name: "", enabled: value! is String ? Bool(value as! String)! : value! as! Bool)
				} else {
					d.wrappedManagedObject.network!.lan!.enabled = value! is String ? Bool(value as! String)! : value! as! Bool
				}
			} else if (key == "network.wan.ip") {
				if (d.wrappedManagedObject.network!.wan == nil) {
					d.wrappedManagedObject.network!.wan = C8yNetwork.WAN(ip: value as! String)
				} else {
					d.wrappedManagedObject.network!.wan!.ip = value as? String
				}
			} else if (key.starts(with: "network.")) {
				d.wrappedManagedObject.network!.properties[key.lastToken(".")] = value as? String
			} else  {
				
				// assume device level property
				
				key = key.lastToken(".")
				
				if (p.type == .string || p.type == .password || p.type == .ip) {
					d.wrappedManagedObject.properties[key] = C8yStringCustomAsset(value is String ? value as! String : "\(value!)")
				} else if (p.type == .bool) {
					d.wrappedManagedObject.properties[key] = C8yBoolCustomAsset(value! is String ? Bool(value as! String)! : value as? Bool ?? false)
				} else if (p.type == .number) {
					d.wrappedManagedObject.properties[key] = C8yDoubleCustomAsset(value! is String ? Double(value as! String)! : value as? Double ?? 0)
				}
			}
			
			if (self._other != nil) {
				
				if (d.wrappedManagedObject.network == nil) {
					d.wrappedManagedObject.network = C8yNetwork()
				}
				
				if (d.wrappedManagedObject.network!.lan == nil && self._other!.lan != nil) {
					d.wrappedManagedObject.network!.lan = self._other!.lan
				}
				
				if (d.wrappedManagedObject.network!.wan == nil && self._other!.wan != nil) {
					d.wrappedManagedObject.network!.wan = self._other!.wan
				}
			}
			
			return d
		}
		
		func clear() {
			
			self._ignore = true
			self.networkType = nil
			self._other = nil
			self.type = C8Y_NETWORK_NONE
			self.provider = ""
			self.instance = ""
			self.properties = [:]
			self._ignore = false
		}
		
		func set(_ editableDevice: C8yEditableDevice, device: C8yDevice? = nil, networkTypes: C8yNetworkAgentManager? = nil) {
		
			self._ignore = true
			
			self._editableDevice = editableDevice
			self.networkTypesManager = networkTypes
			
			if (device == nil || networkTypes == nil) {
				return
			}
			
			if (device!.network.type != C8Y_NETWORK_NONE && networkTypes != nil) {
			
				self.networkType = networkTypes!.networkTypes[device!.network.type]
				
				self.type = self.networkType?.type ?? C8Y_NETWORK_NONE
				
				if (device!.network.provider != nil) {
					self.provider = device!.network.provider ?? ""
				}
				
				if (device!.network.instance != nil) {
					self.instance = device!.network.instance ?? ""
				}
				
				if (self.networkType!.deviceType != nil) {
					self._editableDevice!.type = self.networkType!.deviceType!
				}
				
				self._other = device!.network
				
				self.updateRequiredNetworkProperties(device!)
			} else {
				self.networkType = nil
			}
			
			self._ignore = false
		}
	
		
		private func updateRequiredNetworkProperties(_ device: C8yDevice) {
						
			if (self.networkType != nil) {
				self.networkType?.properties.forEach( { k, property in
					
					if (property.label != nil) {
						self.properties[k] = EditableProperty(self._editableDevice, property: property, value: property.lookupValue(source: device.wrappedManagedObject))
					}
				})
			}
		}
		
		public class EditableProperty: ObservableObject {
			
			private var _editableDevice: C8yEditableDevice?
			private var _value: String
			
			public var value: Binding<String> {
				return self.valueBinder()
			}
			
			public var info: C8yProperty
			
			init(_ editableDevice: C8yEditableDevice?, property: C8yProperty, value: String? = nil) {
				self._editableDevice = editableDevice
				self.info = property
				self._value = value ?? ""
			}
			
			private func valueBinder() -> Binding<String> {
				
				return .init(
					get: {
						return self._value
					}, set: {
						self._value = $0
						if (self._editableDevice != nil) {
							self._editableDevice!.emitDidChange(self._value)
						}
					}
				  )
			}
		}
	}
	
	public class Hardware: ObservableObject {
		   
		private var _editableDevice: C8yEditableDevice?
		private var _ref: C8yDeviceModels?
		
		private var _ignore: Bool = false
		
		@Published public var supplier: String = "" {
			didSet {
				
				if (_ignore) {
					return
				}
				
				if (oldValue != supplier && _editableDevice != nil) {
					model = ""
					_editableDevice!.category = .Unknown
					
					self._editableDevice?.emitDidChange(self.supplier)
				}
			}
		}
		
		@Published public var model: String = "" {
			didSet {
				
				if (_ignore) {
					return
				}
				
				if (!self.model.isEmpty) {
					self._setModelInfo(forId: self.model, andSupplierId: self.supplier)
				}
			}
		}
		
		init() {
			
		}
		
		func set(_ editableDevice: C8yEditableDevice, device: C8yDevice? = nil, supplier: String? = nil, model: String? = nil) {
			
			self._editableDevice = editableDevice
	
			var s = supplier ?? ""
			var m = model ?? ""
			
			if (device != nil) {
				s = device!.supplier
				m = device!.model
			}
			
			self._ignore = true
			self.supplier = s
			self.model = m
			self._ignore = false
		}
		
		func models(_ modelsRef: C8yDeviceModels) -> [String:String] {
		   
			_ref = modelsRef // keep copy for reference below
			
			if (!self.supplier.isEmpty) {

				let modelsForSupplier = modelsRef.supplierForId(id: self.supplier)?.models
				
				if (modelsForSupplier != nil) {
					return modelsForSupplier!
				} else if self.model.count > 0 {
					return [self.model:self.model]
				} else {
					return [:]
				}
			} else {
				return [:]
			}
		}
		
		private func _setModelInfo(forId id: String, andSupplierId supplierId: String) {
			
			if (_ref == nil) {
				return
			}
			
			self._ref!.modelFor(id: id, andSupplier: supplierId.isEmpty ? "generic" : supplierId)
				.receive(on: RunLoop.main)
				.subscribe(Subscribers.Sink(receiveCompletion: { completion in
					
				}, receiveValue: { result in
										
					if (self._editableDevice != nil) {
						if (result.category != .Unknown) {
							self._editableDevice!.category = result.category
						}
						
						if ( result.link != nil) {
							self._editableDevice!.webLink = result.link!
						}
						
						if (result.agent != nil) {
							self._editableDevice?.network.type = result.agent!
						}
					}
					
					self._editableDevice?.emitDidChange(self.model)
				}))
		}
	}
}
