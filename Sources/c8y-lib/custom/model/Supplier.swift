//
//  Supplier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_SUPPLIER = "xSuppliers"

class C8ySupplierAssetDecoder: C8yCustomAssetFactory {
   
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_SUPPLIER, decoder: C8ySupplierAssetDecoder())
    }
    
    override func make(key:C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        try C8ySuppliers(container.decode([C8ySupplier].self, forKey: key))
    }
}

public struct C8ySuppliers: C8yCustomAsset {
    
    public private(set) var suppliers: [C8ySupplier] = []
    
    init(_ suppliers: [C8ySupplier]) {
        self.suppliers = suppliers
    }
    
    public init(from decoder: Decoder) throws {
        // TODO: Implement
        
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
    public func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

public struct C8ySupplier: C8yCustomAsset, Hashable {
       
    public private(set) var id: String = ""
    public private(set) var name: String = ""
    public private(set) var networkType: String? = ""
    public private(set) var site: String? = ""
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case networkType
        case site
    }
    
    init(_ id: String, name: String, networkType: String?, site: String?) {
        
        self.id = id
        self.name = name
        self.networkType = networkType
        self.site = site
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.networkType = try container.decode(String.self, forKey: .networkType)
        self.site = try container.decode(String.self, forKey: .site)
    }
    
    public static func == (lhs: C8ySupplier, rhs: C8ySupplier) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        
        hasher.combine(self.id.hashValue)
    }
    
    public func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}
