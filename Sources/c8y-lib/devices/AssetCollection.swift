//
//  SitesManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

/**
Class to allow you to manage an abritary collection of groups or devices from the users device
e.g.

```
let myCollection = C8yAssetCollection()

do {
	try myCollection.load(conn, c8yReferencesToLoad: ["9403", "9102", "2323"], includeSubGroups: true)
		.receive(on: RunLoop.main)
		.sink(receiveCompletion: { (completion) in
				
				print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>> SINK LOAD ENDED")
			}, receiveValue: { (objects) in
			
				// both devices and group, which can also be referenced via myColletion.objects, which in turn is a Published attribute and hence can
				// be referenced directly from a swiftui View if myCollection is defined either as a @StateObject or @ObservedObject
				 
				let devicesAndGroup: [AnyC8yObject] = objects
			   
			   ...
		})
} catch {
	print ("load failed \(error.localizedDescription)")
}
		
```

Devices and groups can be added to the collection using either the `add(_:)` or `addGroupReference(c8yId:includeSubGroups:completionHandler:)` methods e.g.

```
myCollection.add(device)
myCollection.addGroupReference(c8yId: "4343", includeSubgroups: true) { (group, error) in
	
	if (group != nil) {
		// success, group represents the managed object that has been fetched from c8y and added to your collection
		...
	} else {
		// lookup failed, probably due to invalid reference, refer to error object for precision
		...
}
```

You can reference the devices and groups via the `objects` attribute directly from your SwiftUI views. Ensure that you prefix
the reference to you collection attribute with @ObservedObject or @StateObject to ensure that the view automatically updates
if your collection changes e.g.

```
struct MyAssetsView: View {

	@Binding var conn: C8yCumulocityConnection
	@Binding var referenecs: [String]

	@StateObject var myCollection:C8yAssetCollection = C8yAssetCollection()
	@State var isLoading: Bool = false

	var body some View {
		VStack {
			ForEach(myCollection.objects) { r in
				Text("asset is \(r.name)")
			}
		}.onAppear {
			myCollection.load(self.conn, c8yReferencesToLoad: self.references, includeSubGroups: true)
				.sink(receiveCompletion: { (completion) in
					self.isLoading = false
			}
		}
	}
}
```
*/
public class C8yAssetCollection: ObservableObject {
        
	/**
	Objects that published from this collection. Devices and Groups are wrapped in an `AnyC8yObject` instance to avoid collection
	ambiguity errors.
	*/
    @Published public var objects: [AnyC8yObject] = []

    private let _objectsLockQueue = DispatchQueue(label: "c8y.objects.lock.queue")

    private var _refreshTimer: JcRepeatingTimer? = nil
    private var _reload: Bool = false
    private var _firstLoadCompleted: Bool = false
    private var _lastLoadError: Error? = nil
    private var _cancellableSet: Set<AnyCancellable> = []
    private let _cancellableLockQueue = DispatchQueue(label: "cancellable.lock.queue")

	/**
	The connection reference that was last used to load the collection via `load(_:c8yReferencesToLoad:includeSubGroups:)`
	*/
    public internal(set) var connection: C8yCumulocityConnection?
        
    private var _networks: C8yNetworks? = nil
    
	/**
	List of available network providers
	*/
	public var networks: C8yNetworks {
        get {
            
			if (self._networks == nil) {
                self._networks = C8yNetworks(self.connection)
            }
            
			return self._networks!
        }
    }
    
    public private(set) var groupCount: Int = 0
    public private(set) var deviceCount: Int = 0

	/**
	Default constructor, use from SwiftUI Views with the prefix @StateObject.
	You will need to call the `load(:c8yReferencesToLoad:includeSubGroups)` method to populate the collection
	
	#WARNING#
	Do not invoke the load() method from a SwiftUI View constructor as this will introduce severe performance issues, due to the
	fact the constructor can be called many times by SwiftUI. Instead invoke the method from the View's onAppear lifecycle event emitter
	to ensure that it will only be called once.
	*/
    public init() {
    }
    
    deinit {
       // self._cancellableLockQueue.async {
            for c in self._cancellableSet {
                c.cancel()
            }
       // }
    }
    
