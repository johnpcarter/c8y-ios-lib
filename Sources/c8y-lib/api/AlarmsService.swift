//
//  AlarmsService.swift
//  Cumulocity Client Library
//
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_ALARMS_API = "alarm/alarms"

/**
 Allows alarms to fetched and posted to Cumulocity
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/alarms/) for more information
 */
public class C8yAlarmsService: C8ySubscriber {
    
    /**
     Used when fetching `C8yAlarm`s to determines the maximum number allowed in a single request,
     default is 50
     */
    public var pageSize: Int = 50
    
    public var version: String = "1"
    
    /**
     Retrieves the  `C8yAlarm` details for the given c8y internal id
  
     - parameter id c8y generated id
     - parameter pageNum The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPagedAlarms` object
     - returns Publisher that will issue successful `C8yAlarm` object via `JcRequestResponse` indicating succes/failure
    */
    public func get(_ id: String, pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yAlarm>, APIError> {
        
        return super._get(resourcePath: args(id: id, pageNum: pageNum)).tryMap({ response in
            return try JcRequestResponse<C8yAlarm>(response, dateFormatter: C8yManagedObject.dateFormatter())
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
      Retrieves a paged collection `C8yPagedAlarms` of `C8yAlarm` instances limited to the size of property `pageSize`.
     
     # Notes: #
      Call the function repeatedly to receive the next page if the number of alarms is the same size as the pageSize
     - parameter source the c8y id of the managed object that is to be queried
     - parameter status Status of alarm type to fetch
     - parameter pageNum The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPagedAlarms` object
     - returns Publisher that will issue `JcRequestResponse` indicating succes/failure and payload containing a page of alarms
    */
    public func get(source: String, status: C8yAlarm.Status, pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yPagedAlarms>, APIError> {
        
        return super._get(resourcePath: args(forSource: source, status: status, pageNum: pageNum)).tryMap({ response in
            return try JcRequestResponse<C8yPagedAlarms>(response, dateFormatter: C8yManagedObject.dateFormatter())
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
    Creates a new `C8yAlarm` in Cumulocity
     
     - parameter alarm The `C8yAlarm` to be created in Cumulocity. id should be null
     - parameter responder the callback to be called with the updated alarm from Cumulocity i.e. will now include c8y id
     - returns Publisher that will issue new created `C8yAlarm` object via `JcRequestResponse` indicating succes/failure
     - throws triggered in the alarm is missing mandatory data or references an invalid managed object
    */
    public func post(_ alarm: C8yAlarm) throws -> AnyPublisher<JcRequestResponse<String?>, APIError> {

        return try super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_ALARMS_API, contentType: "application/json", request: alarm).map({ response in
            let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
            let id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])

            return JcRequestResponse<String?>(response, content: id)
        }).eraseToAnyPublisher()
    }
    
	/**
	Used to update the status of an existing alarm. i.e. acknowledged, cleared etc.
	- parameter alarm the alarm to be updated
	- returns Publisher representing success or failure of update
	*/
    public func put(_ alarm: C8yAlarm) throws -> AnyPublisher<JcRequestResponse<Bool>, APIError> {

        return try super._execute(method: JcConnectionRequest.Method.PUT, resourcePath: args(id: alarm.id!), contentType: "application/json", request: alarm.toJsonString(true)).map({ response in
        
            return JcRequestResponse<Bool>(response, content: true)
        }).eraseToAnyPublisher()
    }
    
	/**
	
	*/
	public func subscribeForNewAlarms(c8yIdOfDevice: String) -> AnyPublisher<C8yAlarm, Error> {
	
		return self.connect(subscription: "/alarms/\(c8yIdOfDevice)")
	}
	
    private func args(id: String) -> String {
         return "\(C8Y_ALARMS_API)/\(id)"
    }
    
    private func args(id: String, pageNum: Int) -> String {
       
        return "\(C8Y_ALARMS_API)/\(id)?pageNum=\(pageNum)&pageSize=\(pageSize)"
    }
    
    private func args(forSource source: String, status: C8yAlarm.Status, pageNum: Int) -> String {
                
        return "\(C8Y_ALARMS_API)?source=\(source)&status=\(status.rawValue)&pageNum=\(pageNum)&pageSize=\(self.pageSize)"
    }
}
