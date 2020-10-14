# README #

Client library (iOS 13.0+ or MacOS 10.15+) for accessing your Cumulocity IoT tenant from your own iPhone or Mac apps.

Refer to the [Cumulocity Home Page](https://www.softwareag.cloud/site/product/cumulocity-iot.html) to sign up for your own Cumulocity tenant if you do not already have one.

This library uses the [c8y REST API](https://cumulocity.com/guides/reference/rest-implementation/) in order to communicate with your tenant and you will need a login with appropriate permissions to allow access.

You will need a Mac (ideally running 10.15) and up to date version of xCode 11.0 to use this library and integrate with your apps.

Install the library direct from [github]() or as a swift package in a xcode project that you have already created.

Using Xcode 11 go to File > Swift Packages > Add Package Dependency
Paste the project URL: https://github.com/johnpcarter/c8y-ios-lib
Click on next and select the project target, choose latest branch

Now you can import your dependencies e.g.
```
import Combine
import Cumulocity_Client_Library
```

## Connectivity and basic usage ##

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
the connect method is only useful to verify the credentials and also gather information about the user `C8yUserProfile`. Each call via the Service classes reconnects via the connection
credentials and stateless.

## SDK Documentation ##

Full documentation can be viewed [here](https://raw.githack.com/johnpcarter/c8y-ios-lib/master/docs/out/index.html)