//
//  ConnectionFactory.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Convenience class to intantiate connection based on the 'JcConnection' protocol using different authentication strategies
 */
public class JcConnectionFactory {
    
    /**
     Shared instance of this factory class, avoids having to instantiate objects unnecessarily
     */
    public static var shared: JcConnectionFactory = JcConnectionFactory();

    enum ConnectionTypeNotImplementedError: Error {
        case type(_ type: String)
    }
    
    init() {
        
    }
    
    /**
     Defines a connection based on HTTP Basic authentication to be used when calling `JcConnectionRequest`
     
     # Notes: #
     This call is *stateless* and does not manage cookies, sessions etc. This call is simply to allow us to test the credentials, the connection parameters will be
     resent in every API call.
     
     - parameter url: Url of API end-point excluding resource and arguments
     - parameter authEndpoint: resource path that will allows us to test the connection parameters
     - parameter user: User id to be used to authenticate
     - parameter password: plain text password to be used to authenticate
     - returns: Connection instance that can be used when calling `JcConnectionRequest`
     */
    public func connection(url: URL, authEndpoint: String, user: String, password: String) -> JcSimpleConnection {
        
        return BasicAuthenticatedConnection(url: url, authEndpoint: authEndpoint, user: user, password: password)
    }
    
    class BasicAuthenticatedConnection: JcSimpleConnection {
        
        init(url: URL, authEndpoint: String, user: String, password: String) {

            super.init(url: url, authEndpoint: authEndpoint)
            
            credentials = JcCredentials(basicAuthorisation: user, password: password)
        }
        
        override func connect<T>(completionHandler: @escaping (JcRequestResponse<T>) -> Void) throws -> URLSessionDataTask {

            throw ConnectionTypeNotImplementedError.type("BasicAuthenticationConnection")
        }
    }
}

public class JcSimpleConnection: JcConnection {
    
    public private(set) var endPoint: URL
    public private(set) var authEndpoint: String
    
    public internal(set) var isConnected: Bool = false
              
    public internal(set) var failureReason: String?
              
    public internal(set) var credentials: JcCredentials?
    public internal(set) var headers: Dictionary<String, String>?
              
    init(url: URL, authEndpoint: String) {

        self.endPoint = url
        self.authEndpoint = authEndpoint
    }
    
    public func connect<T>(completionHandler: @escaping (JcRequestResponse<T>) -> Void) throws -> URLSessionDataTask {
        
        throw JcConnectionFactory.ConnectionTypeNotImplementedError.type("JcSimpleConnection")
    }
}
