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
    
    @Published public var supplier: String = "generic" {
        didSet {
            self.emitDidChange(self.supplier)
        }
    }
    
    //@Published
	private var _prevModel: String = ""
    @Published public var model: String = "" {
		willSet {
			self._prevModel = self.model
		}
        didSet {
			
			if (self._prevModel != self.model) {
				self.emitDidChange(self.model)
			}
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

    // extras
    
    @Published public var networkType: C8yNetworkType = .none {
        didSet {
            self.emitDidChange(self.networkType.rawValue)
        }
    }
    
    @Published public var networkProvider: String = "" {
        didSet {
            self.emitDidChange(self.networkProvider)
        }
    }
    
    @Published public var networkInstance: String = "" {
        didSet {
            self.emitDidChange(self.networkInstance)
        }
    }
    
    @Published public var networkAppKey: String = "" {
        didSet {
            self.emitDidChange(self.networkAppKey)
        }
    }

    @Published public var networkAppEUI: String = "" {
        didSet {
            self.emitDidChange(self.networkAppEUI)
        }
    }
    
    @Published public var category: C8yDevice.DeviceCategory = .Unknown {
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
		if (self._networkTypeOriginal != self.networkType.rawValue || self._networkProviderOriginal != self.networkProvider || self._networkInstanceOriginal != self.networkInstance) {
			return self.networkType == .none ? true : false
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

	private var _deviceWrapper: C8yMutableDevice? = nil
	
	/**
	Default constructor to manage a new blank editable device
	*/
    public init() {
    }
    
	/**
	Constructor to allow an existing device to be edited.
	*/
	public convenience init(deviceWrapper: C8yMutableDevice) {
		self.init(deviceWrapper.device)
		self._deviceWrapper = deviceWrapper
	}
	
	/**
	Constructor to allow an existing device to be edited.
	*/
    public convenience init(_ device: C8yDevice) {
        
        self.init()
        
        self.mergeDevices(device)
        
		self._externalIds = device.externalIds
		self._isDeployed = device.isDeployed
		self._networkTypeOriginal = device.network.type ?? ""
		self._networkProviderOriginal = device.network.provider ?? ""
		self._networkInstanceOriginal = device.network.instance ?? ""
		
        if (device.externalIds.count > 0) {
            self.externalId = device.externalIds.values.first!.externalId
            self.externalIdType = device.externalIds.values.first!.type
        } else {
            self.externalId = "-undefined-"
        }
    }
    
	/**
	Constructor for new device with the given attributes
	
	*/
    public init(_ id: String, name: String, supplierName: String?, modelName: String, category: C8yDevice.DeviceCategory, operations: [String], revision: String?, firmware: String?,  requiredResponseInterval: Int) {
        
        self.externalId = id
        self.externalIdType = "UUID"
        self.name = name
        
        if (supplierName != nil) {
            self.supplier = supplierName!
        }
        
        self.model = modelName
        self.category = category
        self.requiredResponseInterval = requiredResponseInterval
        
        if (revision != nil) {
            self.revision = revision!
        }
        
        if (firmware != nil) {
            self.firmware = firmware!
        }
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
        self.supplier = ""
        self.model = ""
        self.revision = ""
        self.firmware = ""
        self.networkType = .none
        self.networkAppEUI = ""
        self.networkAppKey = ""
        self.networkInstance = ""
        self.networkProvider = ""
        
        self._ignoreChanges = false
    }
    
	/**
	Returns true if the minimum number of fields for a device in Cumulocity have been assigned
	- parameter willDeploy: if set to true network parameters must be fully specified; if false networking fields are ignored
	- returns: true if minimum fields are set,
	*/
	public func isValid(_ willDeploy: Bool) -> Bool {
		return (!self.name.isEmpty || !self.model.isEmpty) && !self.externalId.isEmpty && !self.externalIdType.isEmpty && (self.networkType == .none || !willDeploy || (!self.networkInstance.isEmpty && !self.networkAppEUI.isEmpty && !self.networkAppKey.isEmpty))
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
        
        var device: C8yDevice = C8yDevice(self.c8yId, serialNumber: self.externalIdType == C8Y_SERIAL_ID && self.externalId != "-undefined-" ? self.externalId : nil, withName: self.name, type: self.category.rawValue, supplier: self.supplier != "generic" ? self.supplier : nil, model: self.model, notes: self.notes, requiredResponseInterval: self.requiredResponseInterval, revision: self.revision, category: self.category)
                
        if (self._lastPosition != nil) {
            device.position = self._lastPosition
        }
        
        device.webLink = self.webLink
        
        if (self.type != "") {
            device.wrappedManagedObject.type = self.type
        } else {
            device.wrappedManagedObject.type = "c8yDevice"
        }
        
        if (self.networkType != .none) {
            
			device.network = C8yAssignedNetwork(isProvisioned: self.isDeployed)
            
            device.network.type = self.networkType.rawValue
            device.network.provider = self.networkProvider
            device.network.instance = self.networkInstance
            device.network.appKey = self.networkAppKey
            device.network.appEUI = self.networkAppEUI
            
            if (self.networkType == .lora) {
                device.wrappedManagedObject.type = "c8y_LoRaDevice"
            } else if (self.networkType == .sigfox) {
                device.wrappedManagedObject.type = "c8y_SigfoxDevice"
            }
                  
        } else {
            
            device.network.type = C8yNetworkType.none.rawValue
            device.network.provider = nil
            device.network.instance = nil
        }
        
		device.externalIds = self._externalIds
		
        if (self.externalId != "-undefined-") {
            device.externalIds[self.externalIdType] = C8yExternalId(withExternalId: self.externalId, ofType: self.externalIdType)
        }
        
        if (position != nil) {
            device.wrappedManagedObject.updatePosition(latitude: position!.lat, longitude: position!.lng, altitude:  position?.alt)
		}
        
        return device
    }
    
	public func mergeDevices(_ c8yDevice: C8yDevice, group: C8yGroup? = nil) {
    
        self._ignoreChanges = true
        
        if (c8yDevice.c8yId != nil) {
            self.c8yId = c8yDevice.c8yId ?? ""
        }
    
        if (c8yDevice.name != c8yDevice.model && c8yDevice.name != c8yDevice.type) {
            self.name = c8yDevice.name
        }

        if (c8yDevice.supplier != C8Y_UNDEFINED_SUPPLIER) {
            self.supplier = c8yDevice.supplier
        }
        
        if (c8yDevice.model != C8Y_UNDEFINED_MODEL) {
            self.model = c8yDevice.model
        }
        
        if (c8yDevice.revision != nil) {
            self.revision = c8yDevice.revision!
        }
        
        if (c8yDevice.firmware != nil) {
            self.firmware = c8yDevice.firmware!
        }
        
        
        if (c8yDevice.position != nil) {
            self._lastPosition = c8yDevice.position
		} else if (group != nil && group!.info.address != nil) {
			self.addressLine = group!.info.address!.addressLine1 ?? ""
			self.city = group!.info.address!.city ?? ""
			self.postCode = group!.info.address!.postCode ?? ""
			self.country = group!.info.address!.country ?? ""			
		}
        
        if (c8yDevice.notes != nil) {
            self.notes = c8yDevice.notes!
        }
        
        if (c8yDevice.requiredResponseInterval != nil) {
            self.requiredResponseInterval = c8yDevice.requiredResponseInterval!
        }
        
        if (c8yDevice.externalIds.count > 0) {
            self.externalIdType = c8yDevice.externalIds.keys.first!
            self.externalId = c8yDevice.externalIds[self.externalIdType]!.externalId
		} else if (c8yDevice.serialNumber != nil) {
			self.externalId = c8yDevice.serialNumber!
			self.externalIdType = C8Y_SERIAL_ID
		}
        
        // extras
        
		if (c8yDevice.network.type != .none) {
        
            if (c8yDevice.network.type != nil) {
				self.networkType = C8yNetworkType(rawValue: c8yDevice.network.type!) ?? .none
            }
            
            if (c8yDevice.network.provider != nil) {
                self.networkProvider = c8yDevice.network.provider!
            }
            
            if (c8yDevice.network.instance != nil) {
                self.networkInstance = c8yDevice.network.instance!
            }
            
            if (c8yDevice.network.appKey != nil) {
                self.networkAppKey = c8yDevice.network.appKey!
            }
            
            if (c8yDevice.network.appEUI != nil) {
                self.networkAppEUI = c8yDevice.network.appEUI!
            }
        }
        
        self.type = c8yDevice.type != nil ? c8yDevice.type! : ""
        self.category = c8yDevice.deviceCategory
        
        if (c8yDevice.supplier != C8Y_UNDEFINED_SUPPLIER) {
            self.supplier = c8yDevice.supplier
        }
        
        if (c8yDevice.webLink != nil) {
            self.webLink = c8yDevice.webLink!
        }
        
        self._ignoreChanges = false
    }
    
    private func emitDidChange(_ v: String) {
        if (!self._ignoreChanges) {
            self.haveChanges = true
			if (self._deviceWrapper != nil) {
				self._deviceWrapper!.device = self.toDevice()
			}
            self.didChange.send(v)
        }
    }
}
