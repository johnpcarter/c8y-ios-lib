//
//  Site.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct JcGroup {
    
    let info: JcGroupInfo
    
    init(_ obj: JcManagedObject) {
        
    }
    
    public var devices: [JcDevice] {
        get {
            
        }
    }
    
    public func childGroups(completionHandler: ([JcGroup]) -> Void) {
        
    }
}

public struct JcGroupInfo {
    
    let orgName: String
    let subName: String?
    
    let contractRef: String?
    
    let address: JcAddress?
    let siteOwner: JcContactInfo?
    let adminOwner: JcContactInfo?
    
}
