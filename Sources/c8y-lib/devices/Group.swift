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

/**
Encapsulates a c8y `C8yManagedObject` managed object and treats it as a group exposing attributes and methods typically attributed to managing a group.

Also includes a number of custom atributes to better categorise devices such as `groupCategory`, `info` etc.
*/
public struct C8yGroup: C8yObject {

	/**
	client side id, required by SwiftUI for display purposes
	*/
    public var id = UUID().uuidString

	/**
	Dictionary of all related external id's.
	Not populated by default, unless you use the class `C8yAssetCollection` to manage your groups and devices
	*/
    public var externalIds: [String:C8yExternalId] = [String:C8yExternalId]()
	
	/**
	Implemented in accordance to protocol `C8yObject` in order to categorise the type of group
	e.g. physical building, room etc. or logical folder, division etc.
	*/
    public var groupCategory: C8yGroupCategory {
		get {
			if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] != nil) {
				return C8yGroupCategory(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] as! C8yStringCustomAsset).value) ?? .unknown
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
			self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringCustomAsset(c.rawValue)
		}
	}

	/**
	String representing the hierachy in which group belongs, i.e. list the parent group in which device is nested.
	This is only provided if you used `C8yAssetCollection` to fetch the device
	*/
    public internal(set) var hierachy: String?
    
	/**
	Custom attribute to locate the group if it represents a physical category such as Site, Building or Room.
	*/
    public var info: Info {
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
				self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] = C8yStringCustomAsset(self.info.orgName)
			}
        }
    }
    
	/**
	Returns a list of all the subgroups associated with this group
	*/
	public var subGroups: [C8yGroup] {
		get {
			var subGroups: [C8yGroup] = []
			
			for c in self.children {
			
				if (c.type == .C8yGroup) {
					subGroups.append(c.wrappedValue())
				}
			}
			
			return subGroups
		}
	}
	
	/**
	Override default version to only return count of devices that have alarms and not the total number of alarms
	*/
	public var alarmsCount: Int {
		
		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g.alarmsCount
			} else {
				let d: C8yDevice = o.wrappedValue()
				if (d.alarmsCount > 0) {
					count += 1
				}
			}
		}
		
		return count
	}
	
	/**
	Returns a list of all the subgroups and devices associated with this group
	*/
    public internal(set) var children: [AnyC8yObject] = [AnyC8yObject]()
	
	/**
	Represents the wrapped Managed Object that defines this group
	*/
    public var wrappedManagedObject: C8yManagedObject
        
	/**
	Constructor to create a group for the given c8y managed object
	- throws Error if managed object does not reference a group asset
	*/
    public init(_ obj: C8yManagedObject) throws {
       
		if (obj.id != nil && !obj.isGroup) {
			throw GroupDecodingError.notAGroupObject(object: obj)
		}
		
        self.init(obj, parentGroupName: nil)
    }
    
	/**
	Constructor to define a new group with the given attributes
	- parameter c8yId: required if you want to create a group for an existing c8y group, nil if you want to create a new group
	- parameter name: The name attributed to the group
	- parameter isTopLevelGroup: if true the group will be visible in groups menu navigation on the left hand side of the Cumulocity web app. Otherwise will only be available as a sub-folder once you have assigned it to a parent group
	- parameter notes: optional notes to be associated with the group
	*/
	public init(_ c8yId: String?, name: String, isTopLevelGroup: Bool, category: C8yGroupCategory, notes: String?) {
		
		self.init(C8yManagedObject(name: name, type: isTopLevelGroup ? C8Y_MANAGED_OBJECTS_GROUP_TYPE : C8Y_MANAGED_OBJECTS_SUBGROUP_TYPE, notes: notes), parentGroupName: nil)
		
		self.groupCategory = category

		if (c8yId != nil) {
			self.wrappedManagedObject.updateId(c8yId!)
		}
		
		self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringCustomAsset(category.rawValue)
	}
	
    internal init(_ c8yId: String?, name: String, category: C8yGroupCategory, parentGroupName: String?, notes: String?) {
        
		self.init(C8yManagedObject(name: name, type: parentGroupName == nil ? C8Y_MANAGED_OBJECTS_GROUP_TYPE : C8Y_MANAGED_OBJECTS_SUBGROUP_TYPE, notes: notes), parentGroupName: parentGroupName)
		
		self.groupCategory = category
		
        if (c8yId != nil) {
            self.wrappedManagedObject.updateId(c8yId!)
        }
        
        self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XGROUP_CATEGORY] = C8yStringCustomAsset(category.rawValue)
    }
    
	internal init(_ c8yId: String) {
		// fake group
		
		self.init(C8yManagedObject(name: "top", type: "", notes: ""), parentGroupName: nil)
		
		self.wrappedManagedObject.updateId(c8yId)
	}
	
    internal init(_ obj: C8yManagedObject, parentGroupName: String?) {
            
        self.hierachy = parentGroupName
        self.wrappedManagedObject = obj
        
		let orgName = obj.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] != nil ? (obj.properties[C8Y_MANAGED_OBJECTS_XORG_NAME] as! C8yStringCustomAsset).value : "undefined"
		
		self.info = Info(orgName: orgName, subName: nil, address: obj.properties[JC_MANAGED_OBJECT_ADDRESS] as? C8yAddress,
                                                                  contact: obj.properties[JC_MANAGED_OBJECT_CONTACT] as? C8yContactInfo,
                                                                  planning: obj.properties[JC_MANAGED_OBJECT_PLANNING] as? C8yPlanning)
    }
    
	public static func == (lhs: C8yGroup, rhs: C8yGroup) -> Bool {
		lhs.c8yId == rhs.c8yId
	}

	/**
	Convenience method to determine if the given group matches all of the same attributes as this group
	*/
    public func isDifferent(_ group: C8yGroup) -> Bool {
        
        return group.info.isDifferent(group.info) || (position == nil && group.position != nil) || (position != nil && position!.isDifferent(group.position))
    }
    
	/**
	Convenience method to determine if the given device matches on of the devices associated with this group
	*/
    public func isDifferent(_ device: C8yDevice) -> Bool {
        
        let obj: AnyC8yObject? = self.childWith(c8yId: device.c8yId!, returnParent: false)
        
        if (obj == nil) {
            return true
        } else {
            let d: C8yDevice = obj!.wrappedValue()
            return d.isDifferent(device)
        }
    }
    
	/**
	Returns a string representing the default external id and type if provided or if not the c8y internal id.
	
	Format is key='value' e.g.
		c8y_Serial=122434344
		c8y_id=9393
	*/
    public func defaultIdAndType() -> String {
        
        var idType = C8Y_INTERNAL_ID
        var id = self.c8yId
        
        if (self.externalIds.count > 0) {
			idType = self.externalIds.first!.key
            id = self.externalIds.first!.value.externalId
        }
        
        return "\(idType)=\(id ?? "unassigned")"
    }
    
	/**
	Returns the default external id if provided or if not the c8y internal id.
	*/
	public func defaultId() -> String? {
		
		var id = self.c8yId
		
		if (self.externalIds.count > 0) {
			id = self.externalIds.first!.value.externalId
		}
		
		return id
	}
	
	/**
	Returns a UIImage representing a QR code of the default id of this device
	
	- returns: UIImage representing a QR code
	*/
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
    
	/**
	Returns true if the given external id matches one for this group
	
	- parameter forExternalId: the value, must match the value for the associated type
	- parameter type: describes external id, must match a type given in `externalIds`
	- returns: true if a match is found, false otherwise
	*/
    public func match(forExternalId id: String, type: String?) -> Bool {
                   
        if (type == nil || type == C8Y_INTERNAL_ID) {
            return self.c8yId == id
        } else {
            return (self.externalIds[type!] != nil && self.externalIds[type!]!.externalId == id)
        }
    }
    
	/**
	Returns true if a sub-asset with the given internal id is found in this group or one its children
	- parameter c8yId: internal id of the asset to check for
	- returns: true if found somewhere in groups children
	*/
	public func contains(_ c8yId: String) -> Bool {
	
		return self.objectOf(c8yId: c8yId) != nil
	}
	
	/**
	returns the sub-group matching the given external id in this group or one of its children
	- parameter ref: either name or internal id of asset for which we want to find its parent
	- returns: parent group of sub-asset or nil if the asset does not exist
	*/
	public func group(forExternalId id: String, ofType type: String) -> C8yGroup? {
	 
		return self.finder(nil, ext: id, ofType: type)
	}
	
	/**
	returns the sub-group matching the given reference which could be the name of the asset or its internal id
	Will also check sub-groups continuously
	- parameter ref: either name or internal id of asset for which we want to find its parent
	- returns: parent group of sub-asset or nil if the asset does not exist
	*/
    func group(ref: String) -> C8yGroup? {
           
        var found: C8yGroup? = nil
                   
        for c in self.children {
            if (c.c8yId == ref || (c.wrappedValue() as C8yGroup).name == ref) {
                found = self
            }
            else if (c.type == .C8yGroup) {
                found = (c.wrappedValue() as C8yGroup).group(ref: ref)
            }
            
            if (found != nil) {
                break
            }
        }
        
        return found
    }

	/**
	returns the device within this group or one of its children for the given id
	- parameter c8yId: internal id of the device or group to be searched for
	- returns: Found device or nil if not found
	*/
	public func device(withC8yId c8yId: String?) -> C8yDevice? {
		
		return self.finder(c8yId, ext: nil, ofType: nil)
	}
	
	/**
	returns the device within this group or one of its children for the given external id

	- parameter forExternalId: the value, must match the value for the associated type
	- parameter type: describes external id, must match a type given in `externalIds`
	- returns: true if a match is found, false otherwise
	*/
	public func device(forExternalId id: String, ofType type: String) -> C8yDevice? {
	 
		return self.finder(nil, ext: id, ofType: type)
	}
	
	/**
	Will return the parent group of the asset referred to by the given internal id.
	This could be the group itself if the asset is an immediate child of this group or a sub-group if not
	- parameter c8yId: internal id of the device or group to be searched for
	- returns: Found asset or nil if not found
	*/
    func parentOf(c8yId: String) -> AnyC8yObject? {
        return childWith(c8yId: c8yId, returnParent : true)
    }
    
	/**
	returns the asset within this group or one of its children whether it is a group
	or device.
	- parameter c8yId: internal id of the device or group to be searched for
	- returns: Found asset or nil if not found
	*/
    func objectOf(c8yId: String) -> AnyC8yObject? {
        return childWith(c8yId: c8yId, returnParent: false)
    }
    
	/**
	Adds the given asset to the group
	- parameter object: asset to be added to the group
	*/
    public mutating func addToGroup<T:C8yObject>(_ object: T)  {
        
		_ = self._update(object, updateIfPresent: true)
    }
    
	/**
	Adds the given asset to the sub-group within this group one of its children
	
	- parameter c8yIdOfSubGroup: internal id of the sub group
	- parameter object: asset to be added to the group
	- returns: true if the sub group was found and the asset added, false if the sub group cannot be found
	*/
    public mutating func addToGroup<T:C8yObject>(c8yIdOfSubGroup c8yId: String, object: T) -> Bool {
        
		if (self.c8yId == c8yId) {
			return self._update(object, updateIfPresent: true)
		} else {
			
			var i: Int  = 0
			for c in self.children {
				if (c.type == .C8yGroup) {
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
    
	/**
	Removes the specified asset from the group or sub group of one of its children
	- parameter c8yId: id of the asset to be removed
	- returns: true if the asset was found and removed
	*/
    public mutating func removeFromGroup(_ c8yId: String) -> Bool {
        
		return self.replace(c8yId, object: C8yGroup(""))
    }
    
	/**
	Replaces the current asset in the group or sub group of one of its children
	- parameter object: The object to be replaced
	- returns: true if the asset was found and replaced, false if not
	*/
    public mutating func replaceInGroup<T:C8yObject>(_ object: T) -> Bool {
        
		return self.replace(object.c8yId!, object: object)
    }
    
    private func indexOfManagedObject(_ obj: C8yManagedObject) -> Int {
           
        var index = -1
           
        for i in self.children.indices {
            if (self.children[i].c8yId == obj.id) {
                index = i
                break
            }
        }
           
        return index
    }
    
    private func finder<T:C8yObject>(_ id: String?, ext: String?, ofType type: String?) -> T? {
    
        var found: T? = nil
        
        for (c) in self.children {
			if (c.type == .C8yDevice && c.type.rawValue == "\(T.self)") {
                
                if ((id != nil && id! == c.c8yId) || (ext != nil && (c.wrappedValue() as T).match(forExternalId: ext!, type: type!))) {
                    found = c.wrappedValue()
                    break
                }
            }
            
            if (c.type == .C8yGroup) {
                    
                let c8yGroup: C8yGroup = c.wrappedValue()
                found = c8yGroup.finder(id, ext: ext, ofType: type)
                    
                if (found != nil) {
                    break
                }
            }
        }
        
        return found
    }
        
	private func childWith(c8yId: String, returnParent: Bool) -> AnyC8yObject? {
		   
		var found: AnyC8yObject? = nil
		
		if (self.c8yId == c8yId) {
			return AnyC8yObject(self)
		}
		else if (self.hasChildren) {
		   
			for c in self.children {
				if (c.type == .C8yDevice && (c.c8yId == c8yId || (c.wrappedValue() as C8yDevice).name == c8yId)) {
					found = returnParent ? AnyC8yObject(self) : c
				}
				else if (c.type == .C8yGroup) {
					found = (c.wrappedValue() as C8yGroup).childWith(c8yId: c8yId, returnParent: returnParent)
				}
				
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
					if (object.c8yId == nil || object.c8yId!.isEmpty) {
						self.children.remove(at: i)
					} else {
						self.children[i] = AnyC8yObject(object)
					}
					
					matched = true
				} else if (c.type == .C8yGroup) {
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

        if (self.indexOfChild(obj.c8yId ?? "xxxx") == -1) {
                        
            let wrapper = AnyC8yObject(obj)
            
            if (wrapper.type == .C8yGroup) {
                self.children.insert(wrapper, at: 0)
            } else {
                self.children.append(wrapper)
            }
            
            return true
        } else if (updateIfPresent) {
            _ = self._replaceChild(c8yId: obj.c8yId!, with: obj)
            
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
	
	private func _alarmsCount() -> Int {
	
		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g._alarmsCount()
			} else {
				let d: C8yDevice = o.wrappedValue()
				if (d.alarmsCount > 0) {
					count += 1
				}
			}
		}
		
		return count
	}
	
	private func _deviceCount() -> Int {

		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g._alarmsCount()
			} else {
				count += 1
			}
		}
			   
		return count
	}
	   
	private func _onlineCount() -> Int {
		
		var count: Int = 0
		
		for o in self.children {
			if o.type == .C8yGroup {
				let g: C8yGroup = o.wrappedValue()
				count += g._alarmsCount()
			} else {
				let d: C8yDevice = o.wrappedValue()
				if (d.status != .UNAVAILABLE) {
					count += 1
				}
			}
		}
			   
		return count
	}
	
	/**
	Thrown from init if wrapped Managed Object is not a group asset
	*/
	public enum GroupDecodingError: Error {
		case notAGroupObject(object: C8yManagedObject)
	}
	
	/**
	Represents a custom structure to allow more functional information to be associated with a group, such as contacts if it represents a physical entitiy or a planning date
	if it is to be used to group assets based on scheduling etc. etc.
	
	The element is broken out into strings at the top level of the managed object to ensure that they can be viewed/edited using the standard c8y Property Editor widget
	*/
	public struct Info {
		
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
		
		public func isDifferent(_ info: Info?) -> Bool {
			
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

}
