//
//  ContactInfo.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_CONTACT = "xContact"

class JcContactInfoAssetDecoder: JcCustomAssetDecoder<JcContactInfo> {
    
    static func register() {
        JcCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_CONTACT, decoder: JcContactInfoAssetDecoder())
    }
    
    override func make(key: JcCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<JcCustomAssetProcessor.AssetObjectKey>) throws -> JcContactInfo {
       try container.decode(JcContactInfo.self, forKey: key)
    }
}

class JcContactInfo: JcCustomAsset {
    
    var contact: String?
    var contactPhone: String?
    var contactEmail: String?
    
    enum CodingKeys : String, CodingKey {
        case contact = "xContactName"
        case contactPhone = "xContactPhone"
        case contactEmail = "xContactEmail"
    }
}
