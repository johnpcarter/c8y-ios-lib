//
//  Address.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_ADDRESS = "xGroupAddress"

class C8yAddressAssetDecoder: C8yCustomAssetFactory {
    
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_ADDRESS, decoder: C8yAddressAssetDecoder())
    }
    
    override func make() -> C8yCustomAsset {
            return C8yAddress()
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
                
        //return try container.decode(C8yAddress.self, forKey: key)
		//try address.decode(container, forKey: key)

		return try C8yAddress(container.decode(String.self, forKey: key))
    }
}

public struct C8yAddress: C8yCustomAsset {
    
    public private(set) var addressSummary: String
	
    public private(set) var addressLine1: String?
    public private(set) var city: String?
    public private(set) var postCode: String?
    public private(set) var country: String?

    enum CodingKeys : String, CodingKey {
        case addressSummary = "xGroupAddress"
		case country = "xCountry"
    }
    
	public init(_ addressSummary: String) {
		
		self.addressSummary = addressSummary
		let parts: Array<Substring> = addressSummary.split(separator: ",")
		
		parts.forEach { p in
			
			if (self.addressLine1 == nil) {
				self.addressLine1 = String(p)
			} else if (self.city == nil) {
				self.city = String(p)
			} else if (self.postCode == nil) {
				self.postCode = String(p)
			}
		}
	}
	
    public init(addressLine1: String, city: String, postCode: String, country: String) {
        
        self.addressLine1 = addressLine1
        self.city = city
        self.postCode = postCode
        self.country = country
        
		self.addressSummary = addressLine1
		
		if (!city.isEmpty) {
			self.addressSummary = self.addressSummary + ", " + city
		}
		
		if (!postCode.isEmpty) {
			self.addressSummary = self.addressSummary + ", " + postCode
		}
		
		if (!country.isEmpty) {
			self.addressSummary = self.addressSummary + ", " + country
		}
	}
    
    public init() {
        self.addressSummary = ""
    }
    
    public init(from decoder: Decoder) throws {
        
        fatalError("init(from:) has not been implemented, as is should never get called (Duh!!), should have called decode(container:forKey:)")
    }
    
    public func isDifferent(_ address: C8yAddress?) -> Bool {
            
        if (address == nil) {
            return true
        } else {
            return self.addressLine1 != address?.addressLine1 || self.city != address?.city || self.postCode != address?.postCode || self.country != address?.country
        }
    }
    
    public func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        var copy = container
        
        try copy.encode(self.addressSummary, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_ADDRESS)!)
        
        return copy
    }
    
    mutating public func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void {
        
        switch forKey.stringValue {
            case CodingKeys.addressSummary.stringValue:
                self.addressSummary = try container.decode(String.self, forKey: forKey)
                let addressBits = addressSummary.components(separatedBy: ",")
				
				if (!addressBits[0].isEmpty) {
					self.addressLine1 = addressBits[0].trimmingCharacters(in: .whitespacesAndNewlines)
				}
				
				if (addressBits.count > 1 && !addressBits[1].isEmpty) {
                    self.city = addressBits[1]
                }
            
				if (addressBits.count > 2 && !addressBits[2].isEmpty) {
                    self.postCode = addressBits[2]
                }
				
				if (addressBits[0].isEmpty) {
					self.addressSummary = ""
				}
				
            case CodingKeys.country.stringValue:
                self.country = try container.decode(String.self, forKey: forKey)
            default:
                break // do nothing
        }
    }
}
