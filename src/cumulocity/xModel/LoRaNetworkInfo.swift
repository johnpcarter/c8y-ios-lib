//
//  LoRaNetworkInfo.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let CY_LORA_NETWORK = "lora_ns_LNSProxyRepresentation"
let CY_LORA_NETWORK_TYPE_ID = "lnsId"

class C8yLoRaNetworkInfoAssetDecoder: C8yCustomAssetDecoder {
    
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: CY_LORA_NETWORK, decoder: C8yLoRaNetworkInfoAssetDecoder())
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: CY_LORA_NETWORK_TYPE_ID, decoder: C8yStringAssetDecoder())

    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       try container.decode(C8yLoRaNetworkInfo.self, forKey: key)
    }
}

public struct C8yLoRaNetworkInfo: C8yCustomAsset {
        
    public let id: String
    public let name: String
    public let version: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case version
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.version = try container.decode(String.self, forKey: .version)
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("encode(to:) has not been implemented, as is should never get called (Duh!!)")
    }
    
    public func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}
    
