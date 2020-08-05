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
    
    private var _connection: T
    
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
    
    internal func _get(resourcePath: String) -> Future<JcRequestResponse<Data>, APIError> {
        
        return Future<JcRequestResponse<Data>, APIError>.init { (promise) in
            _ = self.call(method: Method.GET, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil) { response in
                
                if (response.status == .SUCCESS) {
                    promise(.success(response))
                } else {
                    promise(.failure(self.makeError(response)))
                }
            }
        }
    }
    
    /**
    Allows multipart responses to be fetched, including binary attachments etc.
    
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    internal func _getMultipart(resourcePath: String, completionHandler: @escaping (JcMultiPartRequestResponse) -> Void) -> URLSessionDataTask {
        
        return self.call(method: Method.GET, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil) { (response) in
            
            completionHandler(JcMultiPartRequestResponse(response))
        }
    }
    
    internal func _getMultipart(resourcePath: String) -> Future<JcMultiPartRequestResponse, APIError> {
        
        return Future<JcMultiPartRequestResponse, APIError>.init { (promise) in
            _ = self.call(method: Method.GET, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil) { (response) in
                
                if (response.status == .SUCCESS) {
                    promise(.success(JcMultiPartRequestResponse(response)))
                } else {
                    promise(.failure(self.makeError(response)))
                }
            }
        }
    }
    
    /**
    Simple REST DELETE call
    
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    
    internal func _delete(resourcePath: String) -> Future<JcRequestResponse<Bool>, APIError> {
        
        return Future<JcRequestResponse<Bool>, APIError>.init { (promise) in
            _ = self.call(method: Method.DELETE, resourceEndPoint: resourcePath, contentType: nil, data: nil, acceptType: nil) { response in
                
                if (response.status == .SUCCESS) {
                    promise(.success(JcRequestResponse(response, content: true)))
                } else {
                    promise(.failure(self.makeError(response)))
                }
            }
        }
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
    
    internal func _execute<RequestContent:JcEncodableContent>(method: Method,resourcePath: String, contentType: String, request: RequestContent) throws -> Future<JcRequestResponse<Data>, APIError> {
        
        return Future<JcRequestResponse<Data>, APIError>.init { (promise) in
            
            do {
                _ = try self.call(method: method, resourceEndPoint: resourcePath, contentType: contentType, data: self.parseRequestContent(request), acceptType: self.acceptTypeForResponse(request)) { response in
                    
                    if (response.status == .SUCCESS) {
                        promise(.success(response))
                    } else {
                        promise(.failure(self.makeError(response)))
                    }
                }
            } catch {
                promise(.failure(self.makeError(error)))
            }
        }
    }
    
    /**
    Allows REST call with specified Method, including arbitrary request Data
    
    - parameter method: GET/POST/PUT/PATCH/DELETE
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter contentType: Indicates the type of content to be sent e.g. 'text/plain', 'application/json' etc.
    - parameter RequestContent: Data to be sent
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    
    internal func _execute(method: Method, resourcePath: String, contentType: String, request: Data) -> Future<JcRequestResponse<Data>, APIError> {

        return Future<JcRequestResponse<Data>, APIError>.init { (promise) in
            
            _ = self.call(method: method, resourceEndPoint: resourcePath, contentType: contentType, data: request, acceptType: self.acceptTypeForResponse(request)) { response in
                
                if (response.status == .SUCCESS) {
                    promise(.success(response))
                } else {
                    promise(.failure(self.makeError(response)))
                }
            }
        }
    }
    
    /**
    Allows REST call with multipart/content formatted request that can be created easily via `JcMultiPartRequestResponse`
    
    - parameter method: GET/POST/PUT/PATCH/DELETE
    - parameter resourePath: the path of the resource to be interrogated, can include resource attributes and include parameters
    - parameter contentType: Indicates the type of content to be sent e.g. 'text/plain', 'application/json' etc.
    - parameter RequestContent: multipart formatted data via `JcMultiPartRequestResponse`
    - parameter completionHandler: callback for processing results
    - returns: Http session task used to invoke request
    */
    
    internal func _execute(method: Method,resourcePath: String, request: JcMultiPartContent) -> Future<JcRequestResponse<Data>, APIError> {
        
        return Future<JcRequestResponse<Data>, APIError>.init { (promise) in
            
            _ = self.call(method: method, resourceEndPoint: resourcePath, contentType: JC_MULTIPART_CONTENT_TYPE, data: request.build(), acceptType: self.acceptTypeForResponse(request)) { response in
                
                if (response.status == .SUCCESS) {
                    promise(.success(response))
                } else {
                    promise(.failure(self.makeError(response)))
                }
            }
        }
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
    
    
    private func call(method: Method, resourceEndPoint: String, contentType: String?, data: Data?, acceptType: String?, completionHandler: @escaping (JcRequestResponse<Data>) -> Void) -> URLSessionDataTask {
        
        print ("===== wotsit \(_connection.endPoint)/\(resourceEndPoint)")
        
        let url = URL(string: resourceEndPoint, relativeTo: _connection.endPoint)
        var urlRequest = URLRequest(url: url!)
        
        urlRequest.httpMethod = method.rawValue
        
        if (_connection.credentials != nil) {
            urlRequest = _connection.credentials!.encodeCredentials(urlRequest: urlRequest)
        }
        
        print("invoking \(method.rawValue) - " + urlRequest.url!.absoluteString)
        
        urlRequest.addValue(acceptType ?? "application/json", forHTTPHeaderField: "Accept")
        
        if (method == Method.POST || method == Method.PUT || method == Method.PATCH) {
            
            if (data != nil && data!.count < 2048) {
                print("\(String(decoding: data!, as: UTF8.self))")
            }
            
            urlRequest.addValue(contentType ?? "application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = data!
        }

        //let session = URLSession.shared
        let session = URLSession(configuration: URLSessionConfiguration.default);

        let task = session.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in

            guard error == nil else {
                
                completionHandler(JcRequestResponse(status: -1, message: error?.localizedDescription ?? "Unknown error", headers: nil, content: nil))
                return
            }
            
            let statusCode = (response as! HTTPURLResponse).statusCode;
            var content: Data? = nil
            var message: String? = nil
            
            if (statusCode >= 200 && statusCode <= 201) {
                
                if (data != nil) {
                    content = data
                }
            } else if (data != nil) {
                // assume data is error reason
                message = String(decoding: data!, as: UTF8.self)
            }
            
            completionHandler(JcRequestResponse(status: statusCode, message: message, headers: (response as! HTTPURLResponse).allHeaderFields, content: content))
        })

        task.resume()
        
        return task
    }
    
    private func makeError(_ error: Error) -> APIError {
        return APIError(httpCode: -1, reason: error.localizedDescription)
    }
    
    private func makeError<T>(_ response: JcRequestResponse<T>) -> APIError {
        
        if (response.httpMessage != nil) {
            return APIError(httpCode: response.httpStatus, reason: response.httpMessage)
        } else if (response.error != nil) {
            return APIError(httpCode: response.httpStatus, reason: response.error?.localizedDescription)
        } else {
            return APIError(httpCode: response.httpStatus, reason: "undocumented")
        }
    
    }
    
    public struct APIError: Error {
        
        public var httpCode: Int
        public var reason: String?
    }
}
