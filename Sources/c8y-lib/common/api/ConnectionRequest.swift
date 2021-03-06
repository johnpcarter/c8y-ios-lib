//
//  ConnectionRequest.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

/**
 Convenience class to simplify API calls via wrapped instances of `UrlRequest` and `UrlSession`
 You will need instantiate a valid `JcConnection` object via the `JcConnectionFactory` class to instantiate an object of this class.
 
 # Notes: #
 This class should not be used directly, use it as a inherited class and leverage the various `_get(resourcePath:completionHandler:)`, `_delete(resourcePath:completionHandler:)`
 `_execute(method:resourcePath:contentType:request:completionHandler:)` methods from your class.
 
 Objects derived from this class are not thread safe and should be reused. Create an instance for each request as required
 */
public class JcConnectionRequest<T:JcSimpleConnection> {

    /**
     Defines the HTTP method to be used
     */
    public enum Method: String {
        case GET
        case POST
        case PUT
        case PATCH
        case DELETE
    }
    
    internal var _connection: T
    
	private var _session: URLSessionDataTask? = nil
	
    /**
     Invoke this as your super init to propagate the connection parameter
     */
    public init(_ connection: T) {
        
        _connection = connection
    }
    
    /**
     SImple REST GET call
     
     - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
     - parameter completionHandler: callback for processing results
     - returns: Http session task used to invoke request
     */
    
    internal func _get(resourcePath: String, headers: [String:String]? = nil) -> AnyPublisher<JcRequestResponse<Data>, APIError> {
        
		return self.call(method: Method.GET, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil, headers: headers)
    }
    
    /**
    Allows multipart responses to be fetched, including binary attachments etc.
    
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    
    internal func _getMultipart(resourcePath: String, headers: [String:String]? = nil) -> AnyPublisher<JcMultiPartRequestResponse, APIError> {
        
		self.call(method: Method.GET, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil, headers: headers)
			.map({ (response) -> JcMultiPartRequestResponse in
				return JcMultiPartRequestResponse(response)
			}).eraseToAnyPublisher()
    }
    
    /**
    Simple REST DELETE call
    
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - returns: Http session task used to invoke request
    */
    
	internal func _delete(resourcePath: String) -> AnyPublisher<JcRequestResponse<Bool>, APIError> {
		
		return self.call(method: Method.DELETE, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil)
			.map({ (response) -> JcRequestResponse<Bool> in
				if (response.status == .SUCCESS) {
					return JcRequestResponse(response, content: true)
				} else {
					return JcRequestResponse(response, content: false)
				}
			}).eraseToAnyPublisher()
	}

    /**
    Allows REST call with specified Method with  `JcEncodableContent` request content
    
    - parameter method: GET/POST/PUT/PATCH/DELETE
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter contentType: Indicates the type of content to be sent e.g. 'text/plain', 'application/json' etc.
    - parameter RequestContent: Your request object, must implement `JcEncodableContent`
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    
	internal func _execute<RequestContent:JcEncodableContent>(method: Method, resourcePath: String, contentType: String, request: RequestContent, headers: [String:String]? = nil) throws -> AnyPublisher<JcRequestResponse<Data>, APIError> {
        
		return try self.call(method: method, resourceEndPoint: resourcePath, contentType: contentType, data: self.parseRequestContent(request), acceptType: self.acceptTypeForResponse(request), headers: headers)
    }
    
    /**
    Allows REST call with specified Method, including arbitrary request Data
    
    - parameter method: GET/POST/PUT/PATCH/DELETE
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter contentType: Indicates the type of content to be sent e.g. 'text/plain', 'application/json' etc.
    - parameter RequestContent: Data to be sent
    - returns: Http session task used to invoke request
    */
    
    internal func _execute(method: Method, resourcePath: String, contentType: String, request: Data, headers: [String:String]? = nil) -> AnyPublisher<JcRequestResponse<Data>, APIError> {

		return self.call(method: method, resourceEndPoint: resourcePath, contentType: contentType, data: request, acceptType: self.acceptTypeForResponse(request), headers: headers)
    }
    
