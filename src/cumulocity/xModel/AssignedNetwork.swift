//
//  Network.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 19/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_NETWORK = "networkType"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER = "networkProvider"
let JC_MANAGED_OBJECT_NETWORK_INSTANCE = "lnsInstanceId"
let JC_MANAGED_OBJECT_NETWORK_EUI = "appEUI"
let JC_MANAGED_OBJECT_NETWORK_KEY = "appKey"
let JC_MANAGED_OBJECT_NETWORK_CODEC = "codec"
let JC_MANAGED_OBJECT_NETWORK_LPWAN = "c8y_LpwanDevice"

class C8yNetworkDecoder: C8yCustomAssetDecoder {
    
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_NETWORK, decoder: C8yNetworkDecoder())
    }
    
    override func make() -> C8yCustomAsset {
        return C8yNetwork()
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       try container.decode(C8yNetwork.self, forKey: key)
    }
}

public struct C8yNetwork: C8yCustomAsset {
    
    public private(set) var type: String?
    public private(set) var provider: String
    public private(set) var instance: String
    public private(set) var appEUI: String?
    public private(set) var appKey: String?
    public private(set) var codec: String?

    public mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        
        switch forKey.stringValue {
        case JC_MANAGED_OBJECT_NETWORK:
            self.type = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_PROVIDER:
            self.provider = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_INSTANCE:
            self.instance = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_EUI:
            self.appEUI =  try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_KEY:
            self.appKey =  try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_CODEC:
            self.codec = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_LPWAN:
            let lpc = container.nestedContainer()
        default:
            break
        }
    }
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        var copy = container
        
        if (self.type != nil) {
            try copy.encode(self.type, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK)!)
        }
        
        if (self.provider != nil) {
            try copy.encode(self.provider, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_PROVIDER)!)
        }

        if (self.instance != nil) {
            try copy.encode(self.instance, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_INSTANCE)!)
        }
        
        if (self.appEUI != nil) {
            try copy.encode(self.appEUI, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_EUI)!)
        }
        
        if (self.appKey != nil) {
            try copy.encode(self.appKey, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_KEY)!)
        }
        
        if (self.codec != nil) {
            try copy.encode(self.codec, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_CODEC)!)
        }
        
        return copy
    }
}
