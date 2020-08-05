//
//  C8yCumulocityConnection.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_AUTH_USERPROFILE_API = "/user/currentUser"

/**
 Represents a *stateless* connection to a Cumulocity tenant/instance
 */
public class C8yCumulocityConnection : JcSimpleConnection {
        
    /**
     Establishes a connection to be used for the given c8y tenant and instance
     
     - parameter tenant: The name of your c8y tenant (you can find it at the beginning of your url in the web browser after logging in e.g. https://#tenant#.cumulocity.com/..'
     - parameter instance: The name of your c8y instance to use. Instances are provided for different regions e.g. 'cumulocity.com' or 'eu-cumulocity.com' etc.
     */
    public init(tenant: String, server: String) {
        
        super.init(url: URL(string: String(format: "https://%@.%@", tenant, server))!, authEndpoint: C8Y_AUTH_USERPROFILE_API)
    }
    
    /**
     Will attempt to check the given credentials calling your callback with the results
     - parameter user: User id to be used to authenticate
     - parameter password: plain text password to be used to authenticate
     - parameter completionHandler your call back function that will be invoked with the results
     - returns: Http session task used to invoke request
     */
    public func connect(user: String, password: String) -> AnyPublisher<JcRequestResponse<C8yCumulocityUser>, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
       
        self.credentials = JcCredentials(basicAuthorisation: user, password: password)
        
        return Authenticator(self).connect().tryMap { (response) in

            self.isConnected = response.httpStatus == 200 || response.httpStatus == 201

            return try JcRequestResponse<C8yCumulocityUser>(response, dateFormatter: nil)
        }.mapError({ error -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
            switch (error) {
            case let error as JcConnectionRequest<C8yCumulocityConnection>.APIError:
                return error
            default:
                return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: error.localizedDescription)
            }
        }).eraseToAnyPublisher()
    }
    
    class Authenticator: JcConnectionRequest<C8yCumulocityConnection> {
                    
        func connect() -> AnyPublisher<JcRequestResponse<Data>, APIError> {
        
            C8yCustomAssetProcessor.registerDefaultExtensions()

            return super._get(resourcePath: C8Y_AUTH_USERPROFILE_API).eraseToAnyPublisher()
        }
    }
}
