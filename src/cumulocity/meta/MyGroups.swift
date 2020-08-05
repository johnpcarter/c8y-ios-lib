//
//  SitesManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let JC_NETWORK_TYPE = "LoRa Network Server type"

/**
 
 */
public class C8yMyGroups: ObservableObject {
    
    public var environmentObject: ObservableObjectPublisher? = nil
        
    /**
     
     */
    public var planningDate: Date {
        get {
            return _planningDate
        }
        set(date) {
            if (_planningDate != date) {
                self._planningDate = date
                self.reload(flattenGroupHierachy: self._flattenGroupHierachy) { (success, error) in
                    // log error
                        
                    self.lastLoadError = error
                }
            }
        }
    }
                
    public internal(set) var availableGroups: [GroupSummary] = []
    
    var _topGroup: C8yGroup = C8yGroup("top", flattenSubGroups: true) {
        didSet {
            // required if using this with an environment object as updates from here don't get propagated properly
            
            if (self.environmentObject != nil) {
                self.environmentObject!.send()
            }
        }
    }

    internal var _myGroupReferences: Array<String> = Array()

    private var _refreshTimer: JcRepeatingTimer? = nil
    
    private(set) var _conn: C8yCumulocityConnection?

    private var _planningDate: Date = Date()
    private var _flattenGroupHierachy: Bool = false
    private var lastLoadError: Error? = nil
    
    private var cancellableSet: Set<AnyCancellable> = []

    public init() {
    }
    
    deinit {
        
        for c in cancellableSet {
            c.cancel()
        }
    }
    
    public convenience init(_ observer: ObservableObjectPublisher) {
        self.init()
        self.environmentObject = observer
    }
    
    public func setRefresh(_ interval: Double) {
            
        if (self._refreshTimer == nil) {
            self._refreshTimer = JcRepeatingTimer(timeInterval: interval)
            
            self._refreshTimer!.eventHandler = {
                
                self._load() { (success, error) in
                    print("Reloaded with success: \(success)")
                }
            }
        }
        
        if (interval > 0) {
            self._refreshTimer?.resume(interval)
        } else {
            self._refreshTimer?.suspend()
        }
    }

    public func stopRefresh() {
    
        self._refreshTimer?.suspend()
    }
    
    public func reload(flattenGroupHierachy: Bool, completionHandler: @escaping (Bool, Error?)->Void) {
       
        self._flattenGroupHierachy = flattenGroupHierachy
        
        self._load(completionHandler)
    }
       
   public func load(_ conn: C8yCumulocityConnection?, planningDate: Date?, flattenGroupHierachy: Bool, myGroupReferences: [String]?, completionHandler: @escaping (Bool, Error?)->Void) {
    
        if (conn == nil) {
            completionHandler(false, RuntimeError("No connection provided!"))
        }
    
        self._conn = conn
    
        self._flattenGroupHierachy = flattenGroupHierachy
        self._topGroup = C8yGroup("top", flattenSubGroups: self._flattenGroupHierachy)
    
        if (planningDate != nil) {
            self._planningDate = planningDate!
        }
    
        if (myGroupReferences != nil) {
            _myGroupReferences = myGroupReferences!
        } else {
            _myGroupReferences = []
        }
    
        self._load(completionHandler)
    }
    
    private func _load(_ completionHandler: @escaping (Bool, Error?)->Void) {
                
        if (self._conn != nil) {
            self.availableGroups.removeAll()
            self._load(0, completionHandler: completionHandler)
        }
    }
    
    public func clear() {
    
        self._conn = nil
        self.availableGroups.removeAll()
        self._topGroup = C8yGroup("top", flattenSubGroups: self._flattenGroupHierachy)
    }
    
    public func addGroup(_ group: C8yGroup, completionHandler: @escaping (Bool, Error?) -> Void) throws {
        
        _ = try C8yManagedObjectsService(self._conn!).post(group.toManagedObject()) { (response) in
            
            if (response.status == .SUCCESS) {
                
                self._myGroupReferences.append(group.c8yId!)
                completionHandler(true, nil)
            } else {
                completionHandler(false, response.error)
            }
        }
    }
    
