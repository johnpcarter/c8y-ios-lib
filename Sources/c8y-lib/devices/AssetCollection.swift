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
        
	@Published public internal(set) var isLoading: Bool = false
	
	/**
	Objects that published from this collection. Devices and Groups are wrapped in an `AnyC8yObject` instance to avoid collection
	ambiguity errors.
	*/
    @Published public var objects: [AnyC8yObject] = []

	@Published var mutableDevices: [String:C8yMutableDevice] = [:]

	public var deviceModels: C8yDeviceModels? = nil
	
	public var title: String = "Favourites"
	public var subTitle: String = ""

	public var parent: AnyC8yObject? = nil
	
    private let _objectsLockQueue = DispatchQueue(label: "c8y.objects.lock.queue")

    private var _refreshTimer: JcRepeatingTimer? = nil
    private var _reload: Bool = false
    private var _firstLoadCompleted: Bool = false
    private var _lastLoadError: Error? = nil
    private var _cancellableSet: Set<AnyCancellable> = []
    private let _cancellableLockQueue = DispatchQueue(label: "cancellable.lock.queue")
	private var _favourites: [String]? = nil
	
	/**
	The connection reference that was last used to load the collection via `load(_:c8yReferencesToLoad:includeSubGroups:)`
	*/
    public internal(set) var connection: C8yCumulocityConnection?

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
	Returns a new asset collection representing the child elements
	*/
	public func assetCollection(for c8yIdOfObject: String) -> C8yAssetCollection {
	
		let ref = self.objectFor(c8yIdOfObject)
		
		if (ref.object == nil) {
			return self
		} else {
			let assetCollection = C8yAssetCollection()
			assetCollection.connection = self.connection
			assetCollection.deviceModels = self.deviceModels
			assetCollection.parent = ref.object!
			assetCollection.objects = ref.object!.children
			
			assetCollection.updateTitle()
			
			return assetCollection
		}
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
						self.reload(includeSubGroups: includeSubGroups)
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
	Call this method to populate your collection with the required assets.
	You can add and remove assets afterwards using the methods `add(:)`, `addGroupReference(c8yId:includeSubgroups:)`  or `remove(c8yId:)`
	
	- parameter favourites: String array of c8y internal id's to be fetched, can refresent either devices or group
	- parameter conn: Connection to be used to used to download assets with
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened i.e. any sub-assets are added to top level group and sub group is ignored
	*/
	public func load(favourites: [String], conn: C8yCumulocityConnection?, includeSubGroups: Bool) throws -> AnyPublisher<Bool, Error> {
    
        self.connection = conn
    
        self.objects.removeAll()
		self._favourites = favourites
		self.parent = nil
		
		return try self._load(favourites, includeSubGroups: includeSubGroups)
			.map { results -> Bool in
				if (results.count > 0) {
					return true
				} else {
					return false
				}
		}.mapError { error -> Error in
			return error
		}.eraseToAnyPublisher()
    }
    
	/**
	Call this method to populate your collection with the required assets.
	You can add and remove assets afterwards using the methods `add(:)`, `addGroupReference(c8yId:includeSubgroups:)`  or `remove(c8yId:)`
	
	- parameter c8yOfParent: c8y internal id of asset to be loaded
	- parameter conn: Connection to be used to used to download assets with
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened i.e. any sub-assets are added to top level group and sub group is ignored
	*/
	public func load(c8yOfParent: String, conn: C8yCumulocityConnection?, includeSubGroups: Bool) {
	
		self.connection = conn
	
		self.objects.removeAll()
		self._favourites = nil
		self.isLoading = true
		
		C8yManagedObjectsService(self.connection!).get(c8yOfParent)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
			
				self.isLoading = false
				
		}, receiveValue: { object in
					
			guard object.content != nil else {
				return
			}
			
			do {
				if (object.content!.isDevice) {
					let d = try C8yDevice(object.content!)
					
					self.loadChildAssets(for: d) { updatedDevice in
							
						self.parent = AnyC8yObject(updatedDevice)
							
						updatedDevice.children.forEach { a in
							self._updateFavourites(a)
						}
					}
					
					self.parent = AnyC8yObject(d)
				} else {
					let g = try C8yGroup(object.content!)
					
					self.loadChildAssets(for: g) { updatedGroup in
							
						self.parent = AnyC8yObject(updatedGroup)
							
						updatedGroup.children.forEach { a in
							self._updateFavourites(a)
						}
					}
					
					self.parent = AnyC8yObject(g)
				}
			} catch {
				// TODO: what to do in error
				
			}
		}))
	}
	
	/**
	Force a refresh of all assets in the collection
	
	- parameter includeSubGroups: if true, sub groups are treated as unique entities, if false all subgroups are flattened
	- parameter completionHandler: Called once refresh has been completed
	*/
	public func reload(favourites: [String]? = nil, includeSubGroups: Bool) {

		if (favourites != nil) {
			self._favourites = favourites
		}
		
		if (self._favourites != nil) {
			do { try self.load(favourites: self._favourites!, conn: self.connection, includeSubGroups: includeSubGroups).subscribe(Subscribers.Sink(receiveCompletion: { completion in
				
			}, receiveValue: { results in
				
			}))
			} catch {
				// TODO
			}
		} else {
			self.load(c8yOfParent: self.parent!.c8yId!, conn: self.connection, includeSubGroups: includeSubGroups)
		}
	}
	
	/**
	Force refresh the given asset, i.e. retrieve latest version from Cumulocity
	If the asset doesn't yet exist in the collection it will be added after the fetch
	
	- parameter asset: device or group to be refreshed
	*/
	public func refreshAsset<T:C8yObject>(_ asset: T) {
					
		if (self.objectFor(asset.c8yId!).object != nil) {
			_ = self.replaceObjectFor(asset)
		} else {
			// asset is not present, so assume we need to add it to favourites
			
			self._updateFavourites(asset)
		}
	}
	
	/**
	Clears out the collection, all assets will be removed locally
	*/
    public func clear() {
    
		if (self._refreshTimer != nil) {
			self._refreshTimer!.suspend()
			self._refreshTimer = nil
		}
        self.connection = nil
        self._cancellableSet.removeAll()
        self.objects.removeAll()
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
		
		let found = self.objectFor(c8yId)
		
		if (found.object != nil && found.object!.type == .C8yGroup) {
			return found.object?.wrappedValue()
		} else {
			return nil
		}
    }
	
	/**
	Returns the first group with a name that contains the given fragment or nil if not found.
	The group can be a sub-group of one of the referenced groups.
	
	*NOTE* - Only checks the local cache, if you want to look up devices in cumulocity use one of the `lookupGroup(c8yId:completionHandler:)` methods
	
	- parameter name: name fragment
	- returns: the group object or nil if not found
	*/
	public func groupFor(name: String) -> C8yGroup? {
		
		var found: C8yGroup? = nil
		
		for o in self.objects {
				
			if (o.type == .C8yGroup) {
				
				if (o.name.contains(name)) {
					found = o.wrappedValue()
					break
				} else {
					let g: C8yGroup = o.wrappedValue()
					let fg = g.group(ref: name)
					
					if (fg != nil) {
						found = fg
						break
					}
				}
			}
		}
		
		return found
	}
    
	public func mutableDevice(for device: C8yDevice) -> C8yMutableDevice {
		
		var m = self.mutableDevices[device.c8yId!]
		
		if (m == nil) {
			m = C8yMutableDevice(device, connection: self.connection!, deviceModels: self.deviceModels)
			
			self.mutableDevices[device.c8yId!] = m
		}
		
		return m!
	}
	
	/**
	Returns the device for the given id, or nil if not found.
	The device can be in a sub-group somewhere of one of the referenced groups.
	
	*NOTE* - Only checks the local cache, if you want to look up devices in cumulocity use one of the `lookupDevice(c8yId:completionHandler:)` methods

	- parameter c8yId: c8y internal id of the device to be found.
	- returns: the device object or nil if not found
	*/
    public func deviceFor(_ ref: String) -> C8yDevice? {
    
		let found = self.objectFor(ref)
        
		return found.object?.wrappedValue()
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
            }
			
			for c in o.children {
			
				found = c.deviceFor(externalId: externalId, externalIdType: type)
				
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
                
				let child = o.objectFor(ref)
				
				if (child.object != nil) {
					found = child.object
					path = child.path
					break
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
		
		// look in children
		
		i = 0
		
		for o in self.objects {
			
			var copy = o
			
			if (copy.replaceChild(obj)) {
				self.objects[i] = copy
				found = true
			}
			
			i = i + 1
		}
		
		if (obj is C8yDevice && self.mutableDevices[obj.c8yId!] != nil) {
			let d: C8yDevice = obj as! C8yDevice
			
			self.mutableDevices[obj.c8yId!] = C8yMutableDevice(d, connection: self.connection!, deviceModels: self.deviceModels)
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
	Removes the asset with the given id it from the local collection regardles of where it is in
	the hireachy of groups.
	
	*NOTE* - This has no impact on the back-end,  use the `delete(:completionHandler:)` method if you want to really delete the asset from cumulocity

	- parameter c8yId: c8y internal id for object to be deleted
	- returns true if asset was found and removed, false if not
	*/
	public func remove(c8yId: String) -> Bool {
		
		var found: Bool = false
		
		for o in self.objects {
			
			var copy = o
			
			if (o.c8yId == c8yId) {
				_ = self._removeFromFavourites(c8yId)
				found = true
			} else if (copy.removeChild(c8yId)) {
				self._updateFavourites(copy)
				found = true;
			}
		}
		
		return found
	}
    
	/**
	Fetches the group asset from c8y and adds it to the local collection.
	
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
					if (error.httpCode == 409) {
						
					} else {
						completionHandler(nil, error)
					}
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
	NOTE: Will NOT update any changed external id's, use the `register(externalId:ofType:forId:)` method to  register or replace an existing external id
	
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
	
	- parameter c8yId: c8y internal id for object to be deleted
	- parameter completionHandler: Called once delete has completed, returns true if delete was done, false if not
	*/
	public func delete(c8yId: String, completionHandler: ((Bool) -> Void)? = nil) {
		
		self._storeCancellable(
			C8yManagedObjectsService(self.connection!).delete(id: c8yId)
				.receive(on: RunLoop.main)
				.sink(receiveCompletion: { (completion) in
					var didDelete: Bool = false
					
					switch completion {
						case .failure:
							didDelete = false
						case .finished:
							didDelete = true
					}
					
					for o in self.objects {
						
						var copy = o
						 
						if (o.c8yId == c8yId) {
							_ = self._removeFromFavourites(c8yId)
						} else if (copy.removeChild(c8yId)) {
							self._updateFavourites(copy)
						}
					}
					
					if (completionHandler != nil) {
						completionHandler!(didDelete)
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
	public func createInGroup<T:C8yObject>(_ object: T, c8yOfGroup: String, completionHandler: @escaping (T?, Error?) -> Void) throws {
		   
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
										
					if (group.addToGroup(c8yIdOfSubGroup: c8yOfGroup, object: object)) {
						
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
				do {
					completionHandler(try C8yGroup(response.content!), nil)
				} catch {
					completionHandler(nil, error)
				}
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
				
				do {
					var device = try C8yDevice(response.content!)
				
					self.fetchExternalIds(device.c8yId!) { success, externalIds in
				
						if (success) {
							device.setExternalIds(externalIds)
						}
					
						completionHandler(device, nil)
					}
				} catch {
					completionHandler(nil, error)
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
	- parameter type: code descrbing external id type e.g. 'c8y_Serial'
	- parameter completionHandler: callback that receives the fetched device, nil if not found or error if failed
	*/
	public func lookupDevice(forExternalId id: String, type: String, completionHandler: @escaping (Result<C8yDevice, Error>) -> Void) {
		
		let found: C8yDevice? = self.deviceFor(externalId: id, ofType: type)
		
		if (found == nil) {
			
			// still no luck, lookup in c8y directly
			
			if (type == C8Y_INTERNAL_ID) {
				self._storeCancellable(C8yManagedObjectsService(self.connection!).get(id)
										.receive(on: RunLoop.main)
										.sink(receiveCompletion: { completion in
											switch completion {
												case .failure(let error):
													completionHandler(.failure(error))
												case .finished:
													print("done")
											}
										}, receiveValue: { (response) in
											do {
												var device = try C8yDevice(response.content!)
												self.fetchExternalIds(device.c8yId!) { success, externalIds in
													
													if (success) {
														device.setExternalIds(externalIds)
													}
													
													completionHandler(.success(device))
												}
											} catch {
												completionHandler(.failure(error))
											}
										}))
			} else {
				
				self._storeCancellable(C8yManagedObjectsService(self.connection!).get(forExternalId: id, ofType: type)
										.receive(on: RunLoop.main)
										.sink(receiveCompletion: { completion in
											switch completion {
												case .failure(let error):
													completionHandler(.failure(error))
												case .finished:
													print("done")
											}
										}, receiveValue: { (response) in
											do {
												var device = try C8yDevice(response.content!)
												self.fetchExternalIds(device.c8yId!) { success, externalIds in
													
													if (success) {
														device.setExternalIds(externalIds)
													}
													
													completionHandler(.success(device))
												}
											} catch {
												completionHandler(.failure(error))
											}
										}))
			}
		} else {
			completionHandler(.success(found!))
		}
	}

	/**
	Returns the group for the given external id and type, or nil if not found. It first checks in the local cache and if not found queries the back-end cumulocity tenant
	The group is NOT added to the local collection if not found locally.
	
	- parameter id: external id of the group to be found.
	- parameter ofType: code descrbing external id type e.g. 'c8y_Serial'
	- parameter completionHandler: callback that receives the fetched group, nil if not found or error if failed
	*/
	public func lookupGroup(forExternalId id: String, type: String, completionHandler: @escaping (Result<C8yGroup, Error>) -> Void) {
		
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

			if (type == C8Y_INTERNAL_ID) {
				self._storeCancellable(C8yManagedObjectsService(self.connection!).get(id)
					.receive(on: RunLoop.main)
					.sink(receiveCompletion: { completion in
					switch completion {
					case .failure(let error):
						print(error)
						completionHandler(.failure(error))
					case .finished:
						print("done")
					}
				}, receiveValue: { response in
					self._postLookupGroup(response, completionHandler: completionHandler)
				}))
			} else {
				self._storeCancellable(C8yManagedObjectsService(self.connection!).get(forExternalId: id, ofType: type)
					.receive(on: RunLoop.main)
					.sink(receiveCompletion: { (completion) in
					switch completion {
					case .failure(let error):
						completionHandler(.failure(error))
					case .finished:
						print("done")
					}
				}, receiveValue: { (response) in
					self._postLookupGroup(response, completionHandler: completionHandler)

				}))
			}
		} else {
			completionHandler(.success(found!))
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
    
    private func _postLookupGroup(_ response: JcRequestResponse<C8yManagedObject>, completionHandler: @escaping (Result<C8yGroup, Error>) -> Void) {
     
		do {
			var group = try C8yGroup(response.content!)
			self.fetchExternalIds(group.c8yId!) { success, externalIds in
				
				if (success) {
					group.setExternalIds(externalIds)
				}
			}
			completionHandler(.success(group))
		} catch {
			completionHandler(.failure(error))
		}
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

		self.isLoading = true
		
        if (c8yReferencesToLoad.count == 0) {
            
            DispatchQueue.main.async {
				self._firstLoadCompleted = true
				self.isLoading = false
				
                p.send(completion: .finished)
            }
            
            return p.eraseToAnyPublisher()
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
                        
            for c8yId in c8yReferencesToLoad {
                
                self._storeCancellable(C8yManagedObjectsService(self.connection!).get(c8yId)
										.receive(on: RunLoop.main)
										.sink(receiveCompletion: { completion in
                   
					if (c8yId == c8yReferencesToLoad.last) {
                        self._firstLoadCompleted = true
						self.isLoading = false
						
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
							
							self._addDevice(response.content!)
							
						} else {
							self._addGroup(C8yGroup(response.content!, parentGroupName: nil), includeSubGroups: includeSubGroups)
						}
					} else {
						// now't
						print("now't")
					}
					
					p.send(self.objects)
				}))
            }
        }
        
        return p.eraseToAnyPublisher()
    }
	
	private func _addDevice(_ object: C8yManagedObject) {
			
		let d: C8yDevice = try! C8yDevice(object)
		
		self._updateFavourites(d)

		self.loadChildAssets(for: d) { updateDeviceWithChildren in
			self._updateFavourites(updateDeviceWithChildren)
		}
		
		/*self.externalIdsForDevice(try! C8yDevice(object)) { updatedDevice, completion in
						
			self._updateFavourites(updatedDevice)

			self.loadChildAssets(for: updatedDevice) { updateDeviceWithChildren in
				self._updateFavourites(updateDeviceWithChildren)
			}
		}*/
	}
    
	private func externalIdsForDevice(_ device: C8yDevice, completionHandler: @escaping (C8yDevice, Subscribers.Completion<JcConnectionRequest<C8yCumulocityConnection>.APIError>) -> Void) {
	
		var updatedDevice: C8yDevice = device
		
		C8yManagedObjectsService(self.connection!).externalIDsForManagedObject(device.wrappedManagedObject.id!)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
		  
			completionHandler(updatedDevice, completion)
			
		}, receiveValue: { response in
			updatedDevice.setExternalIds(response.content!.externalIds)
		}))
	}
	
	private func loadChildAssets<T:C8yObject>(for object: T, completionHandler: @escaping (T) -> Void) {
	
		var updatedObject = object
		
		var assets: [C8yManagedObject.ChildReferences.ReferencedObject] = []
		
		if (object.wrappedManagedObject.childDevices != nil && object.wrappedManagedObject.childAssets != nil) {
			assets = (object.wrappedManagedObject.childDevices!.references! + object.wrappedManagedObject.childAssets!.references!)

		} else if (object.wrappedManagedObject.childAssets != nil) {
			assets = object.wrappedManagedObject.childAssets!.references ?? []
		} else {
			assets = object.wrappedManagedObject.childDevices!.references ?? []
		}
		
		assets.forEach({ c in
			
			self.processChildAsset(c) { obj in
				
				updatedObject.children.append(obj)
				
				if (c.id == assets.last?.id) {
					completionHandler(updatedObject)
				}
			}
		})
	}
	
	private func processChildAsset(_ c: C8yManagedObject.ChildReferences.ReferencedObject, completionHandler: @escaping (AnyC8yObject) -> Void) {
		
		C8yManagedObjectsService(self.connection!).get(c.ref!.lastToken("/"))
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				
				// do nothing
				
			}, receiveValue: { value in
				
				if (value.content != nil) {
					
					do {
						if (value.content!.isGroup) {
														
							self.loadChildAssets(for: try C8yGroup(value.content!)) { updatedGroup in
								completionHandler(AnyC8yObject(updatedGroup))
							}
						} else {
							
							self.externalIdsForDevice(try C8yDevice(value.content!)) { updatedDevice, completion in
								var copy = updatedDevice
								copy.isChildDevice = true
								
								completionHandler(AnyC8yObject(copy))
							}
						}
					} catch {
						// ignore
					}
				}
			}))
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
                        
        self._storeCancellable(GroupLoader(group, conn: self.connection!, path: nil, includeGroups: includeSubGroups).load()
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
		return self._updateFavourites(AnyC8yObject(object))
	}
	
    private func _updateFavourites(_ object: AnyC8yObject) {
        
        self._objectsLockQueue.sync {
            
			if (object.type == .C8yGroup) {
                
                let existingObject: C8yGroup? = self._objectFor(object.c8yId!, excludeDevices: true)
				self._updateFavourites(existingObject, with: object)
               
			} else if (object.type == .C8yDevice) {
                
				// add or replace divice
				
                let existingObject: C8yDevice? = self._objectFor(object.c8yId!, excludeDevices: false)
				self._updateFavourites(existingObject, with: object)
            }
        }
    }
    
	private func _updateFavourites<T:C8yObject>(_ existingObject: T?, with object: AnyC8yObject) {
	
		if (existingObject == nil) {
								
			self.objects.insert(object, at: 0)
		} else {
			// replace
			
			for i in self.objects.indices {
				if (self.objects[i].c8yId == object.c8yId) {
												
					self.objects[i] = object
					break
				}
			}
			
			if (object.type == .C8yDevice && self.mutableDevices[object.c8yId!] != nil) {
				let d: C8yDevice = object.wrappedValue()
				
				self.mutableDevices[object.c8yId!] = C8yMutableDevice(d, connection: self.connection!, deviceModels: self.deviceModels)
			}
		}
		
		self.updateTitle()
	}
	
    private func _removeFromFavourites(_ c8yId: String) -> Bool {
    
        var found: Bool = false
        
        self._objectsLockQueue.sync {
            for i in self.objects.indices {
                
                if (self.objects[i].c8yId == c8yId) {
                    self.objects.remove(at: i)
                    found = true
					self.updateTitle()
                    break
                }
            }
        }
        
        return found
    }
    
	private func updateTitle() {
		
		if (parent != nil && parent!.type == .C8yDevice) {
			
			let d: C8yDevice = self.parent!.wrappedValue()
			self.title = d.name
			
			if (d.hasChildren) {
				
				let deviceCount = d.children.count
				let onlineCount = d.onlineCount
				
				self.subTitle = "is \(d.status.rawValue.lowercased()), and \(onlineCount) of \(deviceCount) devices available, \(d.alarmsCount) alarm\(d.alarmsCount == 1 ? "" : "s")"
			} else {
				self.subTitle = "is \(d.status.rawValue.lowercased()), \(d.alarmsCount) alarm\(d.alarmsCount == 1 ? "" : "s")"
			}
		} else {
			
			var deviceCount = 0
			var alarmsCount = 0
			var onlineCount = 0
			
			if (parent != nil && parent!.type == .C8yGroup) {
				
				let g: C8yGroup = parent!.wrappedValue()
				
				deviceCount = g.deviceCount
				onlineCount = g.onlineCount
				alarmsCount = g.alarmsCount
				
				self.title = g.name
			} else {
				
				//TODO: exclude favourites if referenced elsewhere
				
				self.objects.forEach { o in
					if (o.type == .C8yGroup) {
						let g: C8yGroup = o.wrappedValue()
						
						deviceCount += g.deviceCount
						alarmsCount += g.alarmsCount
						onlineCount += g.onlineCount
					} else {
						
						let d: C8yDevice = o.wrappedValue()
						
						deviceCount += d.children.count > 0 ? d.children.count : 1
						onlineCount += d.onlineCount
						alarmsCount += d.alarmsCount
						
						if (d.operationalLevel == .nominal || d.operationalLevel == .operating || d.operationalLevel == .error || d.operationalLevel == .failing) {
							onlineCount += 1
						}
					}
				}

				self.title = "Favourites"
			}

			if (deviceCount > 1) {
				self.subTitle = "\(onlineCount) of \(deviceCount) devices available"
			} else if (deviceCount == 1) {
				if (onlineCount == 0) {
					self.subTitle = "One unavailable device"
				} else {
					self.subTitle = "One connected device"
				}
			} else {
				self.subTitle = "No devices"
			}
			
			self.subTitle = self.subTitle + ", \(alarmsCount == 0 ? "no" : "\(alarmsCount)") alarm\(alarmsCount == 0 || alarmsCount > 1 ? "s" : "")"
		}
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
