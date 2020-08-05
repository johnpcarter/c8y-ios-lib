# Quick Use Guide #

First refer to 'Installation Section' in order to download and install the library


Make sure to always open the Xcode workspace instead of the project file when building your project:

```
$ open App.xcworkspace
```

Now you can import your dependencies e.g.:
```
#import <Cumulocity_Client_Library/Cumulocity_Client_Library.h>
```

From there you can start to use the library from you classes, to fetch managed objects from your tenant e.g.

```
let _conn: JcCumulocityConnection = JcCumulocityConnection(tenant: "<mytenant>", server: "cumulocity.com")

_ = _conn.connect(user: "john", password: "appleseed") { (response: JcRequestResponse<JcCumulocityUser>) in
                
    if (response.status == .SUCCESS) {
    	
    	_ = JcManagedObjectsService(_conn).get(pageNum: 0) { (response) in
        
            result = response
            
            if (response.status == .SUCCESS) {
                
                print("page \(response.content!.statistics.currentPage) of \(response.content!.statistics.totalPages), size \(response.content!.statistics.pageSize)")
                
                for object in response.content!.objects {
                    print("\(String(describing: object.id))")
                }
            }
        }                  
    }
}
```

Refer to the official [c8y Documentation](https://cumulocity.com/guides/about-doc/intro-documentation/) to better grips to the IoT and c8y concepts.

A `High Level Access` access is provided to allow you to quickly access your devices and groups and avoid a lot of the cruft you would have to develop in your 
Controllers to manage them. 