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
 Allows devices to be remote controled via c8y
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/device-control/#device-control-api) for more information
 */
public class C8yOperationService: JcConnectionRequest<C8yCumulocityConnection> {
    
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
     
     - parameter operation : `C8yOperation` to be posted to Cumulocity
     - parameter version: The version of the operation to be rerenced
     - parameter completionHandler: callback function which will be called with the updated c8y internal id
     - throws: If operation is not correctly formatted or references non existent device in c8y
     */
    func post(operation: C8yOperation, version: Double) throws -> AnyPublisher<JcRequestResponse<C8yOperation>, APIError>  {

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
