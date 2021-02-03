//
//  Object.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 26/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

import UIKit
import CoreImage.CIFilterBuiltins

let C8Y_MANAGED_OBJECTS_XORG_CATEGORY = "xOrgCategory"
let C8Y_MANAGED_OBJECTS_XORG_NAME = "xGroupDescription"
let C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY = "xGroupCategory"
let C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY = "xC8yDeviceCategory"

/**
Wrapper to allow objects deviced from `C8yObject` to managed as a collection.
Swift does not allow Arrays or Dictionaries to reference protocol types, hence why this is needed.

This class is used by `C8yAssetCollection` to allow both `C8yDevice` and `C8yGroup`
objects to managed together.
*/
public struct AnyC8yObject: Identifiable, Equatable, Hashable {

	/**
	Local id reference for wrapped object
	*/
    public let id: String
	
	/**
	Cumulocity internal id from wrapped object
	*/
    public let c8yId: String?
    
	/**
	Specifies the object type of the wrapped content, either `C8yDevice` or `C8yGroup`
	*/
    public let type: WrappedType
    
	public var hasChildren: Bool {
		return self.children.count > 0
	}
	
	/**
	The name attributed to the wrapped object
	*/
    public var name: String {
        get {
			if (self.type == .C8yDevice) {
                let d: C8yDevice = self.wrappedValue()
                
                return d.name
            } else {
                let g: C8yGroup = self.wrappedValue()
                return g.name
            }
        }
    }
    
	/**
	Array of child objects associated with the wrapped object, both `C8yGroup` and `C8yDevice`
	support child elements
	*/
    public var children: [AnyC8yObject] {
        get {
			if (self.type == .C8yDevice) {
                let d: C8yDevice = self.wrappedValue()
                
                return d.children
            } else {
                let g: C8yGroup = self.wrappedValue()
                return g.children
            }
        }
		set(a) {
			if (self.type == .C8yDevice) {
				var d: C8yDevice = self.wrappedValue()
				d.children = a
				
				self._t = d
			} else {
				var g: C8yGroup = self.wrappedValue()
				g.children = a
				
				self._t = g
			}
		}
    }
    
    private var _t: Any?
    
	/**
	Constructor for a wrapper containing the given object
	- parameter obj Implementation of protocol  `C8yObject`, only `C8yDevice` and `C8yGroup` exist today
	*/
    public init<T:C8yObject>(_ obj: T) {
        self.c8yId = obj.c8yId
        self.id = obj.id
				
		self.type = WrappedType(rawValue: "\(T.self)")!
        self._t = obj
    }
    
	/**
	The wrapped object
	*/
    public func wrappedValue<T:C8yObject>() -> T {
        
        return self._t as! T
    }
    
    public static func == (lhs: AnyC8yObject, rhs: AnyC8yObject) -> Bool {
        return lhs.c8yId == rhs.c8yId
    }
    
    public func hash(into hasher: inout Hasher) {
           
        hasher.combine(self.id.hashValue)
    }
	
	func objectFor(_ c8yId: String) -> (path: [String], object: AnyC8yObject?) {
	
		var found: AnyC8yObject? = nil
		var path: [String] = []
		
		if (self.c8yId != nil) {
			path.append(self.c8yId!)
		}
		
		for c in self.children {
			if (c.c8yId == c8yId) {
				found = c
				break
			}
		}
		
		if (found == nil) {
			for c in self.children {
				
				if (c.c8yId == c8yId) {
					// found it
				} else if (c.hasChildren) {
				
					let wrapper = c.objectFor(c8yId)
					if (wrapper.object != nil) {
						found = wrapper.object
						path.append(contentsOf: wrapper.path)
						break
					}
				}
			}
		}
		
		return (path, found)
	}
	
	func deviceFor(externalId: String, externalIdType type: String) -> C8yDevice? {
		
		var found: C8yDevice? = nil
		
		for o in self.children {
			
			if (o.type == .C8yDevice) {
				let device: C8yDevice = o.wrappedValue()
				
				if (device.match(forExternalId: externalId, type: type)) {
					found = device
					break
				}
			}
			
			// check children if not matched
			
			found = o.deviceFor(externalId: externalId, externalIdType: type)
			
			if (found != nil) {
				break
			}
		}
		
		return found
	}
	