	/**
	Established a background thread to automatically refresh all of the assets in the collection i.e. detect
	changes made in Cumulocity automatically.
	
	- parameter interval: Interval in seconds
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened
	i.e. any assets found in sub group will be added to top level group and sub group references ignored.
	*/
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

	/**
	Disables background refresh thread
	Only applicable if the thread was started via `setRefresh(:includeSubGroups:)`
	*/
    public func stopRefresh() {
    
        self._refreshTimer?.suspend()
    }
    
	/**
	Force refresh the given asset, i.e. retrieve latest version from Cumulocity
	If the asset doesn't yet exist in the collection it will added after the fetch
	
	- parameter asset: device or group to be refreshed
	*/
    public func refreshAsset<T:C8yObject>(_ asset: T) {
            		
		if (self.groupFor(c8yId: asset.c8yId!) != nil) {
			_ = self.replaceObjectFor(asset)
		} else {
			// asset is not present, so assume we need to add it to favourites
			
			self._updateFavourites(asset)
		}
    }
    
	/**
	Force a refresh of all assets in the collection
	
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened
	- parameter completionHandler: Called once refresh has been completed
	*/
    public func doRefresh(includeSubGroups: Bool, completionHandler: @escaping () -> Void) {
        
        var groupCountDown = self.groupCount
        var deviceCountDown = self.deviceCount

        self._cancellableSet.removeAll()
        
        for e in self.objects {
            
            if (e.type == .C8yGroup) {
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
                                _ = self.remove(c8yId: group.c8yId!)
                            }
                        case .finished:
                            print("done")
                        }
                        
                        if (groupCountDown == 0) {
                            completionHandler()
                        }
                        
                    }, receiveValue: { (group) in
                        groupCountDown -= 1
                        self._updateFavourites(group)
                    }))
            } else {
                
                var device: C8yDevice = e.wrappedValue()
                
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(device.c8yId!)
                    .receive(on: RunLoop.main)
                    .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print(error)
                        if (error.httpCode == 404) {
                            // remove it from favourites
                            _ = self.remove(c8yId: device.c8yId!)
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
                            self._updateFavourites(device)
                        }
                    }))
                }))
                
                if (deviceCountDown == 0) {
                    completionHandler()
                }
            }
        }
    }
    
	/**
	Call this method to populate your collection with the required assets.
	You can add and remove assets afterwards using the methods `add(:)`, `addGroupReference(c8yId:includeSubgroups:)`  or `remove(c8yId:)`
	
	- parameter conn: Connection to be used to used to download assets with
	- parameter c8yReferencesToLoad: String array of c8y internal id's to be fetched, can refresent either devices or group
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened i.e. any sub-assets are added to top level group and sub group is ignored
	*/
    public func load(_ conn: C8yCumulocityConnection?, c8yReferencesToLoad: [String], includeSubGroups: Bool) throws -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
    
        self.connection = conn
    
        self.objects.removeAll()
        self.deviceCount = 0
        self.groupCount = 0

        return try self._load(c8yReferencesToLoad, includeSubGroups: includeSubGroups)
    }
    
	/**
	Similar to `load(:c8yReferencesToLoad:includeSubGroups)` call this method to repopulate your collection with the required assets.
	
	- parameter c8yReferencesToLoad: String array of c8y internal id's to be fetched, can refresent either devices or group
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened i.e. any sub-assets are added to top level group and sub group is ignored
	*/
    public func reload(_ c8yReferencesToLoad: [String], includeSubGroups: Bool) throws -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError>? {
            
        if (!_firstLoadCompleted) {
            return nil
        }
        
        self._cancellableSet.removeAll()
        
        for r in self.objects {
            if (!c8yReferencesToLoad.contains(r.c8yId!)) {
                _ = self.remove(c8yId: r.c8yId!)
            }
        }
        
        return try self._load(c8yReferencesToLoad, includeSubGroups: includeSubGroups)
    }
    
	/**
	Clears out the collection, all assets will be removed locally
	*/
    public func clear() {
    
        self.connection = nil
        self._cancellableSet.removeAll()
        self.objects.removeAll()
        self.deviceCount = 0
        self.groupCount = 0
    }
    
	/**
	Returns true if the given group is referenced in the collection at the top-level
	
	- parameter group: The group to be looked up
	- returns: true if the group is referenced
	*/
    public func isInCollection(_ group: C8yGroup) -> Bool {
        
        return self.isInCollection(group.c8yId!)
    }
    
	/**
	Returns true if an asset with the given id is referenced in the collection at the top-level
	
	- parameter c8yId: c8y internal id of the asset
	- returns: true if asset is referenced
	*/
    public func isInCollection(_ c8yId: String) -> Bool {
        
        return self.objects.contains { (o) -> Bool in
            return o.c8yId == c8yId
        }
    }

	/**
	Returns the group for the given id, or nil if not found.
	The group can be a sub-group of one of the referenced groups.
	
	*NOTE* - Only checks the local cache, if you want to look up devices in cumulocity use one of the `lookupGroup(c8yId:completionHandler:)` methods
	
	- parameter c8yId: c8y internal id of the group to be found.
	- returns: the group object or nil if not found
	*/
    public func groupFor(c8yId: String) -> C8yGroup? {
		
		var found: C8yGroup? = self._objectFor(c8yId, excludeDevices: true)
        
        if (found == nil) {
            // look in children
            
            for o in self.objects {
                
                if (o.type == .C8yGroup) {
                    let g: C8yGroup = o.wrappedValue()
                    
                    let object = g.parentOf(c8yId: c8yId)
                    
                    if (object != nil && object!.type == .C8yGroup) {
                        found = object!.wrappedValue()
                        break
                    }
                }
            }
        }
        
        return found
    }
    
	/**
	Returns the device for the given id, or nil if not found.
	The device can be in a sub-group somewhere of one of the referenced groups.
	
	*NOTE* - Only checks the local cache, if you want to look up devices in cumulocity use one of the `lookupDevice(c8yId:completionHandler:)` methods

	- parameter c8yId: c8y internal id of the device to be found.
	- returns: the device object or nil if not found
	*/
    public func deviceFor(_ ref: String) -> C8yDevice? {
    
        var found: C8yDevice? = self._objectFor(ref, excludeDevices: false)
        
        if (found == nil) {
            for o in self.objects {
                
                if (o.type == .C8yDevice) {
                    
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
                
                if (o.type == .C8yGroup) {
                    
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
    
	/**
	Returns the device for the given external id, or nil if not found.
	The device can be in a sub-group somewhere of one of the referenced groups.
	
	*NOTE* - Only checks the local cache, if you want to look up devices in cumulocity use one of the `lookupDevice(c8yId:completionHandler:)` methods
	
	- parameter externalId: externall id of the device to be found.
	- parameter ofType: code descrbing external id type e.g. 'c8y_Serial'
	- returns: the device object or nil if not found
	*/
    public func deviceFor(externalId: String, ofType type: String) -> C8yDevice? {
        
        var found: C8yDevice? = nil
        
        for o in self.objects {
            
            if (o.type == .C8yDevice) {
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
    
	/**
	Returns the asset for the given id, or nil if not found.
	The asset can be in a sub-group somewhere of one of the referenced groups.
	Currently two asset types are supported, namely devices or groups. In either
	case the returned object is contained in a `AnyCV8yObject` object.
	
	*NOTE* - Only checks the local cache, if you want to look up assets in cumulocity use one of the `lookupDevice(c8yId:completionHandler:)`  or `lookupGroup(c8yId:completionHandler:)`methods

	- parameter c8yId: c8y internal id of the asset to be found.
	- returns: the asset object or nil if not found
	*/
    public func objectFor(_ ref: String) -> (path: [String]?, object: AnyC8yObject?) {
    
        var found: AnyC8yObject? = nil
        var path: [String]? = nil
        
		print(">>>> objects count \(self.objects.count)")
		
        for o in self.objects {
            if o.c8yId == ref {
                found = o
                break
            }
        }
        
        if (found == nil) {
            
            // look in children
            
            for o in self.objects {
                
                if (o.type == .C8yGroup) {
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
	
	/**
	Replaces an existing asset with the given asset using the object c8y internal id.
	- parameter obj: The asset to be replaced
	- returns: If the asset is not found, no change is effected and false is returned.
	*/
	public func replaceObjectFor<T:C8yObject>(_ obj: T) -> Bool {
	
		var found: Bool = false
		
		var i: Int = 0
				
		for o in self.objects {
			if o.c8yId == obj.c8yId {
				self.objects[i] = AnyC8yObject(obj)
				found = true
				break
			}
			
			i = i + 1
		}
		
		if (!found) {
			
			// look in children
			
			i = 0
			
			for o in self.objects {
				
				if (o.type == .C8yGroup) {
					var g: C8yGroup = o.wrappedValue()
					
					if (g.replaceInGroup(obj)) {
						self.objects[i] = AnyC8yObject(g)
						found = true
					}
				}
				
				i = i + 1
			}
		}
		
		return found
	}
	
	/**
	Adds an asset to the collection
	*NOTE* - This has no impact on the back-end, assumption is that the asset already exists, otherwise use the `create(:completionHandler:)` method
	
	- parameter object: The asset to be added to the collection.
	*/
    public func add<T:C8yObject>(_ object: T) {
        
        self._updateFavourites(object)
    }
    
	/**
	Removes the asset from the local collection.
	*NOTE* - This has no impact on the back-end,  use the `delete(:completionHandler:)` method if you want to really delete the asset from cumulocity
	
	- parameter c8yId: the c8y internal id of the asset to removed from the local collection.
	*/
    public func remove(c8yId: String) -> Bool {
                 
        self._removeFromFavourites(c8yId)
    }
    
	/**
	Adds a group asset to the local collection using its c8y Internal id.
	Will call back end to fetch necessary dsata in order to create a new `C8yGroup` object before then inserting into the local collection.
	
	- parameter c8yId: the c8y internal id of the group to be added to the local collection.
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened i.e. any found sub-assets will be added to the top level group and sub group is ignored
	- parameter completionHandler: Called once fetch has completed, includes either group object if fetched successfully or the error description if it failed.
	*/
    public func addGroupReference(c8yId: String, includeSubGroups: Bool, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
        
        if (!self.isInCollection(c8yId)) {
                        
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
    
	/**
	Creates the new asset in Cumulocity and then adds it to the local collection if successful
	Creation might fail if connection access rights are insufficient or a mandatory attribute is missing.
	
	- parameter object: The cumulocity asset to be created and then referenced locally
	- parameter completionHandler: Called once insert has completed, includes either asset object if insert successful or the error description if it failed.
	- throws: Invalid object i.e. mandatory field missing
	*/
    public func create<T:C8yObject>(_ object: T, completionHandler: @escaping (T?, Error?) -> Void) throws {
           
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
    
	/**
	Saves any changes to the asset in Cumulocity
	
	- parameter object: The cumulocity asset to be created and then referenced locally
	- parameter completionHandler: Called once save has completed, returns a boolean indicating if save was successful.
	- throws: Invalid object i.e. mandatory field missing
	*/
	public func saveObject<T:C8yObject>(_ object: T, completionHandler: @escaping (Bool, Error?) -> Void) throws {
		  
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
			
			//self.refreshAsset(object)
							
			completionHandler(true, nil)
		}))
	}
	
	/**
	Deletes the existing asset from Cumulocity and then removed it from the local collection if necessary
	Deletion might fail if either the asset doesn't exist or connection access rights are insufficient
	
	- parameter object: The cumulocity asset to be deleted
	- parameter completionHandler: Called once delete has completed, returns true if delete was done, false if not
	*/
	public func delete<T:C8yObject>(_ object: T, completionHandler: @escaping (Bool) -> Void) {
		
		self._storeCancellable(
			C8yManagedObjectsService(self.connection!).delete(id: object.c8yId!)
				.receive(on: RunLoop.main)
				.sink(receiveCompletion: { (completion) in
					switch completion {
						case .failure(let error):
							print(error)
							completionHandler(false)
						case .finished:
							for o in self.objects {
								
								if (o.type == .C8yGroup) {
									var group: C8yGroup = o.wrappedValue()
									
									if (group.removeFromGroup(object.c8yId!)) {
										self._updateFavourites(group)
									}
								} else if (o.c8yId == object.c8yId) {
									_ = self._removeFromFavourites(object.c8yId!)
								}
							}
					}
				}, receiveValue: { (response) in
					// nothing doing here I think
					
				}))
	}
	
	/**
	Convenience method that allows a new device or group to be created and then added to an existing group or sub-group. Following which, it then ensures that the local collection is updated
	to reflect any changes.
	
	- parameter object: The asset to be created in Cumulocity
	- parameter c8yOfGroup: The group to which it should be assigned once the object has been created.
	- parameter completinoHandler: Called when operation has been completed to indicate success or failure
	- throws: Invalid object i.e. mandatory field missing
	*/
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
   
	/**
	Convenience method that allows an existing device or group to be added to an existing group or sub-group. Following which, it then ensures that the local collection is updated
	to reflect any changes.
	
	- parameter object: The asset to be created in Cumulocity
	- parameter c8yOfGroup: The group to which it should be assigned once the object has been created.
	- parameter completinoHandler: Called when operation has been completed to indicate success or failure
	*/
	public func assignToGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, completionHandler: @escaping (T?, Error?) -> Void) {
		self._assignToGroup(object.c8yId!, c8yOfGroup: c8yOfGroup) { success, error in
				
			for o in self.objects {
				
				if (o.type == .C8yGroup) {
					var group: C8yGroup = o.wrappedValue()
					
					if (group.addToGroup(c8yIdOfSubGroup: group.c8yId!, object: object)) {
						self._updateFavourites(group)
					}
				}
			}

			completionHandler(object, nil)
		}
	}
	
	/**
	Returns the group for the given  c8y internal id, or nil if not found. It first checks in the local cache and if not found queries the back-end cumulocity tenant
	The group is NOT added to the local collection if not found locally.
	
	- parameter c8yId: c8y internal id of the group to be found.
	- parameter completionHandler: callback that received the fetched group or error if failed
	*/
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
	
	/**
	Returns the device for the given c8y internal id, or nil if not found. It first checks in the local cache and if not found queries the back-end cumulocity tenant
	The device is NOT added to the local collection if not found locally.
	
	- parameter c8yId: c8y internal id of the device to be found.
	- parameter completionHandler: callback that received the fetched device or error if failed
	*/
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
				
				self.fetchExternalIds(device.c8yId!) { success, externalIds in
				
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
	
	/**
	Returns the device for the given external id and type, or nil if not found. It first checks in the local cache and if not found queries the back-end cumulocity tenant
	The device is NOT added to the local collection if not found locally.
	
	- parameter id: external id of the device to be found.
	- parameter ofType: code descrbing external id type e.g. 'c8y_Serial'
	- parameter completionHandler: callback that received the fetched device or error if failed
	*/
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
				self.fetchExternalIds(device.c8yId!) { success, externalIds in
				
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

	/**
	Returns the group for the given external id and type, or nil if not found. It first checks in the local cache and if not found queries the back-end cumulocity tenant
	The group is NOT added to the local collection if not found locally.
	
	- parameter id: external id of the group to be found.
	- parameter ofType: code descrbing external id type e.g. 'c8y_Serial'
	- parameter completionHandler: callback that received the fetched group or error if failed
	*/
	public func lookupGroup(forExternalId id: String, type: String, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
		
		var found: C8yGroup? = nil
		
		for o in self.objects {
	
			if (o.type == .C8yGroup) {
				let g: C8yGroup = o.wrappedValue()
				
				if (g.match(forExternalId: id, type: type)) {
					found = g
					break
				}
			}
		}
		
		if (found == nil) {
			
			for o in self.objects {

				if (o.type == .C8yGroup) {
				
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
	
    private func _postAdd<T:C8yObject>(_ object: T,response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (T?, Error?) -> Void) {
        
        var newObject = object
        newObject.setC8yId(response.content!.id!)
                                           
        self._updateFavourites(newObject)
           
        completionHandler(newObject, nil)
    }
    
    private func _postAddToGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (T?, Error?) -> Void) {
        
       var newObject = object
            
        newObject.setC8yId(response.content!.id!)
        self.assignToGroup(newObject, c8yOfGroup: c8yOfGroup, completionHandler: completionHandler)
    }
    
    private func _postLookupGroup(_ response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (C8yGroup?, Error?) -> Void) {
     
        var group = C8yGroup(response.content!)
        self.fetchExternalIds(group.c8yId!) { success, externalIds in
            
            if (success) {
                group.setExternalIds(externalIds)
            }
        }
        completionHandler(group, nil)
    }
    
    private func _assignToGroup(_ c8yId: String, c8yOfGroup: String, completionHandler: @escaping (Bool, Error?) -> Void) {
            
		self._storeCancellable(C8yManagedObjectsService(self.connection!).assignToGroup(child: c8yId, parentId: c8yOfGroup)
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
                        
            for c8yId in c8yReferencesToLoad {
                
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(c8yId).sink(receiveCompletion: { completion in
                    if (c8yId == c8yReferencesToLoad.last) {
                        self._firstLoadCompleted = true
                        p.send(completion: .finished)
                    }
                    switch completion {
                    case .failure(let error):
                        print(error)
                    case .finished:
                        print("not yet")
                    }
				}, receiveValue: { response in
					
					if (response.status == .SUCCESS) {
						if (response.content!.isDevice) {
							var newDevice = C8yDevice(response.content!)
							self._storeCancellable(C8yManagedObjectsService(self.connection!).externalIDsForManagedObject(response.content!.id!)
													.receive(on: RunLoop.main)
													.sink(receiveCompletion: { completion in
														self._updateFavourites(newDevice)
													}, receiveValue: { exts in
														if (exts.content != nil) {
															newDevice.setExternalIds(exts.content!.externalIds)
														}
													}))
						} else {
							self._addGroup(C8yGroup(response.content!, parentGroupName: nil), includeSubGroups: includeSubGroups)
						}
					}
					
					p.send(self.objects)
				}))
            }
        }
        
        return p.eraseToAnyPublisher()
    }
    
    private func addManagedObjectAsGroup(_ m: C8yManagedObject, includeSubGroups: Bool) -> C8yGroup {
        
        let newGroup = C8yGroup(m, parentGroupName: nil)
        
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
                        
        self._storeCancellable(GroupLoader(group.wrappedManagedObject, conn: self.connection!, path: nil, includeGroups: includeSubGroups).load()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
				print("** Group loader for \(String(describing: group.c8yId)) failed: \(error)")
                self._lastLoadError = error
            case .finished:
				print("** Group loader for \(String(describing: group.c8yId)) - \(group.name) done")
            }
        }, receiveValue: { (newGroup) in            
            self._updateFavourites(newGroup)
        }))
    }
    
    private func _updateFavourites<T:C8yObject>(_ object: T) {
        
        self._objectsLockQueue.sync {
            
            if (object is C8yGroup) {
                
                let newGroup: AnyC8yObject = AnyC8yObject(object)
                let existingObject: C8yGroup? = self._objectFor(object.c8yId!, excludeDevices: true)
                
                if (existingObject == nil) {
                                        
                    self.objects.insert(newGroup, at: 0)
                } else {
                    // replace
                    
                    for i in self.objects.indices {
                        if (self.objects[i].c8yId == newGroup.c8yId) {
                                                        
                            self.objects[i] = newGroup
                            break
                        }
                    }
                }
            } else if (object is C8yDevice) {
                
				// add or replace divice
				
                let existingObject: C8yDevice? = self._objectFor(object.c8yId!, excludeDevices: false)
                
                if (existingObject == nil) {
                    
                    let newDevice: AnyC8yObject = AnyC8yObject(object)
                    self.objects.append(newDevice)
					
                } else {
                    
                    // replace existing
                    
                    for i in self.objects.indices {
                        if (self.objects[i].c8yId == object.c8yId) {
                                                        
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
    
	private func fetchExternalIds(_ c8yId: String, completionHandler: @escaping (Bool, [C8yExternalId]) -> Void) {
		
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
	
    private func makeError(_ message: String) -> Error {
            
        return C8yDeviceUpdateError.reason(message)
    }
    
    private func makeError<T>(_ response: JcRequestResponse<T>) -> Error? {

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
            if (o.c8yId == c8yId && (o.type == .C8yGroup || !excludeDevices)) {
                found = o.wrappedValue()
                break
            }
        }
        
        return found
    }
}
