//
//  JcCumulocityUser.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

class JcCumulocityUser: JcConnectionAccountInfo {
        
    private var _c8yUser: c8y_User
    
    public var user: String {
        get {
            return _c8yUser.userName
        }
    }
    
    public var lastName: String? {
        get {
            return _c8yUser.lastName
        }
    }
    
    public var firstName: String? {
        get {
            return _c8yUser.firstName
        }
    }
    
    public var alias: String? {
        get {
            return _c8yUser.userName
        }
    }
    
    public var emailAddress: String? {
        get {
            return _c8yUser.email
        }
    }
    
    public var phoneNumber: String? {
        get {
            return nil
        }
    }

    init(_ json: Data) {
        
        _c8yUser = try! JSONDecoder().decode(c8y_User.self, from: json)
    }
    
    init(user: String, lastName: String?, firstName: String?, alias: String?, emailAddress: String?, phoneNumber: String?) {
        
        _c8yUser = c8y_User(userName: user, firstName: firstName, lastName: lastName, email: emailAddress)
    }
    
    struct c8y_User: Codable {
    
        var id: String?
        var userName: String
        
        var firstName: String?
        var lastName: String?
        var email: String?
        
        init(userName: String, firstName: String?, lastName: String?, email: String?) {
            
            self.userName = userName
            self.firstName = firstName
            self.lastName = lastName
            self.email = email
        }
    }
}