    public func updateGroup(_ group: C8yGroup, completionHandler: @escaping (Bool, Error?) -> Void) throws {
           
       _ = try C8yManagedObjectsService(self._conn!).put(group.toManagedObject()) { (response) in
           
           if (response.status == .SUCCESS) {
               
               completionHandler(true, nil)
           } else {
               completionHandler(false, response.error)
           }
       }
    }
    
    public func addToMyGroups(c8yId: String) {
        
        self.addToMyGroups(c8yId: c8yId) { group, error in
            // do nothing
        }
    }
    
    public func addToMyGroups(c8yId: String, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
           
        self._myGroupReferences.append(c8yId)
                
        _ = C8yManagedObjectsService(self._conn!).get(c8yId) { (response) in
            
            var newGroup: C8yGroup? = nil
            
            if (response.status == .SUCCESS) {
                newGroup = self.addManagedObjectAsGroup(response.content!)
            }
            
            completionHandler(newGroup, response.error)
        }
    }
    
    public func addToMyGroups(group: C8yGroup) {
              
        if (group.c8yId != nil) {
            self._myGroupReferences.append(group.c8yId!)
            _ = self._addToFavourites(group)
        }
    }
    
    public func removeFromMyGroups(c8yId: String) {
           
        if (_topGroup.removeFromGroup(c8yIdOfGroup: c8yId) { (success, parentGroup) in
            // save changes from here, don't delete the goup tho!!
            
        }) {
            // topGroup changed
        }
    }
    
    public func group(c8yId: String) -> C8yGroup? {
        
        return _topGroup.groupFor(c8yId: c8yId)
    }
    
    public func group(withLabel label: String) -> C8yGroup? {
           
        return _topGroup.groupFor(label: label)

    }
    
    public func lookupDevice(forId id: String, conn: C8yCumulocityConnection, completionHandler: @escaping (C8yDevice?, Error?) -> Void) {
        
        let found: C8yDevice? = _topGroup.device(forId: id)
                
        if (found == nil) {
            
            // still no luck, lookup in c8y directly

            _ = C8yManagedObjectsService(self._conn!).get(id) { (response) in
                if (response.status == .SUCCESS && response.content != nil) {
                    completionHandler(C8yDevice(response.content!), nil)
                } else if (response.httpMessage != nil) {
                    completionHandler(nil, APIAccessError.message(response.httpMessage!))
                } else {
                    completionHandler(nil, APIAccessError.message(response.error?.localizedDescription ?? "no message"))
                }
            }
        } else {
            completionHandler(found, nil)
        }
    }
    
    public func lookupDevice(forExternalId id: String, ofType type: String, completionHandler: @escaping (C8yDevice?, Error?) -> Void) {
        
        let found: C8yDevice? = _topGroup.device(forExternalId: id, ofType: type)

        if (found == nil && self._conn != nil) {
            
            // still no luck, lookup in c8y directly

            _ = C8yManagedObjectsService(self._conn!).get(forExternalId: id, ofType: type) { (response) in
                
                DispatchQueue.main.async {
                     if (response.status == .SUCCESS && response.content != nil) {
                        var device = C8yDevice(response.content!)
                        self.fetchExternalIds(forDevice: device) { success, externalIds in
                        
                            if (success) {
                                device.setExternalIds(externalIds)
                            }
                        }
                        completionHandler(device, nil)
                     } else if (response.httpStatus == 404) {
                         // not found
                         
                         completionHandler(nil, nil)
                     } else if (response.httpMessage != nil) {
                         completionHandler(nil, APIAccessError.message(response.httpMessage!))
                     } else {
                         completionHandler(nil, APIAccessError.message(response.error?.localizedDescription ?? "no message"))
                     }
                }
            }
        } else {
            completionHandler(found, nil)
        }
    }
    
    public func deleteDevice(_ device: C8yDevice, completionHandler: @escaping (Bool) -> Void) {
     
        _ = self._topGroup.removeFromGroup(c8yIdOfGroup: device.c8yId!) { (success, parentGroup) in
            // delete here
            
            _ = C8yManagedObjectsService(self._conn!).delete(id: device.c8yId!) { response in
            
                completionHandler(response.status == .SUCCESS)
            }
        }
    }
    