	/**
	Removes the specified asset from the group or sub group of one of its children
	
	- parameter c8yId: id of the asset to be removed
	- returns: true if the asset was found and removed
	*/
	public mutating func removeChild(_ c8yId: String) -> Bool {
		
		// use replace with a dummy object, replace function will remove

		return self.replaceOrRemove(c8yId, object: C8yGroup(""))
	}
	
	/**
	Replaces the current asset in the group or sub group of one of its children
	- parameter object: The object to be replaced
	- returns: true if the asset was found and replaced, false if not
	*/
	public mutating func replaceChild<T:C8yObject>(_ object: T) -> Bool {
		
		return self.replaceOrRemove(object.c8yId!, object: object)
	}
	
	private mutating func replaceOrRemove<T:C8yObject>(_ c8yId: String, object: T? = nil) -> Bool {
		
		var matched: Bool = false
		
		if (self.hasChildren) {
			
			var i: Int = 0
			
			for c in self.children {
								
				if (c.c8yId == c8yId) {
					// if replacement object is a dummy, then assume we are removing not replacing!!
					
					if (object == nil || object!.c8yId!.isEmpty) {
						self.children.remove(at: i)
					} else {
						self.children[i] = AnyC8yObject(object!)
					}
					
					matched = true
				} else {
					// check subgroups
								
					var copy = c
					if (copy.replaceOrRemove(c8yId, object: object)) {
						self.children[i] = copy
					
						matched = true
					}
				}
			
				i += 1
			}
		}
		
		return matched
	}
	
	/**
	Enumerator type for possoble content types
	*/
	public enum WrappedType: String {
		case C8yDevice
		case C8yGroup
	}
}

/**
Protocol identifying common features for all cumulocity assets managed via a `C8yManagedObject`


Currently only `CyGroup` and `C8yDevice` have been defined
*/
public protocol C8yObject: Equatable {
    
	/**
	iOS id attributed for loca use/indexing
	*/
    var id: String { get }
	
	/**
	Cumulocity assigned id for existing objects or nil if it doesn't yet exist
	*/
    var c8yId: String? { get }
    var name: String { get }
    
    var groupCategory: C8yGroup.Category { get }
    var orgCategory: C8yOrganisationCategory { get }
    var deviceCategory: C8yDevice.Category { get }

    var operationalLevel: C8yOperationLevel { get }
    var status: C8yManagedObject.AvailabilityStatus { get }

	var hierachy: String? { get }

    var hasChildren: Bool { get }
    
    var deviceCount: Int { get }
    
    /**
     Only applicable if hasChildren > 0
     */
    var onlineCount: Int { get }
    
    /**
     Only applicable if hasChildren > 0
     */
    var offlineCount: Int { get }
    
    var alarmsCount: Int { get }
    
    var wrappedManagedObject: C8yManagedObject { get set }
    
    var children: [AnyC8yObject] { get set }
    
    var externalIds: [String:C8yExternalId] { get set }
    
	var notes: String? { get set }
	
    func defaultIdAndType() -> String

    func match(forExternalId id: String, type: String?) -> Bool
}

public enum C8yNoValidIdError : Error {
    case error
}

extension C8yObject {
        
    public var c8yId: String? {
        get {
            return self.wrappedManagedObject.id
        }
    }
    
    public var name: String {
        get {
            if (self.wrappedManagedObject.name != nil) {
                return self.wrappedManagedObject.name!
            } else if (self.wrappedManagedObject.hardware != nil && self.wrappedManagedObject.hardware!.model != nil) {
                return self.wrappedManagedObject.hardware!.model!
            } else {
                return self.wrappedManagedObject.type
            }
        }
		set(n) {
			self.wrappedManagedObject.name = n
		}
    }

	public var notes: String? {
		get {
			return self.wrappedManagedObject.notes
		}
		set(n) {
			self.wrappedManagedObject.notes = n
		}
	}
    
