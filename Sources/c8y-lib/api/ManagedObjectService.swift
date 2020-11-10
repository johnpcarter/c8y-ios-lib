//
//  ManagedObjectService.swift
//  Cumulocity Client Library
//
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_MANAGED_OBJECTS_API = "inventory/managedObjects"
let C8Y_MANAGED_OBJECTS_EXT_API = "identity/externalIds"
let C8Y_MANAGED_EXTIDS_API = "identity/globalIds"

let C8Y_TYPE_DEVICE_TYPE = "c8y_Device"

/**
 Principal access point for all Cumulocity data represented as `ManagedObject`s such as devices and groups and implemented through the API endpoint *\/inventory/managedObjects*.

 Use this class to fetch, create, update and delete assets in c8y
 
 Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/inventory/) for more information
 
 */
public class C8yManagedObjectsService: JcConnectionRequest<C8yCumulocityConnection> {
    
    public enum ManagedObjectNotFoundError: Error {
        case id (String)
        case externalId (String)
        case type (String)
    }
    
    /**
     Used when fetching `C8yManagedObject`s to determines the maximum number allowed in a single request,
     default is 50
     
    # Notes: #
     
     Managed Objects are grouped into pages  via the `C8yPagedManagedObjects` class, successive pages can be fetched by
     invoking the appropriate get method with the specified page number.
     The `C8yPagedManagedObjects` references the current page, size and total via the property `statistics`, which is
     defined by `C8yPageStatistics`.
     */
    public var pageSize: Int = 50
    
    /**
    Fetch the managed object `C8yManagedObject` using the cumulocity internal id
     
     # Notes: #
     
     The id is only known by c8y, you will need to first fetch a list of managed objects or reference the managed
     object via an external id.
     
     # Example: #
     ```
     C8yPagedManagedObjectsService(conn).get(pageNum: 0) { (response) in
     
        if (response.status == .SUCCESS) {
            print("\(String(describing: response.content!.owner))")
        }
     }
     ```
     
     - parameter id c8y generated id
	 - returns Publisher for resulting `C8yManagedObject` if any encapsulated in `JcRequestResponse` wrapper defining result
     */
    public func get(_ id: String) -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
           
