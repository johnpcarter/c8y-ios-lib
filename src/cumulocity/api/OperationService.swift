//
//  Operation.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let C8Y_OPERATIONS_API = "/devicecontrol/operations/"

/**
 Allows devices to be remote controled via c8y
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/device-control/#device-control-api) for more information
 */
public class JcEventsService: JcConnectionRequest<JcCumulocityConnection> {
    
    /**
     Submits an operation to Cumulocity to be run on the targeted device refereneced by the managed object
     
     - parameter operation : `JcOperation` to be posted to Cumulocity
     - parameter completionHandler: callback function which will be called with the updated c8y internal id
     */
    func post(operation: JcOperation,  completionHandler: @escaping (JcRequestResponse<JcOperation>) -> Void) -> URLSessionDataTask  {

        return try super.execute(Method.POST, "application/vnd.com.nsn.cumulocity.operation+json;ver=$version", operation) { (response) in
            
            return JcRequestResponse<JcEvent>(response, type: JcOperation.self, dateFormatter: JcManagedObject.dateFormatter())
        }
    }
}