    public func deleteGroup(_ group: C8yGroup, completionHandler: @escaping (Bool) -> Void) {
     
        _ = self._topGroup.removeFromGroup(c8yIdOfGroup: group.c8yId!) { (success, parentGroup) in
            // delete here
            
            _ = C8yManagedObjectsService(self._conn!).delete(id: group.c8yId!) { response in
            
                completionHandler(response.status == .SUCCESS)
            }
        }
    }
    
    private func fetchExternalIds(forDevice device: C8yDevice, completionHandler: @escaping (Bool, [C8yExternalId]) -> Void) {
        
        _ = C8yManagedObjectsService(self._conn!).externalIDsForManagedObject(device.c8yId!) { (response) in
               
            completionHandler(response.status == .SUCCESS, response.content == nil ? [] : response.content!.externalIds)
        }
    }
    
    private var _cachedNetworkProviders: Dictionary<String, [C8yDeviceNetworkInfo]>?
    
    public func networkProviders(completionHandler: @escaping (Dictionary<String, [C8yDeviceNetworkInfo]>) -> Void) {

       if (_cachedNetworkProviders != nil) {
           completionHandler(_cachedNetworkProviders!)
       } else {

           _cachedNetworkProviders = Dictionary()
            
            networkProviders(networkType: JC_NETWORK_TYPE) { providers in
                
                for p in providers {
                       
                    if (self._cachedNetworkProviders![p.instance] == nil) {
                        self._cachedNetworkProviders![p.instance] = []
                    }
                    
                    self._cachedNetworkProviders![p.instance]!.append(p)
                }
                
                completionHandler(self._cachedNetworkProviders!)
            }
        }
    }
    
    public func networkProviders(networkType: String, completionHandler: @escaping ([C8yDeviceNetworkInfo]) -> Void) {

        _ = C8yManagedObjectsService(self._conn!).get(forType: networkType, pageNum: 0) { response in

            if (response.status == .SUCCESS) {
                
                var networks: [C8yDeviceNetworkInfo] = []
 
                if (response.content != nil) {
                    for object in response.content!.objects{
                        
                        let networkInfo = C8yDeviceNetworkInfo(object)
                        
                        networks.append(networkInfo)
                   }
                }
                
                completionHandler(networks)
            }
        }
    }
    
    private func _load(_ pageNum: Int, completionHandler: @escaping (Bool, Error?)->Void) {
                
        _ = C8yManagedObjectsService(self._conn!).get(forType: C8Y_MANAGED_OBJECTS_GROUP, pageNum: pageNum) { (response) in
            
            if (response.status == .SUCCESS) {
                for (m) in response.content!.objects {
                    
                    self.availableGroups.append(GroupSummary(m.id!, name: m.name!, isSelected: self._myGroupReferences.contains(m.id!), owner: self))
                
                    if (self._myGroupReferences.contains(m.id!)) {
                        _ = self.addManagedObjectAsGroup(m)
                    }
                }
                
                if (response.content?.statistics != nil && (response.content?.objects.count)! > (response.content?.statistics.pageSize)!) {
                    // load next page
                    
                    self._load(pageNum+1, completionHandler: completionHandler)
                } else {
                    // reached end, call completionHandler
                    
                    completionHandler(true, nil)
                }
            } else {
                completionHandler(false, APIAccessError.message(response.httpMessage ?? (response.error?.localizedDescription) ?? "unknown"))
            }
        }
    }
    
    private func addManagedObjectAsGroup(_ m: C8yManagedObject) -> C8yGroup {
        
        let newGroup = C8yGroup(m, location: nil,flattenSubGroups: self._flattenGroupHierachy)
        
        if (Thread.isMainThread) {
            self._addGroup(newGroup)
        } else {
            DispatchQueue.main.async{
                self._addGroup(newGroup)
            }
        }
        
        return newGroup
    }
    
    private func _addGroup(_ group: C8yGroup) {
        
        GroupLoader(group.c8yId!, conn: self._conn!, path: nil, flattenSubGroups: self._flattenGroupHierachy).load() { newGroup in
            _ = self._addToFavourites(group)
        }
    }
    
