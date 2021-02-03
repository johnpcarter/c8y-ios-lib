//
//  Device.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

let C8Y_MANAGED_OBJECTS_ATTACHMENTS = "xAttachmentIds"
let JC_MANAGED_OBJECT_WEBLINK = "xWebLink"
let C8Y_UNDEFINED_SUPPLIER = "generic"
let C8Y_UNDEFINED_MODEL = ""

/**
Encapsulates a c8y `C8yManagedObject` managed object and treats it as a device exposing attributes and methods typically attributed to a device
such as `serialNumber`, `model`

Also includes a number of custom atributes to better categorise devices such as `deviceCategory`, `attachments`  and  `relayState`
*/
public struct C8yDevice: C8yObject {
        
	/**
	Used to categorise the device typex
	*/
	public enum Category: String, CaseIterable, Hashable, Identifiable, Encodable {
		case Unknown
		case Gauge
		case Switch
		case Temperature
		case Motion
		case Accelerator
		case Light
		case Humidity
		case Moisture
		case Distance
		case Current
		case ElectricMeter
		case GasMeter
		case Thermostat
		case Motor
		case Camera
		case Alarm
		case Lock
		case Network
		case Router
		case Phone
		case Computer
		case Group
		case Transport
		case Cart
		
		public var id: Category {self}
	}
	
	private let _id = UUID().uuidString
	
	/**
	client side id, required by SwiftUI for display purposes and to determine if object has been refreshed from c8y
	*/
	public var id: String {
		if self.c8yId != nil {
			return self.c8yId!
		} else {
			return self._id
		}
	}

	public static func == (lhs: Self, rhs: Self) -> Bool {
		
		return lhs.id == rhs.id
	}
	
	/*public static func == (lhs: C8yDevice, rhs: C8yDevice) -> Bool {
		lhs.c8yId == rhs.c8yId
	}*/
	
	/**
	Dictionary of all related external id's.
	Not populated by default, unless you use the class `C8yAssetCollection` to manage your groups and devices
	*/
    public var externalIds: [String:C8yExternalId] = [String:C8yExternalId]()
    
	/**
	Implemented in accordance to protocol `C8yObject`, always returns .device
	*/
	public var groupCategory: C8yGroup.Category {
         return .device
    }
     
	/**
	Implemented in accordance to protocol `C8yObject`, always returns .na as it is a device
	*/
    public var orgCategory: C8yOrganisationCategory {
        get {
         return .na
        }
     }
    