        return super._get(resourcePath: args(id: id)).tryMap({ (response) -> JcRequestResponse<C8yManagedObject> in
            return try JcRequestResponse<C8yManagedObject>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }).mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }

    /**
     Fetch the managed object `C8yManagedObject` using an external id
     
    # Notes: #
     The object associated with the given external id, i.e. assigned via method `post(object:withExternalId:ofType:)`.
     The values will show under the identity tab of the given device in c8y Device Management
     
     - parameter forExternalId id given by device such as serial number, imei etc.
     - parameter ofType identifies the type of id e.g. 'c8y_Serial' or 'LoRa EUI' etc.
	 - parameter deviceOnly set to true if only devices should be searched, default false means look for any matching managed object
     - returns Publisher for resulting `C8yManagedObject` if any encapsulated in `JcRequestResponse` wrapper defining result
     */
	public func get(forExternalId: String, ofType: String, deviceOnly: Bool = false) -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
           
        return super._get(resourcePath: args(forExternalId: forExternalId, ofType: ofType)).tryMap({ (response) -> String in
            if (response.status == .SUCCESS) {
                
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(C8yExternalId.self, from: response.content!).id!
                    
                } catch {
                    // couldn't translate xref response
                    throw APIError(httpCode: -1, reason: "No such match object found for external id \(forExternalId) && type \(ofType)")
                }
            } else {
                throw APIError(httpCode: -1, reason: "No such match object found for external id \(forExternalId) && type \(ofType)")
            }
        }).mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).flatMap({ (c8yId) -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> in
            return self.get(c8yId)
        }).eraseToAnyPublisher()
    }

    /**
     Returns all managed objects in c8y restricted to the given page with the page size specified by the *pageSize*
     property of your `C8yPagedManagedObjectsService` instance, default is 50 items per page.
     
     # Notes: #
     
     Invoke this method for successive page whilst incrementing the pageNum
     You will get a empty list once you go past the last page.
     
     # Example #
     ```
     let service = C8yPagedManagedObjectsService(conn)
     service.pageSize = 10
     
     service.get(pageNum: 0) { (response) in
     
        if (response.status == .SUCCESS) {
            
            print("page \(response.content!.statistics.currentPage) of \(response.content!.statistics.totalPages), size \(response.content!.statistics.pageSize)")
            
            for object in response.content!.objects {
                print("\(String(describing: object.id))")
            }
        }
     }
     ```
     
     - parameter pageNum  The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPageManagedObjects` object
	 - returns: Publisher for resulting page `C8yPagedManagedObjects` of `C8yManagedObject` objects, if any encapsulated in `JcRequestResponse` wrapper defining result
     */
    public func get(pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yPagedManagedObjects>, APIError> {
        
        return super._get(resourcePath: args(page: pageNum, ofPageSize: pageSize)).tryMap { (response) -> JcRequestResponse<C8yPagedManagedObjects> in
            return try JcRequestResponse<C8yPagedManagedObjects>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }.mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }
    
    /**
     Returns all managed objects in c8y restricted for the given type and page number with the page size specified by the *pageSize*
     property of your `C8yManagedObjectService` instance, default is 50 items per page
	
	# Notes: #
		
		Invoke this method for successive page whilst incrementing the pageNum
		You will get a empty list once you go past the last page.
	
     - parameter forType Identifies the type of managed objects to be fetched e.g. c8y_Device or c8y_DeviceGroup
	 - parameter pageNum The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPageManagedObjects` object
	 - returns Publisher for resulting page `C8yPagedManagedObjects` of `C8yManagedObject` objects, if any encapsulated in `JcRequestResponse` wrapper defining result
     */
    public func get(forType type: String, pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yPagedManagedObjects>, APIError> {
        
        return super._get(resourcePath: args(forType: type, andPage: pageNum, ofPageSize: pageSize)).tryMap { (response) -> JcRequestResponse<C8yPagedManagedObjects> in
            return try JcRequestResponse<C8yPagedManagedObjects>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }.mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }
    
    /**
     Allows managed objects to be fetched based on set of query parameters `C8yManagedObjectQuery` and grouped into pages via `C8yPagedManagedObjects`
     
     # Notes: #
     
        All queries must apply (ANDED) if more than query is specified.
     
     # Example: #
     ```
     let query = C8yManagedObjectQuery()
                .add("type", C8yManagedObjectQuery.Operator.eq, "c8y_DeviceGroup")
                .add("bygroupid", nil, "123456")
     
     let service = C8yPagedManagedObjectsService(conn).get(forQuery: query, pageNum: 0) { (response) in
     
        if (response.status == .SUCCESS) {
            
            print("page \(response.content!.statistics.currentPage) of \(response.content!.statistics.totalPages), size \(response.content!.statistics.pageSize)")
            
            for object in response.content!.objects {
                print("\(String(describing: object.id))")
            }
        }
     }
     ```
     
     - parameter forQuery `C8yManagedObjectQuery` object referencing one or more queries to filter on
     - parameter pageNum The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPageManagedObjects` object
	 - returns Publisher for resulting page `C8yPagedManagedObjects` of `C8yManagedObject` objects, if any encapsulated in `JcRequestResponse` wrapper defining result
     */
    public func get(forQuery: C8yManagedObjectQuery, pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yPagedManagedObjects>, APIError>  {
        
        return super._get(resourcePath: args(forQuery: forQuery, andPage: pageNum, ofPageSize: pageSize)).tryMap { (response) -> JcRequestResponse<C8yPagedManagedObjects> in
            return try JcRequestResponse<C8yPagedManagedObjects>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }.mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }
    
    /**
     Adds the new managed object to your cumulocity tenant.
     The internal id generated by Cumulocity is included in the updated object returned by the Publisher
     
     # Notes: #
     
     Not all elements of your managed object can be posted, refer to the *REST API Guide* - (https://cumulocity.com/guides/reference/inventory/#managed-object)
     for more details
        
     - parameter object a `ManagedObject` created locally for which the id attribute will be null
     - returns Publisher indicating success/failure and an updated `C8yManagedObject` including the  internal id attributed by cumulocity.
     - throws Error if the object is missing required fields
	- seeAlso get(forExternalId:ofType:)
     */
    public func post(_ object: C8yManagedObject) throws -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
    
        return try super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_MANAGED_OBJECTS_API, contentType: "application/json", request: object).map({ (response) -> JcRequestResponse<C8yManagedObject> in
                
			let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
			let id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])
			var updatedObject = object
			updatedObject.updateId(id)
                
			return JcRequestResponse<C8yManagedObject>(response, content: updatedObject)
        }).eraseToAnyPublisher()
    }
    
    /**
    Adds the new managed object to your cumulocity tenant, incuding a reference to the external id provided here.
	The internal id generated by Cumulocity is included in the updated object returned by the Publisher.
    
    # Notes: #
    
     You can in turn fetch the managed object using the external id
     
     Not all elements of your managed object can be updated in c8y, refer to the [REST API Guide](https://cumulocity.com/guides/reference/inventory/#managed-object)
     for more details
                
    - parameter object a `C8yManagedObject` created locally for which the id attribute will be null
    - parameter withExternalId  The external id to be associated with the existing managed object
    - parameter ofType Label identifying the type of external id e.g. 'c8y_Serial', 'LoRaDevEUI' etc. and externl references, confirming success or failure
    - returns Publisher indicating success/failure and an updated `C8yManagedObject` including the  internal id attributed by cumulocity.
    - throws Error if the object is missing required fields
    - requires valid ManagedObject reference without id
    - seeAlso get(forExternalId:ofType:)
    */
    public func post(_ object: C8yManagedObject, withExternalId externalId: String, ofType type: String) throws -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
    
        let request: Data = try self.parseRequestContent(C8yExternalId(withExternalId: externalId, ofType: type))
        var updatedObject: C8yManagedObject? = nil
        
        return try super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_MANAGED_OBJECTS_API, contentType: "application/json", request: object).map({ (response) -> JcRequestResponse<C8yManagedObject> in
                let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
                let id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])
                
                updatedObject = object
                updatedObject!.updateId(id)
                
                return JcRequestResponse<C8yManagedObject>(response, content: updatedObject!)
        }).flatMap({ (response) -> AnyPublisher<JcRequestResponse<Data>, APIError> in
            return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: String(format: "%@/%@/externalIds", C8Y_MANAGED_EXTIDS_API, response.content!.id!), contentType: "application/json", request: request)
        }).map({ (response) -> JcRequestResponse<C8yManagedObject> in
            return JcRequestResponse(response, content: updatedObject!)
        }).eraseToAnyPublisher()
    }
    
    /**
     Updates the  managed object in your cumulocity tenant. You do not have to specify all atributes in your `C8yManagedObject` only those that have changed.
	 Use one of the `C8yManagedObject` constructors to updated speficific properties such as response Interval, notes or other properties.
	
     # Notes: #
     
     Not all elements of your managed object can be posted, refer to the *REST API Guide* - (https://cumulocity.com/guides/reference/inventory/#managed-object)
     for more details
        
     - parameter object either a `ManagedObject` retrieved via `get(object:)` or a fragment created via `C8yManagedObject.init()`
     - returns Publisher indicating success/failure and an updated `C8yManagedObject`
     - throws Error if the object is missing c8y id
     */
    public func put(_ object: C8yManagedObject) throws -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
    
        return try super._execute(method: JcConnectionRequest.Method.PUT, resourcePath: "\(C8Y_MANAGED_OBJECTS_API)/\(object.id!)", contentType: "application/json", request: object).map({ (response) -> JcRequestResponse<C8yManagedObject> in
            return JcRequestResponse<C8yManagedObject>(response, content: object)
            }).eraseToAnyPublisher()
    }
    
    /**
     Ensures a existing `C8yManagedObject` can be retrieved with the given external id
     
     - parameter externalId The external id to be associated with the existing managed object
     - parameter ofType Label identifying the type of external id e.g. 'c8y_Serial', 'LoRaDevEUI' etc.
     - parameter forId internal c8y id of the managed object
     - returns Publisher indicating success/failure
     */
    public func register(externalId: String, ofType type: String, forId id: String) throws -> AnyPublisher<JcRequestResponse<String>, APIError> {
        
        let externalIdRef = C8yExternalId(withExternalId: externalId, ofType: type)
                           
        return try super._execute(method: JcConnectionRequest.Method.POST, resourcePath: String(format: "%@/%@/externalIds", C8Y_MANAGED_EXTIDS_API, id), contentType: "application/json", request: externalIdRef).map({ response -> JcRequestResponse<String> in
            return JcRequestResponse<String>(response, content: id)//response.status == .SUCCESS)
        }).eraseToAnyPublisher()
    }
    
    /**
     Retrieves the list of external id's associated for the `C8yManagedObject` for the given c8y internal id
     
     # Notes: #
     
     Define an external id for your managed object at creation time using the method `post(object:withExternalId:ofType:)`
     Alternatively you can register as many external id's as you want after the object has been created using `register(externalId:ofType:forId:)`
     
     - parameter id The internal c8y id of the `C8yManagedObject`
     - returns Publisher with response containing a list of the external ids `RequestResponder<C8yExternalIds>`
     */
	public func externalIDsForManagedObject(_ id: String) -> AnyPublisher<JcRequestResponse<C8yExternalIds>, APIError> {

        return super._get(resourcePath: "\(C8Y_MANAGED_EXTIDS_API)/\(id)/externalIds").tryMap({ response -> JcRequestResponse<C8yExternalIds> in
            return try JcRequestResponse<C8yExternalIds>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }).mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }

    /**
     Associates the given managed object with the identified group. This is most often used to add a device 'c8y_Device' to a group 'c8y_DeviceGroup'
     
     - parameter child The internal id of the managed object to be assigned
     - parameter parentId The internal id of parent managed object to which the child will be associated
     - returns Publisher which will issue the resulting `RequestResponder<C8yManagedObject>` confirming success or failure
     */
    public func assignToGroup(child: String, parentId: String) -> AnyPublisher<JcRequestResponse<Bool>, APIError> {

        let payload = "{\n" +
        "    \"managedObject\" : {\n" +
        "        \"id\" : \"\(child)\"\n" +
        "    }\n" +
        "}"
        
    return super._execute(method: Method.POST, resourcePath: "\(C8Y_MANAGED_OBJECTS_API)/\(parentId)/childAssets", contentType: "application/json", request: Data(payload.utf8)).map({ response -> JcRequestResponse<Bool> in
        return JcRequestResponse<Bool>(response, content: true)
        }).eraseToAnyPublisher()
    }

    /**
     Deletes the given managed object
     
     - parameter id c8y internal id of the managed object to delete
     - returns  Publisher which will issue the `RequestResponder<Bool>` confirming success or failure
     */
    public func delete(id: String) -> AnyPublisher<JcRequestResponse<Bool>, APIError> {

        super._delete(resourcePath: args(id: id)).eraseToAnyPublisher()
    }
    
    private func args(id: String) -> String {
       
        return  "\(C8Y_MANAGED_OBJECTS_API)/\(id)"//.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }
    
    private func args(forExternalId ext: String, ofType type: String) -> String {
    
        return "\(C8Y_MANAGED_OBJECTS_EXT_API)/\(type.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)/\(ext)"
    }
    
    private func args(forQuery query: C8yManagedObjectQuery, andPage page: Int, ofPageSize size: Int) -> String {
    
        return "\(C8Y_MANAGED_OBJECTS_API)?pageNum=\(page)&pageSize=\(size)&query=\(query.build())"
    }
    
    private func args(forType type: String, andPage page: Int, ofPageSize size: Int) -> String {
    
        return  "\(C8Y_MANAGED_OBJECTS_API)?pageNum=\(page)&pageSize=\(size)&type=\(type.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)"
    }
    
    private func args(page: Int, ofPageSize size: Int) -> String {
        
        return  "\(C8Y_MANAGED_OBJECTS_API)?pageNum=\(page)&pageSize=\(size)"
    }
}
