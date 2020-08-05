//
//  Site.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

import UIKit

let C8Y_MANAGED_OBJECTS_GROUP = "c8y_DeviceGroup"
let C8Y_MANAGED_OBJECTS_SUBGROUP = "c8y_DeviceSubgroup"

public struct C8yGroup: C8yObject {

    public var id = UUID().uuidString

    public var externalIds: [String:C8yExternalId] = [String:C8yExternalId]()

    public static func == (lhs: C8yGroup, rhs: C8yGroup) -> Bool {
        lhs.c8yId == rhs.c8yId
    }
    
    public var groupCategory: C8yGroupCategory {
        if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] != nil) {
            return C8yGroupCategory(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] as! C8yStringWrapper).value) ?? .unknown
        } else if (self.children.count > self.deviceCount){
            
            // this group has sub-folders
            
            if (self.orgCategory != .na) {
                return .organisation
            } else {
                return .group
            }
            
        } else if (self.deviceCount > 0) {
            
            // just devices (bottom)
            
            return .group
        } else {
            
            return .empty
        }
    }

    public internal(set) var location: String?
    
    public var info: C8yGroupInfo {
        didSet {
            if (self.info.address != nil) {
                self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_ADDRESS] = self.info.address!
            }
            
            if (self.info.siteOwner != nil) {
                self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_CONTACT] = self.info.siteOwner!
            }
            
            if (self.info.planning != nil) {
                self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_PLANNING] = self.info.planning!
            }
        }
    }
    
    public internal(set) var children: [AnyC8yObject] = [AnyC8yObject]()

    public var deviceCount: Int {
        var count = 0
        for c in self.children {
            if (c.type == "C8yDevice") {
                count += 1
            } else {
                count += (c.wrappedValue() as C8yGroup).deviceCount
            }
        }
        return count
    }
    
    public var wrappedManagedObject: C8yManagedObject
        
    public init(_ c8yId: String) {
        // fake group
        
        self.init(C8yManagedObject(name: "top", type: "", notes: ""), location: nil)
        self.wrappedManagedObject.updateId(c8yId)
    }
    
    public init(_ obj: C8yManagedObject) {
       
        self.init(obj, location: nil)
    }
    
    init(_ c8yId: String?, name: String, category: C8yGroupCategory, location: String?, notes: String?) {
        
        self.init(C8yManagedObject(name: name, type: location == nil ? C8Y_MANAGED_OBJECTS_GROUP : C8Y_MANAGED_OBJECTS_SUBGROUP, notes: notes), location: location)
        
        if (c8yId != nil) {
            self.wrappedManagedObject.updateId(c8yId!)
        }
        
        self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringWrapper(category.rawValue)
    }
    
    init(_ obj: C8yManagedObject, location: String?) {
            
        self.location = location
        self.wrappedManagedObject = obj
        
        self.info = C8yGroupInfo(orgName: obj.name ?? "undefined", subName: nil, address: obj.properties[JC_MANAGED_OBJECT_ADDRESS] as? C8yAddress,
                                                                  contact: obj.properties[JC_MANAGED_OBJECT_CONTACT] as? C8yContactInfo,
                                                                  planning: obj.properties[JC_MANAGED_OBJECT_PLANNING] as? C8yPlanning)
    }
    
    public func isDifferent(_ group: C8yGroup) -> Bool {
        
        return group.info.isDifferent(group.info) || (position == nil && group.position != nil) || (position != nil && position!.isDifferent(group.position))
    }
    
    public func isDifferent(_ device: C8yDevice) -> Bool {
        
        let obj: AnyC8yObject? = self.childWith(c8yId: device.c8yId, returnParent: false)
        
        if (obj == nil) {
            return true
        } else {
            let d: C8yDevice = obj!.wrappedValue()
            return d.isDifferent(device)
        }
    }
    
    public func defaultExternalIdAndType() -> String {
        
        var idType = "c8yId"
        var id = self.c8yId
        
        if (self.externalIds.count > 0) {
            idType = C8yEditableGroup.GROUP_ID_TYPE
            id = self.externalIds.first!.value.externalId
        }
        
        return "\(idType)=\(id)"
    }
    
    public func generateQRCodeImage() throws -> UIImage {
        return try self.generateQRCodeImage(forType: nil)
    }
    
    public func isPlannedForDate(_ date: Date) -> Bool {
     
        if (self.info.planning != nil && self.info.planning!.planningDate != nil) {
            return self.info.planning!.planningDate!.isSameDay(date)
        } else {
            return false
        }
    }
    
    public func contains(_ c8yId: String) -> Bool {
    
        return self.objectOf(c8yId: c8yId) != nil
    }
    
    public func match(forExternalId id: String, type: String?) -> Bool {
                   
        if (type == nil || type == "c8yId") {
            return self.c8yId == id
        } else {
            return (self.externalIds[type!] != nil && self.externalIds[type!]!.externalId == id)
        }
    }
    
    func groupFor(ref: String) -> C8yGroup? {
           
        var found: C8yGroup? = nil
                   
        for c in self.children {
            if (c.c8yId == ref || (c.wrappedValue() as C8yGroup).name == ref) {
                found = self
            }
            else if (c.type == "C8yGroup") {
                found = (c.wrappedValue() as C8yGroup).groupFor(ref: ref)
            }
            
            if (found != nil) {
                break
            }
        }
        
        return found
    }

    func parentOf(c8yId: String) -> AnyC8yObject? {
        return childWith(c8yId: c8yId, returnParent : true)
    }
    
    func objectOf(c8yId: String) -> AnyC8yObject? {
        return childWith(c8yId: c8yId, returnParent: false)
    }
    
    private func childWith(c8yId: String, returnParent: Bool) -> AnyC8yObject? {
           
        var found: AnyC8yObject? = nil
        
        if (self.c8yId == c8yId) {
            return AnyC8yObject(self)
        }
        else if (self.hasChildren) {
           
            for c in self.children {
                if (c.type == "C8yDevice" && (c.c8yId == c8yId || (c.wrappedValue() as C8yDevice).name == c8yId)) {
                    found = returnParent ? AnyC8yObject(self) : c
                }
                else if (c.type == "C8yGroup") {
                    found = (c.wrappedValue() as C8yGroup).childWith(c8yId: c8yId, returnParent: returnParent)
                }
                
                if (found != nil) {
                    break
                }
            }
        }
        
        return found
    }
    
    public mutating func addToGroup<T:C8yObject>(_ object: T) -> C8yGroup? {
        
        return self._add(object, updateIfPresent: true)
    }
    
    public mutating func addToGroup<T:C8yObject>(c8yIdOfGroup c8yId: String, object: T) -> C8yGroup? {
        
        return self.process(c8yId) { group in
            var copy = group
            return copy._add(object, updateIfPresent: false)
        }        
    }
    
    public mutating func removeFromGroup(_ c8yId: String) -> C8yGroup? {
        
        return self.process(c8yId) { group in
            var copy = group
            return copy._remove(c8yId)
        }
    }
    
    public mutating func replaceInGroup<T:C8yObject>(_ object: T) -> C8yGroup? {
        
        return self.process(c8yId) { group in
            var copy = group
            return copy._replaceChild(c8yId: object.c8yId, with: object)
        }
    }

    public func device(forId id: String?) -> C8yDevice? {
        
        return self.finder(id, ext: nil, ofType: nil)
    }
    
    public func device(forExternalId id: String, ofType type: String) -> C8yDevice? {
     
        return self.finder(nil, ext: id, ofType: type)
    }
    
    public func group(forExternalId id: String, ofType type: String) -> C8yGroup? {
     
        return self.finder(nil, ext: id, ofType: type)
    }
    
    public  func indexOfManagedObject(_ obj: C8yManagedObject) -> Int {
           
        var index = -1
           
        for i in self.children.indices {
            if (self.children[i].c8yId == obj.id) {
                index = i
                break
            }
        }
           
        return index
    }
    
    func finder<T:C8yObject>(_ id: String?, ext: String?, ofType type: String?) -> T? {
    
        var found: T? = nil
        
        for (c) in self.children {
             if (c.type == "C8yDevice" && c.type == "\(T.self)") {
                
                if ((id != nil && id! == c.c8yId) || (ext != nil && (c.wrappedValue() as T).match(forExternalId: ext!, type: type!))) {
                    found = c.wrappedValue()
                    break
                }
            }
            
            if (c.type == "C8yGroup") {
                    
                let c8yGroup: C8yGroup = c.wrappedValue()
                found = c8yGroup.finder(id, ext: ext, ofType: type)
                    
                if (found != nil) {
                    break
                }
            }
        }
        
        return found
    }
        
    private mutating func process(_ c8yId: String, processor: (C8yGroup) -> C8yGroup?) -> C8yGroup? {
           
        if (self.c8yId == c8yId) {
           return processor(self)
        }
        else if (self.hasChildren) {
           
           for c in self.children {
               
               if (c.c8yId == c8yId) {
                   return processor(self)
               } else if (c.type == "C8yGroup") {
                   // check subgroups
                   
                   var group: C8yGroup = c.wrappedValue()
                   let parentGroup = group.process(c8yId, processor: processor)
                   
                   // cascade struct up structure, replacing each one
                   
                   if (parentGroup != nil && self._replaceChild(c8yId: parentGroup!.c8yId, with: parentGroup!) != nil) {
                      return self
                   } else {
                       return nil
                   }
               }
           }
        }
        
        return nil
    }
    
    private mutating func _add<T:C8yObject>(_ obj: T, updateIfPresent: Bool) -> C8yGroup? {

        if (self.indexOfChild(obj.c8yId) == -1) {
            
            print("=======> Adding \(obj.name)")
            
            let wrapper = AnyC8yObject(obj)
            
            if (wrapper.type == "C8yGroup") {
                self.children.insert(wrapper, at: 0)
            } else {
                self.children.append(wrapper)
            }
            
            return self
        } else if (updateIfPresent) {
            _ = self._replaceChild(c8yId: obj.c8yId, with: obj)
            
            return self
        }
        
        return nil
    }
    
    private mutating func _remove(_ c8yId: String) -> C8yGroup? {
           
        //DispatchQueue.main.sync {
            
            if (self.indexOfChild(c8yId) != -1) {
                
                self.children.remove(at: self.indexOfChild(c8yId))

                return self
            } else {
                return nil
            }
       // }
    }
    
    private mutating func _replaceChild<T:C8yObject>(c8yId: String, with object: T) -> C8yGroup? {
           
        let i = self.indexOfChild(c8yId)
           
        if (i != -1) {
            self.children[i] = AnyC8yObject(object)
            return self
        } else {
            return nil
        }
    }
}


