//
//  EventsService.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_EVENTS_API = "event/events"

/**
 Allows events related to `C8yManagedObject` to fetched and posted to Cumulocity
 
Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/events/) for more information
 */
public class C8yEventsService: JcConnectionRequest<C8yCumulocityConnection> {

    /**
     Used when fetching `C8yEvent`s to determines the maximum number allowed in a single request,
     default is 50
     */
    public var pageSize: Int = 50
 
    /**
     Determines in which order events  should be fetched, i.e. most recent first (false) or oldest first (true)
     default is false, newest first
     */
    var revert: Bool = false
    
    /**
     Retrieves the  `C8yEvent` details for the given c8y internal id
  
     - parameter id c8y generated id
     - returns Publisher that will issue fetched `C8yEvent` or error 404 if not found
     */
    public func get(_ id: String) -> AnyPublisher<JcRequestResponse<C8yEvent>, APIError> {
     
        return super._get(resourcePath: self.args(id: id)).tryMap({ response in
            return try JcRequestResponse<C8yEvent>(response, dateFormatter: C8yManagedObject.dateFormatter())
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
     Retrieves all events  associated with the given source `C8yManagedObject`
     
     # Notes: #
     
     It retreives the newest to oldest events first with a maximum number specified by `pageSize` in a single request. Call the method incrementing the page
     number to fetch older and older events if required.
     
     - parameter source internal c8y of the associated managed object
     - parameter pageNum The page to be fetched, total pages can be found in  via the statistics property `PageStatistics` of the returned `C8yPagedAlarms` object
     - returns Publisher that will issue fetched events in a `C8yPagedEvents` instance
     */
    public func get(source: String, pageNum: Int) -> AnyPublisher<JcRequestResponse<C8yPagedEvents>, APIError> {
     
        self.revert = false
        self.pageSize = 50
        
        return super._get(resourcePath: self.args(forSource: source, pageNum: pageNum)).tryMap({ response in
            try JcRequestResponse<C8yPagedEvents>(response, dateFormatter: C8yManagedObject.dateFormatter())
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
     Submits the `C8yEvent` to cumulocity for processing
	
    - parameter event A new event to be posted, c8y id must be null
	- returns Publisher that will issue fetched events in a `C8yPagedEvents` instance
     */
    public func post(_ event: C8yEvent) throws -> AnyPublisher<JcRequestResponse<C8yEvent>, APIError> {

        try super._execute(method: Method.POST, resourcePath: C8Y_EVENTS_API, contentType: "application/json", request: event).map ( { response in
            
			let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
			var updatedEvent: C8yEvent = event

			updatedEvent.id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])

			return JcRequestResponse<C8yEvent>(response, content: updatedEvent)
			
        }).eraseToAnyPublisher()
    }
    
    private func args(id: String) -> String {
        
        return String(format: "%@/%@&timeStamp", C8Y_EVENTS_API, id, self.timeStamp())
    }
    
    private func args(forSource: String, pageNum: Int) -> String {
        return "\(C8Y_EVENTS_API)?source=\(forSource)&pageSize=\(pageSize)&pageNum=\(pageNum)&revert=\(revert)&\(self.timeStamp())"
    }
    
    private func timeStamp() -> String {
        
        let from = Date().advanced(by: -86400)
        let to = Date()
        
        return "dateFrom=\(parseDate(from))&dateTo=\(parseDate(to))"
    }
    
    private func parseDate(_ date: Date) -> String {
        
        return C8yManagedObject.dateFormatter().string(from: date).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
}
