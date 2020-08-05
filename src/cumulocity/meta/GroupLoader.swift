//
//  GroupLoader.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

class GroupLoader {
    
    var parent: C8yGroup
    
    var processedObjects: [String] = []
    
    private let _c8yId: String
    private let _conn: C8yCumulocityConnection
    private let _includeGroups: Bool
    private let _path: String?
    private var _refreshOnly: Bool = false
    
    private var _remainingObjects: [C8yManagedObject]
    
    private var _groupLoader = PassthroughSubject<C8yGroup, JcConnectionRequest<C8yCumulocityConnection>.APIError>()
    private var _response: JcRequestResponse<C8yPagedManagedObjects>?
    private var _currentPage: Int = 0
    
    private var _cancellableSet: Set<AnyCancellable> = []

    convenience init(_ m: C8yManagedObject, conn: C8yCumulocityConnection, path: String?, includeGroups: Bool) {
    
        self.init(C8yGroup(m), conn: conn, path: path, includeGroups: includeGroups)
    }
    
    init(_ group: C8yGroup, conn: C8yCumulocityConnection, path: String?, includeGroups: Bool) {
        
        self.parent = group
        self._includeGroups = includeGroups
        
        self._c8yId = self.parent.c8yId
        self._conn = conn
        self._path = group.location
        self._remainingObjects = []
        self.processedObjects = []
    }
    
    deinit {
        
        for c in self._cancellableSet {
            c.cancel()
        }
    }
    
    func refresh() -> AnyPublisher<C8yGroup, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
           
        self._refreshOnly = true
        return self.load()
    }
       
    func load() -> AnyPublisher<C8yGroup, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
        
        self._load(self._currentPage)

        return self._groupLoader.eraseToAnyPublisher()
    }
    
    func _load(_ pageNum: Int) {
        
        var query = C8yManagedObjectQuery()
        query.add(key: "bygroupid", op: nil, value: self._c8yId)
                
        print("Group loader - Internal - started scanning group \(self._c8yId)")
        
        C8yManagedObjectsService(_conn).get(forQuery: query, pageNum: pageNum).sink(receiveCompletion: { completion in
            
            switch completion {
            case .failure:
                print("Group loader - Internal - failed for group \(self._c8yId) - \(completion)")
               // self._groupLoader.send(completion: completion)
            case .finished:
                print("Group loader - Internal - done for group \(self._c8yId)")
            }
        }, receiveValue: { response in
            
            print("Group loader - Internal - processing value for \(self._c8yId)")
            
            self._remainingObjects = response.content!.objects
            self._response = response
            
            self._unwrapAssets()

        }).store(in: &_cancellableSet)
    }
        
    func _unwrapAssets() {
        
        // process one element after another
        
        let m: C8yManagedObject? = self._remainingObjects.popLast()
        
        if (m != nil) {
            print("====> Popped \(String(describing: m!.name))")
            
            if (m!.type == C8Y_MANAGED_OBJECTS_GROUP || m!.type == C8Y_MANAGED_OBJECTS_SUBGROUP) {
                processGroupObjects(m!)
            } else if (m!.type != "c8y_PrivateSmartRule") { //TODO: And what about the rest
                processDeviceObject(m!)
            }
        } else  {
            
            // reached end of group, do we need to load next page
            
            if (self._response!.content != nil && self._response!.content!.objects.count > self._response!.content!.statistics.pageSize) {
                // load next page
                _currentPage += 1
                self._load(self._currentPage)
            } else {
            
                if (self._refreshOnly) {
                    
                    // reached end, remove all objects that are not in processed list i.e. don't exist any more
                    
                    for c in self.parent.children {
                        if (!self.processedObjects.contains(c.c8yId!)) {
                            _ = self.parent.removeFromGroup(c.c8yId!)
                        }
                    }
                }
                
                // flag completion
                                   
                self._groupLoader.send(completion: .finished)
            }
            
            // flag latest changes
            
            self._groupLoader.send(self.parent)
        }
    }
    
    func processDeviceObject(_ m: C8yManagedObject) {
                           
        var device = C8yDevice(m, location: self._path ?? "")
           
        C8yManagedObjectsService(_conn).externalIDsForManagedObject(device.wrappedManagedObject.id!).sink(receiveCompletion: { completion in
          
            switch completion {
            case .failure(let error):
                print("failed to load device object for \(String(describing: device.wrappedManagedObject.id))")
                print(error)
                self._unwrapAssets() // continue even with error
            case .finished:
                self._unwrapAssets()
            }
        }, receiveValue: { response in
            device.setExternalIds(response.content!.externalIds)
            
            if (!self._refreshOnly || self.parent.isDifferent(device)) {
                if (self.parent.replaceInGroup(device) == nil) {
                    _ = self.parent.addToGroup(device)
                }
                
                self.processedObjects.append(device.c8yId)
            }
            // flag update up chain
            
            self._groupLoader.send(self.parent)
        }).store(in: &self._cancellableSet)
    }
    
    func processGroupObjects(_ m: C8yManagedObject) {
        
        let currentGroup: C8yGroup? = self.parent.parentOf(c8yId: m.id!)?.wrappedValue()
        var childGroup: C8yGroup = C8yGroup(m)
        
        if (currentGroup != nil) {
            childGroup = currentGroup!
        }
        
        C8yManagedObjectsService(_conn).externalIDsForManagedObject(childGroup.wrappedManagedObject.id!).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print("failed to load group object for \(String(describing: currentGroup?.wrappedManagedObject.id))")
                print(error)
            case .finished:
                print("done for \(childGroup.wrappedManagedObject.name!)")
            }
        }, receiveValue: { response in
            
            childGroup.setExternalIds(response.content!.externalIds)
            // now process children in group
            
            print("sub group started \(String(describing: childGroup.wrappedManagedObject.name))")

            GroupLoader(childGroup, conn: self._conn, path: self.determinePath(m), includeGroups: self._includeGroups).load().sink(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    print("failed to load group object for \(String(describing: childGroup.wrappedManagedObject.name))")
                    print(error)
                case .finished:
                    print("sub group finished \(String(describing: childGroup.wrappedManagedObject.name)) - children \(childGroup.children.count)")
                    self._unwrapAssets()
                }
            }, receiveValue: { (response) in
                    
                childGroup = response
                
                if (!self._includeGroups) {
                    
                    // merge child with this group
                    
                    for c in childGroup.children {
                        if (c.type == "C8yDevice") {
                            let d: C8yDevice = c.wrappedValue()
                            _ = self.parent.addToGroup(d)
                            self.processedObjects.append(d.c8yId)
                        } else {
                            let g: C8yGroup = c.wrappedValue()
                            self.processGroupObjects(g.wrappedManagedObject)
                        }
                    }
                    
                } else {                    
                    _ = self.parent.addToGroup(childGroup)
                }
                
                // flag updates
                
                self._groupLoader.send(self.parent)

            }).store(in: &self._cancellableSet)
        }).store(in: &self._cancellableSet)
    }
    
    func determinePath(_ m: C8yManagedObject) -> String {
        
        var newPath: String
                   
        if _path == nil {
            newPath = m.name ?? ""
        } else {
            newPath = "\(_path!), \(m.name!)"
        }
        
        return newPath
    }
}
