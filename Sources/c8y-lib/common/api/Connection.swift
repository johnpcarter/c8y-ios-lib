//
//  Connection.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_HEADER_LOCATION = "Location"
let JC_HEADER_CONTENT_DISPOSITION = "Content-Disposition"

/**
  Used to indicate what type of authentication to use
 */
enum JcAuthType: String {
    case Basic
    case Bearer
    case Token
    case Anonymous
}

/**
  Convenience protocol  to define connection parameters for API calls when using `URLRequest` via `JcConnectionRequest`
 */
public protocol JcConnection {
    
    /**
     URL including http/https excluding resource path and arguments
     */
    var endPoint: URL { get }
    
    /**
    true if the connection has already been tested and was successful
     */
    var isConnected: Bool { get }
    
    /**
     Reason for previous failure
     */
    var failureReason: String? { get }
    
    /**
     Credentials to be used when connecting
     */
    var credentials: JcCredentials? { get }

    /**
    Default header fields to be sent when making requests
     */
    var headers: Dictionary<String, String>? { get }
    
    /**
     function that will somehow test the connection and update `isConnected`, `failureMessage` etc with results
     
     - parameter completionHandler: callback to receive connection results
     */
    func connect<T>(completionHandler: @escaping (JcRequestResponse<T>) -> Void) throws -> URLSessionDataTask
}

/**
  Represents credentials to be used for making requests
 */
public class JcCredentials {
    
    var user: String?
    var password: String?
    var authType: JcAuthType
    
    init(basicAuthorisation user: String, password: String) {
        
        self.user = user;
        self.password = password;
        self.authType = JcAuthType.Basic
    }
    
    func encodeCredentials(urlRequest: URLRequest) -> URLRequest {

        var urlRequestRef: URLRequest = urlRequest
        
        if (self.user != nil && self.password != nil) {
                 
            urlRequestRef.addValue(String( format: "Basic %@", String(format: "%@:%@", self.user!, self.password!).data(using: String.Encoding.utf8)!.base64EncodedString()), forHTTPHeaderField: "Authorization")

        } else if (self.password != nil) {
             
             urlRequestRef.addValue(String(format: "%@ %@", self.authType.rawValue, self.password!), forHTTPHeaderField: "Authorization")
        }
        
        return urlRequestRef
    }
}

/**
  Status of connection requests to indicate success or failure
 */
public enum JCResponseStatus {
    /**
     Connection or requested succeeded
     */
    case SUCCESS
    
    /**
    Something went wrong processing our request, no valid response received
     */
    case SERVER_SIDE_FAILURE
    
    /**
     Problem occured on our end, response successfully received, but something went wrong when trying to process it
     */
    case CLIENT_SIDE_FAILURE
}

/**
 Defines a response received back from our API call via `JcConnectionRequest` and communicated asynchronously
 via callbacks
 */
public class JcRequestResponse<ResponseContent:Codable> {
    
    /**
     http status code returned from server
     */
    public private(set) var httpStatus: Int
    
    /**
     Response headers returned from server
     */
    public private(set) var httpHeaders: [AnyHashable: Any]?
    
    /**
     Optional http response message returned from server, generally only provided in case of error
     */
    public private(set) var httpMessage: String?
    
    /**
     Flags .SUCCESS or failure of request.
     
     Two types of failure are possible;
     
     # SERVER_SIDE_FAILURE #
     Error was server side, refer to `httpStatus` & `httpMessage`.
     
     # CLIENT_SIDE_FAILURE #
     The failure was triggered on our side when trying to translate the response into something useful, refer instead to `error`
     
     # Notes: #
     Connection failures will not be reported here, as they are triggered immediately when making calls
     */
    public var status: JCResponseStatus {
        get {
            if (httpStatus >= 200 && httpStatus <= 300) {
                if (error != nil) {
                    return JCResponseStatus.CLIENT_SIDE_FAILURE
                } else {
                    return JCResponseStatus.SUCCESS
                }
            } else {
                return JCResponseStatus.SERVER_SIDE_FAILURE
            }
        }
    }
    
    /**
     Error triggered when making request, generally triggered in case where call could not processed after succesffully received, i.e.
     problem translating the response into something useful.
     */
    public private(set) var error: Error?
    
    public let content: ResponseContent?
    
    init(status: Int, message: String?, headers: [AnyHashable: Any]?, content: ResponseContent?) {
        
        self.httpStatus = status
        self.httpMessage = message
        self.httpHeaders = headers
        self.error = nil
        self.content = content
    }
    
    init(_ original: JcRequestResponse<Data>, content: ResponseContent) {
        
        self.httpStatus = original.httpStatus
        self.httpMessage = original.httpMessage
        self.httpHeaders = original.httpHeaders
        
        self.content = content
    }
    
    init(_ original: JcRequestResponse<Data>, dateFormatter: DateFormatter?) throws {
        
        self.httpStatus = original.httpStatus
        self.httpMessage = original.httpMessage
		self.httpHeaders = original.httpHeaders
		
		let decoder = JSONDecoder()
		
		if (dateFormatter == nil) {
			decoder.dateDecodingStrategy = .iso8601
		} else {
			decoder.dateDecodingStrategy = .formatted(dateFormatter!)
		}
		
		if (original.content != nil) {
			self.content = try decoder.decode(ResponseContent.self, from: original.content!)
		} else {
			self.content = nil
		}
		
		self.error = nil
    }
    
    init (_ original: JcRequestResponse<Data>, error: Error) {
        
        self.httpStatus = original.httpStatus
        self.httpMessage = original.httpMessage
        self.httpHeaders = original.httpHeaders
        self.content = nil
        
        self.error = error
    }
    
    init(_ original: JcRequestResponse<Data>) {
        
        self.httpStatus = original.httpStatus
        self.httpMessage = original.httpMessage
        self.httpHeaders = original.httpHeaders
        self.error = original.error
        self.content = nil
    }
    
    func update(_ new: JcRequestResponse<Data>) {
        
        self.httpStatus = new.httpStatus
        self.httpMessage = new.httpMessage
        self.httpHeaders = new.httpHeaders
        self.error = new.error
    }
    
    func update(_ new: JcRequestResponse<Bool>) {
        
        self.httpStatus = new.httpStatus
        self.httpMessage = new.httpMessage
        self.httpHeaders = new.httpHeaders
        self.error = new.error
    }
    
    func update(_ error: Error) {
        self.error = error
    }
}
