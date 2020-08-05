//
//  SitesManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

//import SwiftUI
/**
 
 */
public class C8yMyGroups: ObservableObject {
        
    @Published public var objects: [AnyC8yObject] = []

    private let _objectsLockQueue = DispatchQueue(label: "c8y.objects.lock.queue")

    private var _refreshTimer: JcRepeatingTimer? = nil
    private var _reload: Bool = false
    private var _firstLoadCompleted: Bool = false
    private var _lastLoadError: Error? = nil
    private var _cancellableSet: Set<AnyCancellable> = []
    private let _cancellableLockQueue = DispatchQueue(label: "cancellable.lock.queue")

    public internal(set) var connection: C8yCumulocityConnection?
        
    private var _networks: C8yNetworks? = nil
    public var networks: C8yNetworks {
        get {
            
            if (self._networks == nil) {
                self._networks = C8yNetworks(self.connection!)
            }
            
            return self._networks!
        }
    }
    
    public private(set) var groupCount: Int = 0
    public private(set) var deviceCount: Int = 0

    public init() {
        print("setting up MyGroups")
    }
    
    deinit {
       // self._cancellableLockQueue.async {
            for c in self._cancellableSet {
                c.cancel()
            }
       // }
    }
    
    public func setRefresh(_ interval: Double, includeSubGroups: Bool) {
            
        if (interval <= 0) {
            
            if (self._refreshTimer != nil) {
                self._refreshTimer?.suspend()
            }
        } else {
            if (self._refreshTimer == nil) {
                self._refreshTimer = JcRepeatingTimer(timeInterval: interval)
                
                self._refreshTimer!.eventHandler = {
                    
                    DispatchQueue.main.sync {
                        self.doRefresh(includeSubGroups: includeSubGroups) {
                        }
                    }
                }
                
                self._refreshTimer!.resume(interval)
            }
        }
    }

    public func stopRefresh() {
    
        self._refreshTimer?.suspend()
    }
    
    public func refreshAsset<T:C8yObject>(_ asset: T) {
            
        self._updateAsset(asset, inGroup: self.groupFor(c8yId: asset.c8yId))
    }
    