	/**
	Returns the category to which the device belongs.
	Represented by a custom attribute 'xC8yDeviceCategory' in the wrapped managed object
	*/
	public var deviceCategory: Category {
         get {
            if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] != nil) {
                return Category(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] as! C8yStringCustomAsset).value) ?? .Unknown
            } else if self.wrappedManagedObject.sensorType.count > 0 {
                return Category(rawValue: self.wrappedManagedObject.sensorType[0].rawValue.subString(from: 3))!
            } else {
                return .Unknown
            }
         }
        set(v) {
            if (self.wrappedManagedObject.sensorType.count == 0 || (C8yManagedObject.SensorType(rawValue: "c8y_\(v)") != nil && !self.wrappedManagedObject.sensorType.contains(C8yManagedObject.SensorType(rawValue: "c8y_\(v)")!))) {
                wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] = C8yStringCustomAsset(v.rawValue)
            }
        }
	}
    
	public var alarmsCount: Int {
	
		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g.alarmsCount
			} else {
				let d: C8yDevice = o.wrappedValue()
				count += d.alarmsCount
			}
		}
		
		// local stuff
		
		count += (self.alarms?.critical ?? 0) + (self.alarms?.major ?? 0) + (self.alarms?.minor ?? 0)
		
		return count
	}
	
	/**
	Convenience attribute to determin if the device is operating correctly or not.
		
	nominal - available and no alarms present
	operating - available with warning alarms
	failing - avaiable with major alarms
	error -  unavailable or available with critical alarms
	offline - unavailable, no alarms present
	maintenance - either unavailable or unavailable and all alarms ignored
	*/
     public var operationalLevel: C8yOperationLevel {
        get {
			if ((self.wrappedManagedObject.requiredAvailability?.responseInterval == -1 || self.wrappedManagedObject.availability?.status == .MAINTENANCE) || self.wrappedManagedObject.activeAlarmsStatus == nil || self.wrappedManagedObject.activeAlarmsStatus?.total == 0) {
                if (self.wrappedManagedObject.availability?.status == .AVAILABLE) {
                    return .nominal
                } else if (self.wrappedManagedObject.availability?.status == .UNAVAILABLE) {
                    return .offline
				} else if (self.wrappedManagedObject.availability?.status == .MAINTENANCE || self.wrappedManagedObject.requiredAvailability?.responseInterval == -1) {
                    return .maintenance
				} else if (!self.isDeployed) {
					return .undeployed
				} else {
					return .unknown
				}
			} else {
			
				if (self.wrappedManagedObject.activeAlarmsStatus?.critical ?? 0 > 0 || self.wrappedManagedObject.availability?.status == .UNAVAILABLE) {
					return .error
				}
				else if (self.wrappedManagedObject.activeAlarmsStatus?.major ?? 0 > 0) {
					return .failing
				} else if (self.wrappedManagedObject.activeAlarmsStatus?.minor ?? 0 > 0) {
					return .operating
				} else if (self.wrappedManagedObject.activeAlarmsStatus?.warning ?? 0 > 0) {
					return .operating
				} else if (!self.isDeployed) {
					return .undeployed
				} else {
					return .unknown
				}
			}
        }
    }
    
	/**
	Returns true if the associated device is a switch/relay type device
	*/
	public var isRelay: Bool {
	
		return self.wrappedManagedObject.relayState != nil
	}
	
	/**
	Reflects current state of relay either open, closed or pending
	*/
	public var relayState: C8yManagedObject.RelayStateType? {
		get {
			return self.wrappedManagedObject.relayState
		}
		set(r) {
			self.wrappedManagedObject.relayState = r
		}
	}
	
	/**
	Returns the Cumulocity derived status of the device.
	Cumulocity determines the availability of the device based on the last time it received any data from the device.
	Cumulocity flags the device as UNAVAILABLE If nothing has been received within the devices `requiredResponseInterval` time period.
	Unless If the `requiredResponseInterval` is set to -1, in which case it returns the status of MAINTENANCE.
	
	Refer to `C8yMutableDevice` if you want to change the `requriedResponseInterval` or POST a managed object to c8y using the
	constructor `C8yManagedObject.init(_:requiredAvailability:)` and service `C8yManagedObjectService.post(_:)`
	*/
    public var status: C8yManagedObject.AvailabilityStatus {
        get {
			if (self.wrappedManagedObject.requiredAvailability?.responseInterval == -1) {
				return .MAINTENANCE
			} else if (self.wrappedManagedObject.network?.connectionError ?? false) {
				return .UNAVAILABLE
			} else {
				return self.wrappedManagedObject.availability?.status ?? .UNKNOWN
			}
		}
    }
    
	/**
	Returns the device's serial number if available
	*/
    public internal(set) var serialNumber: String? {
        get {
            return self.externalIds[C8Y_SERIAL_ID]?.externalId
            
        }
        set(v) {
            
            var ext = self.externalIds[C8Y_SERIAL_ID]
            
            if (ext == nil && v != nil) {
                self.externalIds[C8Y_SERIAL_ID] = C8yExternalId(withExternalId: v!, ofType: C8Y_SERIAL_ID)
            } else if (v != nil) {
                ext!.externalId = v!
            }
        }
    }
    
	/**
	String value describing the supplier of the device or 'generic' if not defined
	*/
    public internal(set) var supplier: String {
        get {
			if (self.wrappedManagedObject.hardware == nil || self.wrappedManagedObject.hardware!.supplier == nil) {
				return C8Y_UNDEFINED_SUPPLIER
			} else {
				return self.wrappedManagedObject.hardware!.supplier!
			}
        }
        set(s) {
            
            if (self.wrappedManagedObject.hardware == nil) {
               self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware?.supplier = s
        }
    }
    
	/**
	String value describing the model of the device or an empty string  if not defined
	*/
	public internal(set) var model: String {
        get {
			if (self.wrappedManagedObject.hardware == nil || self.wrappedManagedObject.hardware!.model == nil) {
				return C8Y_UNDEFINED_MODEL
			} else {
				return self.wrappedManagedObject.hardware!.model!
			}
        }
        set(m) {
            
            if (self.wrappedManagedObject.hardware == nil) {
                self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware!.model = m
        }
    }
    
	/**
	String value describing the revision of the device or nil if not available
	*/
    public internal(set) var revision: String? {
        get {
            return self.wrappedManagedObject.hardware?.revision
        }
        set(r) {
            
           if (self.wrappedManagedObject.hardware == nil) {
                self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware?.revision = r
        }
    }
    
	/**
	String value describing the device's firmware version  or nil if not available
	*/
    public var firmware: String? {
        get {
            return self.wrappedManagedObject.firmware?.version
        }
    }
    
	/**
	String list of operation types that are supported by this device.
	e.g. c8y_Restart etc.
	*/
    public var supportedOperations: [String] {
        get {
            if (self.wrappedManagedObject.supportedOperations != nil) {
                return self.wrappedManagedObject.supportedOperations!
            } else {
                return []
            }
        }
    }
    
	/**
	Network settings describing what network the device uses to communicate.
	*/
    public var network: C8yNetwork {
        get {
            return self.wrappedManagedObject.network ?? C8yNetwork()
        }
        set {
            self.wrappedManagedObject.network = newValue
        }
    }
    
	/**
	Determine if the device has been been successfully deployed.
	This is not the same as `network.provisioned`, which may return false even if this property returns true.
	
	This property will return true either if no specific networking requirements are set (Device Credentials), i.e. assuming device agent is remote
	and will push data to c8y without specific setup on c8y side, or if an agent is being used then it has been provisioned successfully.
	i.e. `network.provisioned` is true.
	
	Refer to the class `C8yNetwork` for more information
	*/
	public internal(set) var isDeployed: Bool {
		get {
			if (self.network.type == C8Y_NETWORK_NONE) {
				return true
			} else {
				return self.network.provisioned
			}
		}
		set(v) {
			
			self.network.provisioned = true
		}
	}
	
	/**
	Arbritary text associated with the device or nil if note available.
	*/
    public var notes: String? {
        get {
            return self.wrappedManagedObject.notes
        }
        set(notes) {
            self.wrappedManagedObject.notes = notes
        }
    }
    
	/**
	Date/time that the Managed Object represeting this device was last updated in Cumulocity
	*/
    public var lastUpdated: Date? {
        get {
            return self.wrappedManagedObject.lastUpdated
        }
    }
    
	/**
	Date/time that Cumulocity last received some kind of activity from the device.
	This is used to determine the devices `status` in conjunction with `requiredResponseInterval`
	*/
    public var lastMessage: Date? {
        get {
            return self.wrappedManagedObject.availability?.lastMessage
        }
    }
    
	/**
	Value in seconds used to determine device availability, i.e. the device is considered unavailable  if no activity is received from the device within
	the time period given here. The device is considered to be in maintenance mode if this is set to -1. Incidentally all alarms triggers are
	ignored if this value indicates maintenance mode.
	
	Refer to `C8yMutableDevice` if you want to change the `requriedResponseInterval` or POST a managed object to c8y using the
	constructor `C8yManagedObject.init(_:requiredAvailability:)` and service `C8yManagedObjectService.post(_:)`
	*/
    public var requiredResponseInterval: Int? {
        get {
            return self.wrappedManagedObject.requiredAvailability?.responseInterval
        }
    }
    
	/**
	Custom attribute to allow a web url to be associated with the device.
	Useful if you want to provide a link to external technical documentation etc. The attribute is stored in the c8y managed object as 'xWebLink'
	*/
    public var webLink: String? {
        get {
            return (self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_WEBLINK] as? C8yStringCustomAsset)?.value
        }
        set(lnk) {
            
            if (lnk != nil) {
                self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_WEBLINK] = C8yStringCustomAsset(lnk!)
            }
        }
    }
    
	/**
	This attribute only applies to devices that connect to Cumulocity using push notifications rather than the more typical polling mechanism
	whereby Cumulocity through an agent queries the device.
	
	If applicable returns true if the device is currently connected and sending data, false indicates the device has disconnected.
	*/
    public var connected: Bool {
        get {
            if (self.wrappedManagedObject.status != nil) {
                return self.wrappedManagedObject.connectionStatus!.status == .CONNECTED
            } else {
                return false
            }
        }
    }
    
	/**
	Alarm summary for device.
	*/
    public internal(set) var alarms: C8yManagedObject.ActiveAlarmsStatus? {
        get {
            return self.wrappedManagedObject.activeAlarmsStatus
        }
		set(v) {
			self.wrappedManagedObject.activeAlarmsStatus = v
		}
    }
    
	/**
	Defines the type of measurements that can be collected for this device and gives an indication to how they should be displayed
	*/
    public var dataPoints: C8yDataPoints? {
        get {
            return self.wrappedManagedObject.dataPoints
        }
    }
    
	public internal(set) var hasChanges: Bool = false
	
	/**
	Represents the wrapped Managed Object that defines this device
	*/
	public var wrappedManagedObject: C8yManagedObject {
		didSet {
			self.hasChanges = true
		}
	}
	
	/**
	String representing the hierachy in which device belongs, i.e. list the parent group in which device is nested.
	This is only provided if you used `C8yAssetCollection` to fetch the device
	*/
    public internal(set) var hierachy: String?
	
	/**
	List of attachment references associated with this device. The attachments themselves can be
	fetched via the `C8yBinariesService` using the references here.
	
	The attachments are stored in the managed object in c8y using the attribute 'xAttachmentIds'
	*/
    public internal(set) var attachments: [String] = []
	
	/**
	Indicates if this device is managed via a parent device, router etc,
	that is responsible for managing it's connectivity.
	*/
	public internal(set) var isChildDevice: Bool = false
	
	/**
	List of child devices associated with this device, only applicable for router or gateway type devices.
	*/
	public var children: [AnyC8yObject] = []
    
	/**
	Default constructor for an empty device
	*/
    internal init() {
        self.wrappedManagedObject = C8yManagedObject()
        self.wrappedManagedObject.isDevice = true
    }
	
	/**
	Creates a new empty device with the given external id and type
	
	- parameter externalId: string representing external id
	- parameter type: description of external id type e.g. 'c8y_Serial'
	*/
    public init(externalId: String, type: String) {
        self.init()
        self.externalIds[type] = C8yExternalId(withExternalId: externalId, ofType: type)
    }
    
	/**
	Creates a device based on the underlying managed object
	
	- parameter m: The managed object representing the device
	*/
    public init(_ m: C8yManagedObject) throws {
                
		if (m.id != nil && !m.isDevice) {
			throw DeviceDecodingError.notADeviceObject(object: m)
		}
		
        self.wrappedManagedObject = m
        
        if (wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] != nil) {
            let subs = (wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] as! C8yStringCustomAsset).value.split(separator: ",")
            
            for s in subs {
                self.attachments.append(String(s))
            }
        }
		
		// TODO: improve this, a bit hacky as it assumes the agent will set this
		// need to find another way to know if it is a child device, unfortunately parentAsset references are nil even if it is a child device
		
		if (wrappedManagedObject.network?.type == "childDevice") {
			self.isChildDevice = true
		}
    }
    
	internal init(_ c8yId: String?, serialNumber: String?, withName name: String, type: String, supplier: String?, model: String?, notes: String?, requiredResponseInterval: Int, revision: String, category: Category?) {
	
		self.wrappedManagedObject = C8yManagedObject(deviceWithSerialNumber: serialNumber, name: name, type: type, supplier: supplier, model: model!, notes: notes, revision: revision, requiredResponseInterval: requiredResponseInterval)
				
		if (c8yId != nil) {
			self.wrappedManagedObject.updateId(c8yId!)
		}
		
		if (category != nil) {
			self.deviceCategory = category!
		}
	}
	
	internal init(_ c8yId: String) {
	
		self.wrappedManagedObject = C8yManagedObject(c8yId)
		self.wrappedManagedObject.isDevice = true
	}
	
    internal init(_ m: C8yManagedObject, hierachy: String) throws {
                
        try self.init(m)
        self.wrappedManagedObject.isDevice = true

        self.hierachy = hierachy
    }
    
	/**
	Returns true if the given device is the same copy as this i.e. internal id assigned by this app when loading is the same.
	Returns false if the given device is a different device or represents the same device but a different instance i.e. reloaded or updated.
	*/
	public func isSameCopy(_ d: C8yDevice) -> Bool {
			
		return d._id == self._id
	}
	
	/**
	Convenience method to determine if the given device matches all of the same attributes as this device
	*/
	public func isDifferent(_ device: C8yDevice) -> Bool {
	
		return  self.operationalLevel != device.operationalLevel
				|| self.attachments.count != device.attachments.count
				|| self.isDeployed != device.isDeployed
				|| self.firmware != device.firmware
				|| self.lastMessage != device.lastMessage
				|| self.lastUpdated != device.lastUpdated
				|| self.deviceCategory != device.deviceCategory
				|| self.name != device.name
				|| self.isNew != device.isNew
				|| self.webLink != device.webLink
				|| self.model != device.model
				|| self.network != device.network
				|| self.notes != device.notes
				|| self.requiredResponseInterval != device.requiredResponseInterval
				|| self.revision != device.revision
				|| self.position == nil && device.position != nil
				|| (self.position != nil && self.position!.isDifferent(device.position))
	}
	
	/**
	Returns a string representing the default external id and type if provided or if not the c8y internal id.
	
	Format is key='value' e.g.
		c8y_Serial=122434344
		c8y_id=9393
	*/
    public func defaultIdAndType() -> String {
       
       var idString: String
       
       if (self.externalIds.count > 0) {
           idString = "\(externalIds.first!.value.type)=\(externalIds.first!.value.externalId)"
       } else if (self.serialNumber != nil) {
           idString = "\(C8Y_SERIAL_ID)=\(self.serialNumber!)"
       } else {
		idString = "\(C8Y_INTERNAL_ID)=\(self.c8yId ?? "unasigned")"
       }
       
       return idString
    }
	
	/**
	Returns the default external id if provided or if not the c8y internal id.
	*/
	public func defaultId() -> String? {
		
		var idString: String?
		
		if (self.externalIds.count > 0) {
			idString = externalIds.first!.value.externalId
		} else if (self.serialNumber != nil) {
			idString = self.serialNumber!
		} else {
			idString = self.c8yId
		}
		
		return idString
	}
	
	/**
	Returns true if the given external id matches this device
	
	- parameter forExternalId: the value, must match the value for the associated type
	- parameter type: describes external id, must match a type given in `externalIds`
	- returns: true if a match is found, false otherwise
	*/
    public func match(forExternalId id: String, type: String?) -> Bool {
                   
        return (self.externalIds[type ?? C8Y_SERIAL_ID] != nil && self.externalIds[type ?? C8Y_SERIAL_ID]!.externalId == id)
    }
    
	/**
	Returns true if an external id and type can be found in the formatted string, which then matches one of the devices.
	
	String could be formatted as
	
	c8y_Serial=3434343
	or
	3434343 (if no separator given)
	
	- parameter line: formatted text string containing the id and type
	- parameter separator: Optional separator determing how the type and value are provided. If nil assume type is not provided and will attempt to match one of the lines to any external id
	- returns: true if a match was made
	*/
	public func matchRawStringIdentifier(line: String, separator: String.Element?) -> Bool {
				
		if (separator != nil) {
	
			let parts = line.split(separator: separator!)
			let type: String = String(parts[0])
			let ref: String = String(parts[1])
			var id = self.externalIds[type]
				   
			if (id == nil) {
				id = self.externalIds[type.lowercased()]
			}
			
			return id != nil && id?.externalId.lowercased() == ref.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of:":", with:"")
		} else {
			
			for id in self.externalIds.values {
				if (id.externalId == line) {
					return true
				}
			}
			
			return false
		}
	}
	
	/**
	Returns a UIImage representing a QR code of the default id of this device
	
	- returns: UIImage representing a QR code
	*/
    public func generateQRCodeImage() throws -> UIImage {
        
        return try self.generateQRCodeImage(forType: nil)
    }
    
	/**
	Returns a UIImage representing a QR code for the given external id type of this device.
	Resorts to the default id of the device If the external id is not found for the given type.
	
	- returns: UIImage representing a QR code
	*/
    public func generateQRCodeImage(forType type: String?) throws -> UIImage {
    
        var idString: String
        
        if (type == nil) {
            idString = self.defaultIdAndType()
        } else if (type == C8Y_SERIAL_ID && self.serialNumber != nil) {
			idString =  "\(C8Y_SERIAL_ID)=\(self.serialNumber!)"
		} else if (type == C8Y_INTERNAL_ID) {
			idString = "\(C8Y_INTERNAL_ID)=\(self.c8yId ?? "unassigned")"
		} else {
            let ext = self.externalIds[type!]
            
            if (ext == nil) {
                throw C8yNoValidIdError.error
            }
            
            idString = "\(ext!.type)=\(ext!.externalId)"
        }
        
		if (self.supplier != C8Y_UNDEFINED_SUPPLIER && !self.supplier.isEmpty) {
            idString += "\n"
            idString += "supplier=\(self.supplier)"
        }
        
		if (self.model != C8Y_UNDEFINED_MODEL && self.model != "-"  && !self.model.isEmpty) {
            idString += "\n"
            idString += "model=\(self.model)"
        }
        			
		self.network.properties.forEach( { k, v in
			idString += "\n"
			idString += "\(k)=\(v)"
		})
               
        let data = Data(idString.utf8)
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
	
	/**
	Thrown from init if wrapped Managed Object is not a device asset
	*/
	public enum DeviceDecodingError: Error {
		case notADeviceObject(object: C8yManagedObject)
		case outOfStock
	}
}
