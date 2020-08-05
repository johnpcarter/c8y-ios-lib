//
//  JcCumulocityConnection.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

class JcCumulocityConnection : JcSimpleConnection<JcCumulocityUser> {
        
    override func connect(completionHandler: @escaping (JcRequestResponse<JcCumulocityUser>) -> Void) -> URLSessionDataTask {
        
        return Authenticator(self).get { (response: JcRequestResponse<JcCumulocityUser>) in
        
            self.isConnected = response.status == 200 || response.status == 201
            
            completionHandler(response)
        }
    }
    
    private class Authenticator: JcConnectionRequest<JcCumulocityUser> {
        
        override func parseResponse<ResponseContent>(_ data: Data) -> ResponseContent {
            
            return JcCumulocityUser(data) as! ResponseContent
        }
    }
}