public struct C8yGroupInfo {
    
    public var orgName: String
    public var subName: String?
    
    public var contractRef: String?
    
    public internal(set) var address: C8yAddress?
    
    public var planning: C8yPlanning?
    
    public var siteOwner: C8yContactInfo?
    public var adminOwner: C8yContactInfo?
    
    init(orgName: String, subName: String?, address: C8yAddress?, contact: C8yContactInfo?, planning: C8yPlanning?) {
        
        self.orgName = orgName
        self.subName = subName
        self.address = address
        self.siteOwner = contact
        self.planning = planning
        
        self.adminOwner = nil
        self.contractRef = nil
    }
    
    public func isDifferent(_ info: C8yGroupInfo?) -> Bool {
        
        if (info == nil) {
            return true
        } else {
            return self.orgName != info?.orgName
                    || self.subName != info?.subName
                    || self.contractRef != info?.contractRef
                    || self.address == nil && info?.address != nil
                    || self.address == nil && info?.address != nil
                    || self.siteOwner == nil && info?.siteOwner != nil
                    || self.planning == nil && info?.planning != nil
                    || (self.address != nil && self.address!.isDifferent(info!.address))
                    || (self.siteOwner != nil && self.siteOwner!.isDifferent(info!.siteOwner))
                    || (self.planning != nil && self.planning!.isDifferent(info!.planning))
        }
    }
}