    public var orgCategory: C8yOrganisationCategory {
        get {
            if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_CATEGORY] != nil) {
                return C8yOrganisationCategory(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_CATEGORY] as! C8yStringCustomAsset).value) ?? .unknown
            } else {
                return .undefined
            }
        }
        
    }
    
    public var deviceCategory: C8yDevice.Category {
        get {
            return .Group
        }
    }
    
    public var operationalLevel: C8yOperationLevel {
        get {
            if (!self.hasChildren) {
                return .undeployed
            } else if (self.alarmsCount == 0) {
                return .nominal
            } else if (self.alarmsCount == self.deviceCount) {
                return .error
            } else {
                return .failing
            }
        }
    }
    
    public var status: C8yManagedObject.AvailabilityStatus {
        get {
            if (!self.hasChildren) {
                return .UNKNOWN
            } else {
                return .AVAILABLE
            }
        }
    }
    
	/**
	Returns number of child devices that are unavailable
	*/
	public var offlineCount: Int {
	
		return self.deviceCount - self.onlineCount
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
		
		return count
	}
	
	public var deviceCount: Int {

		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g.deviceCount
			} else {
				count += 1
			}
		}
			   
		return count
	}
	   
	public var onlineCount: Int {
		
		var count: Int = 0
				
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g.onlineCount
			} else {
				let d: C8yDevice = o.wrappedValue()
				
				if (d.status != .UNAVAILABLE) {
					count += 1
				}
			}
		}
			   
		return count
	}
	
    public mutating func setExternalIds(_ ids: [C8yExternalId]) {
    
        self.externalIds.removeAll()
                       
        for ext in ids {
            self.externalIds[ext.type] = ext
        }
    }
    
    public var isNew: Bool {
		return  self.c8yId == nil || self.c8yId!.isEmpty
    }
    
    public var hasChildren: Bool {
        get {
            return self.children.count > 0
        }
    }
    
    public var type: String? {
       get {
           return self.wrappedManagedObject.type
       }
    }
    
    public var position: C8yManagedObject.Position? {
        get {
            return self.wrappedManagedObject.position
        }
        set(p) {
            self.wrappedManagedObject.position = p
        }
    }
    
    mutating func setC8yId(_ id: String) {
            
        self.wrappedManagedObject.updateId(id)
    }
        
    func indexOfChild(_ c8yId: String) -> Int {
        
        for i in self.children.indices {
            if self.children[i].c8yId == c8yId {
                return i
            }
        }
        
        return -1
    }
    
    public func generateQRCodeImage(forType type: String?) throws -> UIImage {
    
        var idString: String
        
        if (type == nil) {
            idString = self.defaultIdAndType()
        } else {
            let ext = self.externalIds[type!]
            
            if (ext == nil) {
                throw C8yNoValidIdError.error
            }
            
            idString = "\(ext!.type)=\(ext!.externalId)"
        }
        
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
}

struct C8yCounter {

    var total: Int
    
    var onlineCount: Int
    
    var offlineCount: Int
    
    var alarmsCount: Int
        
    init<T:C8yObject>(for object: T) {
        self.total = 1
        self.onlineCount = (object.status == .AVAILABLE ? 1 : 0) + object.onlineCount
        self.offlineCount = (object.status == .UNAVAILABLE || object.status == .UNKNOWN || object.status == .MAINTENANCE ? 1 : 0) + object.offlineCount
       
        self.alarmsCount = object.alarmsCount
    }
}

public enum C8yOrganisationCategory: String, CaseIterable, Hashable, Identifiable {

    case undefined
    case unknown
    case na
    case Industrial
    case School
    case Commercial
    case Office
    case Agriculture
    case Residential
    
    public var id: C8yOrganisationCategory {self}
}

public enum C8yOperationLevel: String {
    case nominal // green
    case operating // ok with minor alarms
    case failing // ok with major alarms
    case error // critical alarms
    case offline  // no status
    case maintenance
	case unknown // value is nil
    case undeployed // never deployed
}

enum C8yDeviceUpdateError: LocalizedError {
    case reason (String?)
}