    public func doRefresh(includeSubGroups: Bool, completionHandler: @escaping () -> Void) {
        
        var groupCountDown = self.groupCount
        var deviceCountDown = self.deviceCount

        self._cancellableSet.removeAll()
        
        for e in self.objects {
            
            if (e.type == "C8yGroup") {
                let group: C8yGroup = e.wrappedValue()
                
                let loader: GroupLoader = GroupLoader(group, conn: self.connection!, path: nil, includeGroups: includeSubGroups)
                self._storeCancellable(loader.refresh()
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { (completion) in
                        switch completion {
                        case .failure(let error):
                            print(error)
                            if (error.httpCode == 404) {
                                // delete it
                                _ = self.removeFromMyGroups(c8yId: group.c8yId)
                            }
                        case .finished:
                            print("done")
                        }
                        
                        if (groupCountDown == 0) {
                            completionHandler()
                        }
                        
                    }, receiveValue: { (group) in
                        groupCountDown -= 1
                        self._addToFavourites(group)
                    }))
            } else {
                
                var device: C8yDevice = e.wrappedValue()
                
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(device.c8yId)
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print(error)
                        if (error.httpCode == 404) {
                            // remove it from favourites
                            _ = self.removeFromMyGroups(c8yId: device.c8yId)
                        }
                    case .finished:
                        print("done")
                    }
                }, receiveValue: { (response) in
                    
                    deviceCountDown -= 1
                    
                    let newDevice: C8yDevice = C8yDevice(response.content!)
                    
                    self._storeCancellable(C8yManagedObjectsService(self.connection!).externalIDsForManagedObject(device.wrappedManagedObject.id!)
                        .receive(on: RunLoop.main)
                        .sink(receiveCompletion: { completion in
                        
                    }, receiveValue: { response in
                        
                        device.setExternalIds(response.content!.externalIds)
                        
                        if (device.isDifferent(newDevice)) {
                            self._addToFavourites(device)
                        }
                    }))
                }))
                
                if (deviceCountDown == 0) {
                    completionHandler()
                }
            }
        }
    }
    
    public func load(_ conn: C8yCumulocityConnection?, c8yReferencesToLoad: [String], includeSubGroups: Bool) throws -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
    
        self.connection = conn
    
        self.objects.removeAll()
        self.deviceCount = 0
        self.groupCount = 0

        return try self._load(c8yReferencesToLoad, includeSubGroups: includeSubGroups)
    }
    
    public func reload(_ c8yReferencesToLoad: [String], includeSubGroups: Bool) throws -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError>? {
            
        if (!_firstLoadCompleted) {
            return nil
        }
        
        self._cancellableSet.removeAll()
        
        for r in self.objects {
            if (!c8yReferencesToLoad.contains(r.c8yId!)) {
                _ = self.removeFromMyGroups(c8yId: r.c8yId!)
            }
        }
        
        return try self._load(c8yReferencesToLoad, includeSubGroups: includeSubGroups)
    }
    
    public func clear() {
    
        self.connection = nil
        self._cancellableSet.removeAll()
        self.objects.removeAll()
        self.deviceCount = 0
        self.groupCount = 0
    }
    
    public func isInMyGroups(_ group: C8yGroup) -> Bool {
        
        return self.isInMyGroups(group.c8yId)
    }
    
    public func isInMyGroups(_ c8yId: String) -> Bool {
        
        return self.objects.contains { (o) -> Bool in
            return o.c8yId == c8yId
        }
    }

    public func groupFor(c8yId: String) -> C8yGroup? {
    var found: C8yGroup? = self._objectFor(c8yId, excludeDevices: true)
        
        if (found == nil) {
            // look in children
            
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    let g: C8yGroup = o.wrappedValue()
                    
                    let object = g.parentOf(c8yId: c8yId)
                    
                    if (object != nil && object!.type == "C8yGroup") {
                        found = object!.wrappedValue()
                        break
                    }
                }
            }
        }
        
        return found
    }
    
    public func deviceFor(_ ref: String) -> C8yDevice? {
    
        var found: C8yDevice? = self._objectFor(ref, excludeDevices: false)
        
        if (found == nil) {
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    
                    let d: C8yDevice = o.wrappedValue()
                    
                    if (d.name.contains(ref) || d.match(forExternalId: ref, type: nil)) {
                        found = d
                        break
                    }
                }
            }
        }
        
        if (found == nil) {
            // look in children
            
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    
                    let g: C8yGroup = o.wrappedValue()

                    found = g.objectOf(c8yId: ref)?.wrappedValue()
                    
                    if (found != nil) {
                        break
                    }
                }
            }
        }
        
        return found
    }
    
    public func deviceFor(externalId: String, ofType type: String) -> C8yDevice? {
        
        var found: C8yDevice? = nil
        
        for o in self.objects {
            
            if (o.type == "C8yDevice") {
                let device: C8yDevice = o.wrappedValue()
                
                if (device.match(forExternalId: externalId, type: type)) {
                    found = device
                    break
                }
            } else {
                let g: C8yGroup = o.wrappedValue()

                found = g.device(forExternalId: externalId, ofType: type)
                
                if (found != nil) {
                    break
                }
            }
        }
        
        return found
    }
    
    public func objectFor(_ ref: String) -> (path: [String]?, object: AnyC8yObject?) {
    
        var found: AnyC8yObject? = nil
        var path: [String]? = nil
        
        
        for o in self.objects {
            if o.c8yId == ref {
                found = o
                break
            }
        }
        
        if (found == nil) {
            
            // look in children
            
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    let g: C8yGroup = o.wrappedValue()
                    
                    let x = g.objectFor(ref)
                    
                    if (x.object != nil) {
                        found = x.object
                        path = x.path
                    }
                }
            }
        }
        
        return (path, found)
    }
    
    public func addToMyGroups<T:C8yObject>(_ object: T) {
        
        self._addToFavourites(object)
    }
    
    public func removeFromMyGroups(c8yId: String) -> Bool {
                 
        self._removeFromFavourites(c8yId)
    }
    
    public func lookupGroupAndAddToMyGroups(c8yId: String, includeSubGroups: Bool, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
        
        if (!self.isInMyGroups(c8yId)) {
                        
            self._storeCancellable(C8yManagedObjectsService(self.connection!).get(c8yId)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                completionHandler(self.addManagedObjectAsGroup(response.content!, includeSubGroups: includeSubGroups), response.error)
            }))
        } else {
            
            completionHandler(self.groupFor(c8yId: c8yId), nil)
        }
    }
    
    public func add<T:C8yObject>(_ object: T, completionHandler: @escaping (T?, Error?) -> Void) throws {
           
        if (object.externalIds.count > 0) {
            self._storeCancellable(try C8yManagedObjectsService(self.connection!).post(object.wrappedManagedObject, withExternalId: object.externalIds.first!.value.externalId, ofType: object.externalIds.first!.value.type)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                self._postAdd(object, response: response, completionHandler: completionHandler)
            }))
        } else {
            self._storeCancellable(try C8yManagedObjectsService(self.connection!).post(object.wrappedManagedObject).sink(receiveCompletion: { completion in
                print("done")
            }, receiveValue: { response in
                self._postAdd(object, response: response, completionHandler: completionHandler)
            }))
        }
    }
    
    private func _postAdd<T:C8yObject>(_ object: T,response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (T?, Error?) -> Void) {
        
        var newObject = object
        newObject.setC8yId(response.content!.id!)
                                           
        self._addToFavourites(newObject)
           
        completionHandler(newObject, nil)
    }
    
    public func addToGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, completionHandler: @escaping (T?, Error?) -> Void) throws {
           
        if (object.externalIds.count > 0) {
            self._storeCancellable(try C8yManagedObjectsService(self.connection!).post(object.wrappedManagedObject, withExternalId: object.externalIds.first!.value.externalId, ofType: object.externalIds.first!.value.type)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                self._postAddToGroup(object, c8yOfGroup: c8yOfGroup, response: response, completionHandler: completionHandler)
            }))
        } else {
            self._storeCancellable(try C8yManagedObjectsService(self.connection!).post(object.wrappedManagedObject)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                self._postAddToGroup(object, c8yOfGroup: c8yOfGroup, response: response, completionHandler: completionHandler)
            }))
        }
    }
   
    public func assignToGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, completionHandler: @escaping (T?, Error?) -> Void) {
        self._assignToGroup(object.c8yId, c8yOfGroup: c8yOfGroup) { success, error in
                
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    var group: C8yGroup = o.wrappedValue()
                    let changedGroup = group.addToGroup(c8yIdOfGroup: group.c8yId, object: object)
                    
                    if (changedGroup != nil) {
                        self._addToFavourites(group)
                    }
                }
            }

            completionHandler(object, nil)
        }
    }
    
    private func _postAddToGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (T?, Error?) -> Void) {
        
       var newObject = object
            
        newObject.setC8yId(response.content!.id!)
        self.assignToGroup(newObject, c8yOfGroup: c8yOfGroup, completionHandler: completionHandler)
    }
    
    public func saveChanges<T:C8yObject>(_ object: T, completionHandler: @escaping (Bool, Error?) -> Void) throws {
          
        self._storeCancellable(try C8yManagedObjectsService(self.connection!).put(object.wrappedManagedObject)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                completionHandler(false, error)
            case .finished:
                print("done")
            }
        }, receiveValue: { (response) in
                                    
            // if a device is referenced eleswhere, check sub-levels
            
            self.refreshAsset(object)
                            
            completionHandler(true, nil)
        }))
    }
    
    public func delete<T:C8yObject>(_ object: T, completionHandler: @escaping (Bool) -> Void) {
        
        self._storeCancellable(C8yManagedObjectsService(self.connection!).delete(id: object.c8yId)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                completionHandler(false)
            case .finished:
                print("done")
            }
        }, receiveValue: { (response) in
            for o in self.objects {
                
                if (o.type == "C8yGroup") {
                    var group: C8yGroup = o.wrappedValue()
                    let changedGroup = group.removeFromGroup(object.c8yId)
                    
                    if (changedGroup != nil) {
                        self._addToFavourites(changedGroup!)
                    }
                }
            }
        }))
    }
    
    public func lookupGroup(c8yId id: String, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
        
        let found: C8yGroup? = self.groupFor(c8yId: id)
        
        if (found == nil) {
            
            // still no luck, lookup in c8y directly
            
            self._storeCancellable(C8yManagedObjectsService(self.connection!).get(id).sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                completionHandler(C8yGroup(response.content!), nil)
            }))
        } else {
            completionHandler(found, nil)
        }
    }
    
    public func lookupDevice(c8yId id: String, completionHandler: @escaping (C8yDevice?, Error?) -> Void) {
        
        let found: C8yDevice? = self.deviceFor(id)
                
        if (found == nil) {
            
            // still no luck, lookup in c8y directly
            
            self._storeCancellable(C8yManagedObjectsService(self.connection!).get(id).sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { response in
                
                var device = C8yDevice(response.content!)
                
                self.fetchExternalIds(device.c8yId) { success, externalIds in
                
                    if (success) {
                        device.setExternalIds(externalIds)
                    }
                    
                    completionHandler(device, nil)
                }
            }))
        } else {
            completionHandler(found, nil)
        }
    }
    
    public func lookupDevice(forExternalId id: String, ofType type: String, completionHandler: @escaping (C8yDevice?, JcConnectionRequest<C8yCumulocityConnection>.APIError?) -> Void) {
        
        let found: C8yDevice? = self.deviceFor(externalId: id, ofType: type)

        if (found == nil) {
            
            // still no luck, lookup in c8y directly

            self._storeCancellable(C8yManagedObjectsService(self.connection!).get(forExternalId: id, ofType: type)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print(error)
                    completionHandler(nil, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { (response) in
                var device = C8yDevice(response.content!)
                self.fetchExternalIds(device.c8yId) { success, externalIds in
                
                    if (success) {
                        device.setExternalIds(externalIds)
                    }
                    
                    completionHandler(device, nil)
                }
            }))
        } else {
            completionHandler(found, nil)
        }
    }

    public func lookupGroup(forExternalId id: String, type: String, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
        
        var found: C8yGroup? = nil
        
        for o in self.objects {
    
            if (o.type == "C8yGroup") {
                let g: C8yGroup = o.wrappedValue()
                
                if (g.match(forExternalId: id, type: type)) {
                    found = g
                    break
                }
            }
        }
        
        if (found == nil) {
            
            for o in self.objects {

                if (o.type == "C8yGroup") {
                
                    let g: C8yGroup = o.wrappedValue()
                    
                    found = g.group(forExternalId: id, ofType: C8yEditableGroup.GROUP_ID_TYPE)
                    
                    if (found != nil) {
                        break
                    }
                }
            }
        }

        if (found == nil && self.connection != nil) {
            
            // still no luck, lookup in c8y directly

            if (type == "c8yId") {
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(id).sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print(error)
                        completionHandler(nil, error)
                    case .finished:
                        print("done")
                    }
                }, receiveValue: { response in
                    self._postLookupGroup(response, completionHandler: completionHandler)
                }))
            } else {
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(forExternalId: id, ofType: C8yEditableGroup.GROUP_ID_TYPE)
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { (completion) in
                    switch completion {
                    case .failure(let error):
                        print(error)
                        if (error.httpCode == 404) {
                            completionHandler(nil, nil)
                        } else {
                            completionHandler(nil, error)
                        }
                    case .finished:
                        print("done")
                    }
                }, receiveValue: { (response) in
                    self._postLookupGroup(response, completionHandler: completionHandler)

                }))
            }
        } else {
            completionHandler(found, nil)
        }
    }
    
    private func _updateAsset<T:C8yObject>(_ asset: T, inGroup group: C8yGroup?) {
        
        if (group != nil) {
            var groupCopy: C8yGroup! = group
            self._replace(groupCopy.replaceInGroup(asset))
        } else {
            self._addToFavourites(asset)
        }
    }
    
    private func _replace(_ updatedGroup: C8yGroup?) {
        
        if (updatedGroup == nil) {
            return
        }
        
        var pgroup: C8yGroup? = self.groupFor(c8yId: updatedGroup!.c8yId)
        
        if (pgroup != nil && pgroup?.c8yId != updatedGroup?.c8yId) {
            self._replace(pgroup!.replaceInGroup(updatedGroup!))
        } else {
            // reached top
            
            self._addToFavourites(updatedGroup!)
        }
    }
    
    private func _postLookupGroup(_ response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
     

        var group = C8yGroup(response.content!)
        self.fetchExternalIds(group.c8yId) { success, externalIds in
            
            if (success) {
                group.setExternalIds(externalIds)
            }
        }
        completionHandler(group, nil)
    }
    
    private func _assignToGroup(_ c8yId: String, c8yOfGroup: String, completionHandler: @escaping (Bool, Error?) -> Void) {
            
        do {
            self._storeCancellable(try C8yManagedObjectsService(self.connection!).assignToGroup(child: c8yId, parentId: c8yOfGroup)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    completionHandler(false, error)
                case .finished:
                    print("done")
                }
            }, receiveValue: { (response) in
                completionHandler(true, nil)

            }))
       } catch {
           completionHandler(false, error)
       }
    }
    
    public func fetchExternalIds(_ c8yId: String, completionHandler: @escaping (Bool, [C8yExternalId]) -> Void) {
        
        self._storeCancellable(C8yManagedObjectsService(self.connection!).externalIDsForManagedObject(c8yId)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                completionHandler(false, [])
            case .finished:
                print("done")
            }
        }, receiveValue: { (response) in
           completionHandler(true, response.content == nil ? [] : response.content!.externalIds)
        }))
    }
    
    private func _load(_ c8yReferencesToLoad: [String], includeSubGroups: Bool) throws -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                   
        if (self.connection != nil) {
            return self._load(c8yReferencesToLoad, pageNum: 0, includeSubGroups: includeSubGroups)
        } else {
            throw makeError("No connnection available")
        }
    }
    
    private func _load(_ c8yReferencesToLoad: [String], pageNum: Int, includeSubGroups: Bool) -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
        
        let p = PassthroughSubject<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError>()

        if (c8yReferencesToLoad.count == 0) {
            
            DispatchQueue.main.async {
                p.send(completion: .finished)
            }
            
            return p.eraseToAnyPublisher()
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            
            print(">>>>>>>>>>>>>>>>>> LOAD STARTED")
            
            for c8yId in c8yReferencesToLoad {
                
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(c8yId).sink(receiveCompletion: { completion in
                    if (c8yId == c8yReferencesToLoad.last) {
                        self._firstLoadCompleted = true
                        print(">>>>>>>>>>>>>>>>>> LOAD ENDED")

                        p.send(completion: .finished)
                    }
                    switch completion {
                    case .failure(let error):
                        print(error)
                    case .finished:
                        print("not yet")
                    }
                }, receiveValue: { response in
                    if (response.content!.isDevice) {
                        var newDevice = C8yDevice(response.content!)
                        self._storeCancellable(C8yManagedObjectsService(self.connection!).externalIDsForManagedObject(response.content!.id!)
                            .receive(on: RunLoop.main)
                            .sink(receiveCompletion: { completion in
                            self._addToFavourites(newDevice)
                        }, receiveValue: { exts in
                            if (exts.content != nil) {
                                newDevice.setExternalIds(exts.content!.externalIds)
                            }
                        }))
                    } else {
                        self._addGroup(C8yGroup(response.content!, location: nil), includeSubGroups: includeSubGroups)
                    }
                    
                    p.send(self.objects)
                }))
            }
        }
        
        return p.eraseToAnyPublisher()
    }
    
    private func addManagedObjectAsGroup(_ m: C8yManagedObject, includeSubGroups: Bool) -> C8yGroup {
        
        let newGroup = C8yGroup(m, location: nil)
        
        if (Thread.isMainThread) {
            self._addGroup(newGroup, includeSubGroups: includeSubGroups)
        } else {
            DispatchQueue.main.async{
                self._addGroup(newGroup, includeSubGroups: includeSubGroups)
            }
        }
        
        return newGroup
    }
    
    private func _addGroup(_ group: C8yGroup, includeSubGroups: Bool) {
        
        print("Group loader for \(group.c8yId) started")
        
        var didAdd: Bool = false
        
        self._storeCancellable(GroupLoader(group.wrappedManagedObject, conn: self.connection!, path: nil, includeGroups: includeSubGroups).load()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print("Group loader for \(group.c8yId) failed: \(error)")
                self._lastLoadError = error
            case .finished:
                print("Group loader for \(group.c8yId) done")
                if (!didAdd) {
                    _ = self._addToFavourites(group)
                }
            }
        }, receiveValue: { (newGroup) in
            print("Group loader for \(group.c8yId) value received")
            
            _ = self._addToFavourites(newGroup)
            didAdd = true
        }))
    }
    
    private func _addToFavourites<T:C8yObject>(_ object: T) {
        
        self._objectsLockQueue.sync {
            
            if (object is C8yGroup) {
                
                let newGroup: AnyC8yObject = AnyC8yObject(object)
                let existingObject: C8yGroup? = self._objectFor(object.c8yId, excludeDevices: true)
                
                if (existingObject == nil) {
                    
                    print("====== Inserting group \(object.c8yId)")
                    
                    self.objects.insert(newGroup, at: 0)
                } else {
                    // replace
                    
                    for i in self.objects.indices {
                        if (self.objects[i].c8yId == newGroup.c8yId) {
                            
                            print("====== Updating group \(object.c8yId)")
                            
                            self.objects[i] = newGroup
                            break
                        }
                    }
                }
            } else if (object is C8yDevice) {
                
                let existingObject: C8yDevice? = self._objectFor(object.c8yId, excludeDevices: false)
                
                if (existingObject == nil) {
                    
                    let newDevice: AnyC8yObject = AnyC8yObject(object)
                    
                    if (self.objects.count > 0) {
                        
                        if (!self.objects.contains(where: { (r) -> Bool in
                            return r.c8yId == newDevice.c8yId
                        })) {
                            for i in self.objects.indices.reversed() {
                                if (self.objects[i].type != "c8yDevice" && self.objects[i].type != "c8yGroup") {
                                    if (i == self.objects.count-1) {
                                        self.objects.append(newDevice)
                                        break
                                    } else {
                                        self.objects.insert(newDevice, at: i)
                                        break
                                    }
                                }
                            }
                        } else {
                            // replace
                            
                            for i in self.objects.indices {
                                if (self.objects[i].c8yId == newDevice.c8yId) {
                                    self.objects[i] = newDevice
                                    break
                                }
                            }
                        }
                    } else {
                        self.objects.append(newDevice)
                    }
                } else {
                    
                    // replace existing
                    
                    for i in self.objects.indices {
                        if (self.objects[i].c8yId == object.c8yId) {
                            
                            print("====== Updating device \(object.c8yId)")
                            
                            let device: AnyC8yObject = AnyC8yObject(object)

                            self.objects[i] = device
                            break
                        }
                    }
                }
            }
        }
    }
    
    private func _removeFromFavourites(_ c8yId: String) -> Bool {
    
        var found: Bool = false
        
        self._objectsLockQueue.sync {
            for i in self.objects.indices {
                
                if (self.objects[i].c8yId == c8yId) {
                    self.objects.remove(at: i)
                    found = true
                    break
                }
            }
        }
        
        
        return found
    }
    
    func makeError(_ message: String) -> Error {
            
        return C8yDeviceUpdateError.reason(message)
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
    
    public enum APIAccessError: Error {
        case message (String)
    }
    
    private func _storeCancellable(_ c: AnyCancellable) {
           
        _ = self._cancellableLockQueue.sync {
            self._cancellableSet.insert(c)
        }
    }
    
    private func _removeCancellable(_ c: AnyCancellable) {
           
        self._cancellableLockQueue.async {
            self._cancellableSet.remove(c)
        }
    }
    
    private func _objectFor<T:C8yObject>(_ c8yId: String, excludeDevices: Bool) -> T? {
            
        var found: T? = nil
        
        for o in self.objects {
            if (o.c8yId == c8yId && (o.type == "C8yGroup" || !excludeDevices)) {
                found = o.wrappedValue()
                break
            }
        }
        
        return found
    }
    
    public class GroupSummary: Identifiable {
        
        public let id: String
        public let name: String?
        public let includeSubGroups: Bool
        
        private var _owner: C8yMyGroups
        
        public init(_ id: String, name: String, isSelected: Bool, includeSubGroups: Bool, owner: C8yMyGroups) {
        
            self._owner = owner
            self.includeSubGroups = includeSubGroups
            self.id = id
            self.name = name
            self.isSelected = isSelected
        }
        
        @Published public var isSelected: Bool {
            didSet {
                if (self.isSelected) {
                    self._owner.lookupGroupAndAddToMyGroups(c8yId: self.id, includeSubGroups: includeSubGroups) { (group, error) in
                        // TODO report error
                        
                    }
                } else {
                    _ = self._owner.removeFromMyGroups(c8yId: self.id)
                }
            }
        }
    }
}
