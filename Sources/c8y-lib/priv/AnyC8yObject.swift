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
let C8Y_MANAGED_OBJECTS_XORG_NAME = "xOrgName"
let C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY = "xGroupCategory"
let C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY = "xDeviceCategory"

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
public protocol C8yObject: Identifiable, Equatable {
    
	/**
	iOS id attributed for loca use/indexing
	*/
    var id: String { get }
	
	/**
	Cumulocity assigned id for existing objects or nil if it doesn't yet exist
	*/
    var c8yId: String? { get }
    var name: String { get }
    
    var groupCategory: C8yGroupCategory { get }
    var orgCategory: C8yOrganisationCategory { get }
    var deviceCategory: C8yDeviceCategory { get }

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
    
    var children: [AnyC8yObject] { get }
    
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
	
    public var deviceCount: Int {
        get {
            var count: Int = 0
            
            self._counter{ (obj) in
                count += obj.total
            }
            
            return count
        }
    }
    
    public var onlineCount: Int {
        get {
            var count: Int = 0
            
            self._counter{ (obj) in
                count += obj.onlineCount
            }
            
            return count
        }
    }
    
    public var offlineCount: Int {
        get {
            var count: Int = 0
            
            self._counter{ (obj) in
                count += obj.offlineCount
            }
            
            return count
        }
    }
    
    public var alarmsCount: Int
    {
        get {
            var count: Int = 0
            
            self._counter{ (obj) in
                count += obj.alarmsCount
            }
            
            return count
        }
    }
    
    public var orgCategory: C8yOrganisationCategory {
        get {
            if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_CATEGORY] != nil) {
                return C8yOrganisationCategory(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_CATEGORY] as! C8yStringWrapper).value) ?? .unknown
            } else {
                return .undefined
            }
        }
        
    }
    
    public var deviceCategory: C8yDeviceCategory {
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
    
    public mutating func setExternalIds(_ ids: [C8yExternalId]) {
    
        self.externalIds.removeAll()
                       
        for ext in ids {
            self.externalIds[ext.type] = ext
        }
    }
    
    public var isNew: Bool {
		return  self.c8yId == nil
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
				if (c.type == .C8yGroup) {
                    let g: C8yGroup = c.wrappedValue()
                    let x = g.objectFor(c8yId)
                    
                    if (x.object != nil) {
                        found = x.object!
                        path.append(contentsOf: x.path)
                        
                        break
                    }
                }
            }
        }
        
        return (path, found)
    }
    
    func _counter(_ counter:(C8yCounter) -> Void) {
    
        for obj in self.children {
            
			if (obj.type == .C8yGroup) {
                (obj.wrappedValue() as C8yGroup)._counter(counter)
            } else {
                counter(C8yCounter(for: obj.wrappedValue() as C8yDevice))
            }
        }
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

public enum C8yGroupCategory: String, CaseIterable, Hashable, Identifiable {
    case unknown = ""
    case empty = "empty"
    case group = "group"
    case organisation = "organisation"
    case building = "building"
    case room = "room"
    case asset = "asset"
    case device = "device"
    
    public var id: C8yGroupCategory {self}
    
    static public func displayableForHighLevel() -> [C8yGroupCategory] {
        
        var out:[C8yGroupCategory] = []
        out.append(.organisation)
        out.append(.building)
        out.append(.group)

        return out
    }
    
    static public func displayableForLowLevel() -> [C8yGroupCategory] {
        
        var out:[C8yGroupCategory] = []
        out.append(.group)
        out.append(.building)
        out.append(.room)
        out.append(.asset)

        return out
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
    case offline // no status
    case maintenance
    case undeployed // never deployed
}

enum C8yDeviceUpdateError: Error {
    case reason (String?)
}