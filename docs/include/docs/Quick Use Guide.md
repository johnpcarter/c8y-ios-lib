# Quick Use Guide #

First refer to 'Installation Section' in order to download and install the library

You will need to add the following imports to use the library from each of your swift files
that need to reference the library or any of its assets.

```
import Combine
import Cumulocity_Client_Library
```

The Combine import is required because the API's use the swift framework Combine, refer to [Combine Framework](https://developer.apple.com/documentation/combine) for more information about using Combine.

# Connectivity and basic usage #

You first need to create a Connection object and then one of the API Service classes to interact with you Cumulocity tenant, e.g.

```
let conn: C8yCumulocityConnection = C8yCumulocityConnection(tenant: "<mytenant>", server: "cumulocity.com")

        conn.connect(user: "john", password: "appleseed").sink(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    print("Connection refused! - \(error.localizedDescription)")
                default:
                    print("Connection Success")
                    
                    // Now that we have tested the connections, lets fetch some managed objects
                    
                    C8yManagedObjectsService(conn).get(pageNum: 0).sink(receiveCompletion: { (completion) in
                    
                        switch completion {
                        case .failure(let error):
                            print("Get Failed \(error.localizedDescription)")
                        default:
                            print("Get Completed")
                        }
                        
                    }, receiveValue: { results in
                    
                        if (results.status == .SUCCESS) {
                    
                            print("page \(results.content!.statistics.currentPage) of \(results.content!.statistics.totalPages!), size \(results.content!.statistics.pageSize)")
                    
                            for object in results.content!.objects {
                                    print("\(String(describing: object.id))")
                            }
                        }
                    }).store(in: &self._cancellableSet)
                }
        }, receiveValue: ({ userInfo in
            
            print("User name is \(userInfo)")
            
        })).store(in: &self._cancellableSet)
```

The above first verifies the connection and uses the `C8yManagedObjectsService` class to fetch a page of `C8yManagedObject` objects. The connection object does not carry state and
the connect method is only useful to verify the credentials and also gather information about the user `C8yUserProfile`. Each call via the Service classes reconnects via the connection credentials and is stateless.

Refer to the official [c8y Documentation](https://cumulocity.com/guides/about-doc/intro-documentation/) to better grips to the IoT and c8y concepts.

# High Level Access for Device & Groups #

A `High Level Access` is provided to allow you to quickly access your devices and groups and avoid a lot of the cruft you would have to develop in your own classes to manage them.
In addition these high level classes are SwiftUI compatible i.e. the class objects in most cases implement the ObservableObject protocol and hence their attributes can be referenced
directly from your SwiftUI Views. Your views will automatically update if any of the attributes change.

For instance you can use the `C8yAssetCollection` class to manage a collection of groups or devices locally
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