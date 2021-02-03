//
//  ContactInfo.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_CONTACT = "xContact"

class C8yContactInfoAssetDecoder: C8yCustomAssetFactory {
    
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_CONTACT, decoder: C8yContactInfoAssetDecoder())
    }
    
    override func make() -> C8yCustomAsset {
        return C8yContactInfo()
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       try container.decode(C8yContactInfo.self, forKey: key)
    }
}

public struct C8yContactInfo: C8yCustomAsset {
    
    public var contact: String?
    public var contactPhone: String?
    public var contactEmail: String?
    
    enum CodingKeys : String, CodingKey {
        case contact = "xContactName"
        case contactPhone = "xContactPhone"
        case contactEmail = "xContactEmail"
    }
    
    public init() {
    }
    
    public init(_ contact: String, phone: String?, email: String?) {
                
        self.contact = contact
        self.contactPhone = phone
        self.contactEmail = email
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if (container.contains(.contact)) {
            self.contact = try container.decode(String.self, forKey: .contact)
        }

        if (container.contains(.contactEmail)) {
            self.contactEmail = try container.decode(String.self, forKey: .contactEmail)
        }
        
        if (container.contains(.contactPhone)) {
            self.contactPhone = try container.decode(String.self, forKey: .contactPhone)
        }
    }

    public func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        var copy = container
        
        if (self.contact != nil) {
            try copy.encode(self.contact, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: CodingKeys.contact.rawValue )!)
        }
        
        if (self.contactPhone != nil) {
            try copy.encode(self.contactPhone, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: CodingKeys.contactPhone.rawValue)!)
        }
        
        if (self.contactEmail != nil) {
            try copy.encode(self.contactEmail, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: CodingKeys.contactEmail.rawValue)!)
        }
        
        return copy
    }
    
    public mutating func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
   
        switch forKey.stringValue {
            case CodingKeys.contact.stringValue:
                self.contact = try container.decode(String.self, forKey: forKey)
            case CodingKeys.contactEmail.stringValue:
                self.contactEmail = try container.decode(String.self, forKey: forKey)
            case CodingKeys.contactPhone.stringValue:
                do {
                    self.contactPhone = try container.decode(String.self, forKey: forKey)
                } catch {
                    self.contactPhone = "\(try container.decode(Int.self, forKey: forKey))"
                }
            default:
                break
        }
    }
    
    public func isDifferent(_ contact: C8yContactInfo?) -> Bool {
    
        if (contact == nil) {
            return true
        } else {
            return self.contact != contact?.contact || self.contactEmail != contact?.contactEmail || self.contactPhone != contact?.contactPhone
        }
    }
    
}
