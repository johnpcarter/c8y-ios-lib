//
//  Network.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 19/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_NETWORK_TYPE = "networkType"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER = "networkProvider"
let JC_MANAGED_OBJECT_NETWORK_INSTANCE = "lnsInstanceId"
let JC_MANAGED_OBJECT_NETWORK_EUI = "appEUI"
let JC_MANAGED_OBJECT_NETWORK_KEY = "appKey"
let JC_MANAGED_OBJECT_NETWORK_CODEC = "codec"
let JC_MANAGED_OBJECT_NETWORK_LPWAN = "c8y_LpwanDevice"

class C8yAssignedNetworkDecoder: C8yCustomAssetFactory {
    

    static func register() {
        //C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_NETWORK_TYPE, decoder: C8yAssignedNetworkDecoder())
    }
    
    override func make() -> C8yCustomAsset {
        return C8yAssignedNetwork()
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       try container.decode(C8yAssignedNetwork.self, forKey: key)
    }
}

public struct C8yAssignedNetwork: C8yCustomAsset, Equatable {
    
    public internal(set) var type: String?
    public internal(set) var provider: String?
    public internal(set) var instance: String?
    public internal(set) var appEUI: String?
    public internal(set) var appKey: String?
    public internal(set) var codec: String?

    public internal(set) var isProvisioned: Bool = false
    
	public init() {
		
	}
	
    public init(isProvisioned: Bool?) {
    
        if (isProvisioned != nil) {
            self.isProvisioned = isProvisioned!
        }
    }
    
	public init(type: String, provider: String, instance: String) {

		self.type = type
		self.provider = provider
		self.instance = instance
		self.isProvisioned = false
    }
    
    public mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
                
        switch forKey.stringValue {
        case JC_MANAGED_OBJECT_NETWORK_TYPE:
            self.type = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_PROVIDER:
            self.provider = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_INSTANCE:
            self.instance = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_EUI:
            self.appEUI = try container.decode(String.self, forKey: forKey)
            if (self.type == nil) {
                self.type = C8yNetworkType.lora.rawValue
            }
        case JC_MANAGED_OBJECT_NETWORK_KEY:
            self.appKey =  try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_CODEC:
            self.codec = try container.decode(String.self, forKey: forKey)
        case JC_MANAGED_OBJECT_NETWORK_LPWAN:
			let l = try container.nestedContainer(keyedBy: C8yManagedObject.LpwanDevice.LPWanCodingKeys.self, forKey: forKey)
            self.isProvisioned = try l.decode(Bool.self, forKey: .provisioned)
        default:
            break
        }
    }
    
    // this never gets called, refer to C8yManagedObject.encode
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        var copy = container
        
        if (self.type != nil) {
            try copy.encode(self.type, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_TYPE)!)
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
    
    public static func == (lhs: C8yAssignedNetwork, rhs: C8yAssignedNetwork) -> Bool {
        
        return lhs.type != rhs.type || lhs.provider != rhs.provider || lhs.instance != rhs.instance || lhs.appEUI != rhs.appEUI || lhs.appKey != rhs.appKey || lhs.codec != rhs.codec
    }
}
