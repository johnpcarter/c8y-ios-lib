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

public struct C8yGroup: C8yObject {

    public var id = UUID().uuidString

    public var externalIds: [String:C8yExternalId] = [String:C8yExternalId]()

    public static func == (lhs: C8yGroup, rhs: C8yGroup) -> Bool {
        lhs.c8yId == rhs.c8yId
    }
    
    public var groupCategory: C8yGroupCategory {
		get {
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
		set(c) {
			self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringWrapper(c.rawValue)
		}
	}

    public internal(set) var hierachy: String?
    
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
			
			if (!self.info.orgName.isEmpty) {
				self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] = C8yStringWrapper(self.info.orgName)
			}
        }
    }
    
	public var subGroups: [C8yGroup] {
		get {
			var subGroups: [C8yGroup] = []
			
			for c in self.children {
			
				if (c.type == "C8yGroup") {
					subGroups.append(c.wrappedValue())
				}
			}
			
			return subGroups
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
        
        self.init(C8yManagedObject(name: "top", type: "", notes: ""), parentGroupName: nil)
        self.wrappedManagedObject.updateId(c8yId)
    }
    
    public init(_ obj: C8yManagedObject) {
       
        self.init(obj, parentGroupName: nil)
    }
    
    init(_ c8yId: String?, name: String, category: C8yGroupCategory, parentGroupName: String?, notes: String?) {
        
        self.init(C8yManagedObject(name: name, type: parentGroupName == nil ? C8Y_MANAGED_OBJECTS_GROUP_TYPE : C8Y_MANAGED_OBJECTS_SUBGROUP_TYPE, notes: notes), parentGroupName: parentGroupName)
        
        if (c8yId != nil) {
            self.wrappedManagedObject.updateId(c8yId!)
        }
        
        self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringWrapper(category.rawValue)
    }
    
    init(_ obj: C8yManagedObject, parentGroupName: String?) {
            
        self.hierachy = parentGroupName
        self.wrappedManagedObject = obj
        
		let orgName = obj.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] != nil ? (obj.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] as! C8yStringWrapper).value : "undefined"
		
		self.info = C8yGroupInfo(orgName: orgName, subName: nil, address: obj.properties[JC_MANAGED_OBJECT_ADDRESS] as? C8yAddress,
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
    
    public func defaultIdAndType() -> String {
        
        var idType = "c8yId"
        var id = self.c8yId
        
        if (self.externalIds.count > 0) {
			idType = self.externalIds.first!.key
            id = self.externalIds.first!.value.externalId
        }
        
        return "\(idType)=\(id)"
    }
    
	public func defaultId() -> String {
		
		var id = self.c8yId
		
		if (self.externalIds.count > 0) {
			id = self.externalIds.first!.value.externalId
		}
		
		return id
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
    
    public mutating func addToGroup<T:C8yObject>(_ object: T)  {
        
		_ = self._update(object, updateIfPresent: true)
    }
    
    public mutating func addToGroup<T:C8yObject>(c8yIdOfSubGroup c8yId: String, object: T) -> Bool {
        
		if (self.c8yId == c8yId) {
			return self._update(object, updateIfPresent: true)
		} else {
			
			var i: Int  = 0
			for c in self.children {
				if (c.type == "C8yGroup") {
					var g: C8yGroup = c.wrappedValue()
					
					if (g.addToGroup(c8yIdOfSubGroup: c8yId, object: object)) {
						self.children[i] = AnyC8yObject(g)
						
						return true
					}
				}
				
				i += 1
			}
		}
		
		return false
    }
    
    public mutating func removeFromGroup(_ c8yId: String) -> Bool {
        
		return self.replace(c8yId, object: C8yGroup(""))
    }
    
    public mutating func replaceInGroup<T:C8yObject>(_ object: T) -> Bool {
        
		return self.replace(object.c8yId, object: object)
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
        
	private mutating func replace<T:C8yObject>(_ c8yId: String, object: T) -> Bool {
		
		var matched: Bool = false
		
		if (self.hasChildren) {
			
			var i: Int = 0
			
			for c in self.children {
								
				if (c.c8yId == c8yId) {
					if (object.c8yId.isEmpty) {
						self.children.remove(at: i)
					} else {
						self.children[i] = AnyC8yObject(object)
					}
					
					matched = true
				} else if (c.type == "C8yGroup") {
					// check subgroups
					
					var v: C8yGroup = c.wrappedValue()
				
					if (v.replace(c8yId, object: object)) {
						self.children[i] = AnyC8yObject(v)
					
						matched = true
					}
				}
			
				i += 1
			}
		}
		
		return matched
	}
	
    private mutating func _update<T:C8yObject>(_ obj: T, updateIfPresent: Bool) -> Bool {

        if (self.indexOfChild(obj.c8yId) == -1) {
            
            print("=======> Adding \(obj.name)")
            
            let wrapper = AnyC8yObject(obj)
            
            if (wrapper.type == "C8yGroup") {
                self.children.insert(wrapper, at: 0)
            } else {
                self.children.append(wrapper)
            }
            
            return true
        } else if (updateIfPresent) {
            _ = self._replaceChild(c8yId: obj.c8yId, with: obj)
            
            return true
        }
        
        return false
    }
    
    private mutating func _replaceChild<T:C8yObject>(c8yId: String, with object: T) -> Bool {
           
        let i = self.indexOfChild(c8yId)
           
        if (i != -1) {
            self.children[i] = AnyC8yObject(object)
            return true
        } else {
            return false
        }
    }
}


public struct C8yGroupInfo {
    
    public internal(set) var orgName: String
    public internal(set) var subName: String?
    
    public internal(set) var contractRef: String?
    
    public internal(set) var address: C8yAddress?
    
    public internal(set) var planning: C8yPlanning?
    
    public internal(set) var siteOwner: C8yContactInfo?
    public internal(set) var adminOwner: C8yContactInfo?
    
    public init(orgName: String, subName: String?, address: C8yAddress?, contact: C8yContactInfo?, planning: C8yPlanning?) {
        
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