    /**
    Allows REST call with multipart/content formatted request that can be created easily via `JcMultiPartRequestResponse`
    
    - parameter method: GET/POST/PUT/PATCH/DELETE
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter contentType: Indicates the type of content to be sent e.g. 'text/plain', 'application/json' etc.
    - parameter RequestContent: multipart formatted data via `JcMultiPartRequestResponse`
    - returns: Http session task used to invoke request
    */
    
    internal func _execute(method: Method,resourcePath: String, request: JcMultiPartContent, headers: [String:String]? = nil) -> AnyPublisher<JcRequestResponse<Data>, APIError> {
        
		return self.call(method: method, resourceEndPoint: resourcePath, contentType: JC_MULTIPART_CONTENT_TYPE, data: request.build(), acceptType: self.acceptTypeForResponse(request))
    }
    
    /**
     Default type  for acceptable respnose format, can be overriden if required
     */
    open func acceptTypeForResponse<RequestContent>(_ data: RequestContent) -> String? {
        
        return "application/json"
    }
    
    internal func parseRequestContent<RequestContent:JcEncodableContent>(_ data: RequestContent) throws -> Data {
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(data)
    }
    
    
	private func call(method: Method, resourceEndPoint: String, contentType: String?, data: Data?, acceptType: String?, headers: [String:String]? = nil) -> AnyPublisher<JcRequestResponse<Data>, APIError> {
		
		return _call(method: method, resourceEndPoint: resourceEndPoint, contentType: contentType, data: data, acceptType: acceptType, headers: headers)
			.tryMap({ (data, response) -> JcRequestResponse<Data> in
				
				let statusCode = (response as! HTTPURLResponse).statusCode
				
				if (statusCode < 200 || statusCode > 204) {
					throw self.makeError((response as! HTTPURLResponse), data: data)
				} else {
					return JcRequestResponse(status: statusCode, message: (response as! HTTPURLResponse).description, headers: (response as! HTTPURLResponse).allHeaderFields, content: data)
				}
			}).mapError{$0 as! APIError}.eraseToAnyPublisher()
	}
	
	private func _call(method: Method, resourceEndPoint: String, contentType: String?, data: Data?, acceptType: String?, headers: [String:String]? = nil) -> AnyPublisher<URLSession.DataTaskPublisher.Output, APIError> {
				
		let url = URL(string: resourceEndPoint, relativeTo: _connection.endPoint)
		var urlRequest = URLRequest(url: url!)
		
		urlRequest.httpMethod = method.rawValue
		
		if (_connection.credentials != nil) {
			urlRequest = _connection.credentials!.encodeCredentials(urlRequest: urlRequest)
		}
				
		urlRequest.addValue(acceptType ?? "application/json", forHTTPHeaderField: "Accept")
		
		if (headers != nil) {
			headers!.forEach { k, v in
				urlRequest.addValue(v, forHTTPHeaderField: k)
			}
		}
		
		if (method == Method.POST || method == Method.PUT || method == Method.PATCH) {
			
			urlRequest.addValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
			urlRequest.httpBody = data!
		}

		return URLSession.shared.dataTaskPublisher(for: urlRequest)
			.mapError({ error -> APIError in
				return self.makeError(error)
			}).eraseToAnyPublisher()
	}
    
    private func makeError(_ error: Error) -> APIError {
        return APIError(httpCode: -1, reason: error.localizedDescription)
    }
	
	private func makeError(_ response: HTTPURLResponse, data: Data?) -> APIError {
		
		let r = data != nil ? String(decoding: data!, as: UTF8.self) : response.description
		
		return APIError(httpCode: response.statusCode, reason: r)
	}
    
    internal func makeError<T>(_ response: JcRequestResponse<T>) -> APIError {
        
        if (response.httpMessage != nil) {
            return APIError(httpCode: response.httpStatus, reason: response.httpMessage)
        } else if (response.error != nil) {
            return APIError(httpCode: response.httpStatus, reason: response.error?.localizedDescription)
        } else {
            return APIError(httpCode: response.httpStatus, reason: "undocumented")
        }
    
    }
    
    public struct APIError: LocalizedError, CustomStringConvertible {
        
        public var httpCode: Int
        public var reason: String?
		
		public var description: String {
			let format = NSLocalizedString("http error: \(httpCode) - \(reason ?? "no reason given")", comment: "Error description")
			return String.localizedStringWithFormat(format)
		}
    }
}
