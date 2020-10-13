//
//  Operation.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_OPERATIONS_API = "devicecontrol/operations/"

/**
 Allows devices to be remote controlled via c8y
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/device-control/#device-control-api) for more information
 */
public class C8yOperationService: JcConnectionRequest<C8yCumulocityConnection> {
    
	/**
	Fetch a list of operations associated with the managed object given by the id
	
	- parameter source internal c8y id of the associated managed object
	- returns Publisher that will issue the list of resulting operations.
	*/
    public func get(_ source: String) -> AnyPublisher<JcRequestResponse<C8yPagedOperations>, APIError> {
     
        return super._get(resourcePath: self.args(id: source)).tryMap({ response in
            return try JcRequestResponse<C8yPagedOperations>(response, dateFormatter: C8yManagedObject.dateFormatter())
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
     Submits an operation to Cumulocity to be run on the targeted device refereneced by the managed object
     
     - parameter operation  `C8yOperation` to be posted to Cumulocity
     - returns Publisher that will issue updated operation including attributed c8y internal id
     - throws If operation is not correctly formatted
     */
    func post(operation: C8yOperation) throws -> AnyPublisher<JcRequestResponse<C8yOperation>, APIError>  {

        // "application/vnd.com.nsn.cumulocity.operation+json;ver=\(version)"
        
        return try super._execute(method: Method.POST, resourcePath: C8Y_OPERATIONS_API, contentType: "application/json", request: operation).tryMap({ response in
            return try JcRequestResponse<C8yOperation>(response, dateFormatter: C8yManagedObject.dateFormatter())
        }).mapError({ error -> APIError in
            switch (error) {
            case let error as APIError:
                return error
            default:
                return APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }
    
    private func args(id: String) -> String {
        return "\(C8Y_OPERATIONS_API)?deviceId=\(id)"
    }
}