    private func _addToFavourites(_ newGroup: C8yGroup) -> Bool {
        
        if (self._myGroupReferences.contains(newGroup.c8yId!) || newGroup.isPlannedForDate(self.planningDate) || self._topGroup.indexOfChild(newGroup.c8yId!) != -1) {
            
            _ = self._topGroup.replaceInGroup(c8yIdOfGroup: self._topGroup.c8yId!, object: newGroup) { success, group in
                
                print("did replace \(success)")
                if (!success) {
                    _ = self._topGroup.addToGroup(c8yIdOfGroup: self._topGroup.c8yId!, object: newGroup) { success, group in
                        print("added")
                    }
                }
            }
            
            return true
        } else {
            return false
        }
    }
    
    public enum APIAccessError: Error {
        case message (String)
    }
    
    public class GroupSummary: Identifiable {
        
        public let id: String
        public let name: String?
        
        private var _owner: C8yMyGroups
        
        public init(_ id: String, name: String, isSelected: Bool, owner: C8yMyGroups) {
        
            self._owner = owner
            
            
            self.id = id
            self.name = name
            self.isSelected = isSelected
        }
        
        @Published public var isSelected: Bool {
            didSet {
                if (self.isSelected) {
                    self._owner.addToMyGroups(c8yId: self.id)
                } else {
                    self._owner.removeFromMyGroups(c8yId: self.id)
                }
            }
        }
        
    }
}

class GroupLoader {
    
    let _c8yId: String
    let _conn: C8yCumulocityConnection
    let _flattenSubGroups: Bool
    let _path: String?
    
    var group: C8yGroup
    
    init(_ c8yId: String, conn: C8yCumulocityConnection, path: String?, flattenSubGroups: Bool) {
    
        self._c8yId = c8yId
        self._conn = conn
        self._path = path
        self._flattenSubGroups = flattenSubGroups
        
        self.group = C8yGroup(c8yId, flattenSubGroups: flattenSubGroups)
    }
    
    func load(completionHandler: @escaping (C8yGroup) -> Void) {
           
        self._load(self._c8yId, path: "", pageNum: 0, completionHandler: completionHandler)
    }
    
    func _load(_ id: String, path: String?, pageNum: Int, completionHandler: @escaping (C8yGroup) -> Void) {
        
        var query = C8yManagedObjectQuery()
        _ = query.add(key: "bygroupid", op: nil, value: id)
                
        _ = C8yManagedObjectsService(_conn).get(forQuery: query, pageNum: 0) { (response) in
            
            if (response.status == .SUCCESS) {
                for (m) in response.content!.objects {
                    
                    self._unwrapAsset(m, groupId: id, completionHandler: completionHandler)
                }
                
                if (response.content?.statistics != nil && (response.content?.objects.count)! > (response.content?.statistics.pageSize)!) {
                    // load next page
                    
                    self._load(id, path: path, pageNum: pageNum+1, completionHandler: completionHandler)
                } else {
                    // reached end
                    
                    completionHandler(self.group)
                }
            } else {
                //TODO report error
                print("Request failed")
            }
        }
    }
    
    func _unwrapAsset(_ m: C8yManagedObject, groupId: String, completionHandler: (C8yGroup) -> Void) {
        
        if (m.type == C8Y_MANAGED_OBJECTS_GROUP || m.type == C8Y_MANAGED_OBJECTS_SUBGROUP) {
            // scan child devices
            
            var newPath: String? = nil
            
            if (self._flattenSubGroups) {
                if _path == nil {
                    newPath = m.name
                } else {
                    newPath = "\(_path!), \(m.name!)"
                }
            }
                        
            GroupLoader(m.id!, conn: _conn, path: newPath, flattenSubGroups: self._flattenSubGroups).load() { group in
                
                if (self._flattenSubGroups) {
                                    
                    for c in group.children {
                        let device: C8yDevice = c.c8yObject()
                        self.group.children.append(AnyC8yObject(device))
                    }
                    
                } else {
                    _ = self.group.children.append(AnyC8yObject(group))
                }
            }
        } else {
            
            var device = C8yDevice(location: self._path ?? "", groupId: groupId, m: m)
            
            _ = C8yManagedObjectsService(_conn).externalIDsForManagedObject(device.wrappedManagedObject.id!) { (response) in
                
                if (response.status == .SUCCESS && response.content != nil) {
                    
                    device.setExternalIds(response.content!.externalIds)
                }
            }
            
            print("Group \(self.group.c8yId!) has \(self.group.children.count) objects")
            
            _ = self.group.children.append(AnyC8yObject(device))
        }
    }
}
