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

    convenience init(_ m: C8yManagedObject, conn: C8yCumulocityConnection, path: String?, includeGroups: Bool) throws {
    
        try self.init(C8yGroup(m), conn: conn, path: path, includeGroups: includeGroups)
    }
    
    init(_ group: C8yGroup, conn: C8yCumulocityConnection, path: String?, includeGroups: Bool) {
        
        self.parent = group
        self._includeGroups = includeGroups
        
        self._c8yId = self.parent.c8yId!
        self._conn = conn
        self._path = group.hierachy
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
                        
        C8yManagedObjectsService(_conn).get(forQuery: query, pageNum: pageNum).sink(receiveCompletion: { completion in
            			
			//self._groupLoader.send(completion: .finished)
			
        }, receiveValue: { response in
                        
            self._remainingObjects = response.content!.objects
            self._response = response
            
            self._unwrapAssets()

        }).store(in: &_cancellableSet)
    }
        
    func _unwrapAssets() {
        
        // process one element after another
        		
        let m: C8yManagedObject? = self._remainingObjects.popLast()
        
        if (m != nil) {
            
			do {
				if (m!.isGroup) {
					try processGroupObject(m!)
				} else { //TODO: And what about the rest
					try processDeviceObject(m!)
				}
			} catch {
				print("error \(error.localizedDescription)")
				// can happen, just ignore and go to next element in list.
				self._unwrapAssets()
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
							self.parent.children.removeAll { (o) -> Bool in
								return o.c8yId == c.c8yId!
							}
						}
					}
                }
            }
			
			self._groupLoader.send(parent)
			self._groupLoader.send(completion: .finished)
        }
    }
    
    func processDeviceObject(_ m: C8yManagedObject) throws {
                           
        let device = try C8yDevice(m, hierachy: self._path ?? "")
           
		self.externalIdsForDevice(device) { updatedDevice, completion in
			
			if (!self._refreshOnly || self.parent.isDifferent(updatedDevice)) {
				self.parent.addToGroup(updatedDevice)
			}
			
			self.processedObjects.append(updatedDevice.c8yId!)

            switch completion {
            case .failure(let error):
                print(error)
                self._unwrapAssets() // continue even with error
            case .finished:
                self._unwrapAssets()
            }
		}
    }
	
	private func externalIdsForDevice(_ device: C8yDevice, completionHandler: @escaping (C8yDevice, Subscribers.Completion<JcConnectionRequest<C8yCumulocityConnection>.APIError>) -> Void) {
	
		var updatedDevice: C8yDevice = device
		
		C8yManagedObjectsService(_conn).externalIDsForManagedObject(device.wrappedManagedObject.id!).subscribe(Subscribers.Sink(receiveCompletion: { completion in
		  
			completionHandler(updatedDevice, completion)
			
		}, receiveValue: { response in
			updatedDevice.setExternalIds(response.content!.externalIds)
		}))
	}
	
    func processGroupObject(_ m: C8yManagedObject) throws {
        
        let currentGroup: C8yGroup? = self.parent.parentOf(c8yId: m.id!)?.wrappedValue()
        var childGroup: C8yGroup = try C8yGroup(m)
        
        if (currentGroup != nil) {
            childGroup = currentGroup!
        }
        
        C8yManagedObjectsService(_conn).externalIDsForManagedObject(childGroup.wrappedManagedObject.id!).sink(receiveCompletion: { (completion) in
           
			GroupLoader(childGroup, conn: self._conn, path: self.determinePath(m), includeGroups: self._includeGroups).load().sink(receiveCompletion: { (completion) in
				switch completion {
				case .failure(let error):
					print(error)
				case .finished:
					
					if (self._includeGroups) {
						self.parent.addToGroup(childGroup)
					}
					
					// flag updates
					
					self._groupLoader.send(self.parent)
					
					self._unwrapAssets()
				}
			}, receiveValue: { (response) in
									
				childGroup = response
				
				if (!self._includeGroups) {
					
					// merge child assets with parent group
					
					for c in childGroup.children {
						if (c.type == .C8yDevice) {
							let d: C8yDevice = c.wrappedValue()
							self.parent.addToGroup(d)
							self.processedObjects.append(d.c8yId!)
						} else {
							let g: C8yGroup = c.wrappedValue()
							do {
								try self.processGroupObject(g.wrappedManagedObject)
							} catch {
								// already checked type above, can't happen
							}
						}
					}
				}
			}).store(in: &self._cancellableSet)
			
        }, receiveValue: { response in
            
            childGroup.setExternalIds(response.content!.externalIds)
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
