//
//  C8yCumulocityUser.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Wraps a c8y UserProfile, refer to [c8y API Reference guid](https://cumulocity.com/guides/reference/users/#user) for more info
 */
public struct C8yCumulocityUser: Codable {
            
    public private(set) var userName: String
    
    public private(set) var lastName: String?
    public private(set) var firstName: String?
    public private(set) var email: String?
    
    enum CodingKeys : String, CodingKey {

        case userName
        case lastName
        case firstName
        case email
    }
}
