//
//  Model.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_MODEL = "xModels"

class C8yModelAssetDecoder: C8yCustomAssetDecoder {
   
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_MODEL, decoder: C8yModelAssetDecoder())
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       try C8yModels(container.decode([C8yModel].self, forKey: key))
    }
}

public struct C8yModels: C8yCustomAsset {
   
    public private(set) var models: [C8yModel] = []
    
    public init(_ models: [C8yModel]) {
        self.models = models
    }
    
    public init(from decoder: Decoder) throws {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
    public func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
       
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

public struct C8yModel: C8yCustomAsset, Hashable {
    
    public private(set) var id: String = ""
    public private(set) var name: String = ""
    public private(set) var category: C8yDeviceCategory = .Unknown
    public private(set) var link: String? = ""
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case link
    }
    
    init(_ id: String, name: String, category: C8yDeviceCategory, link: String?) {
        
        self.id = id
        self.name = name
        self.category = category
        self.link = link
        
    }
    
    public init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.link = try container.decode(String.self, forKey: .link)

        if (container.contains(.category)) {
            self.category = try C8yDeviceCategory(rawValue: container.decode(String.self, forKey: .category))!
        }
    }
    
    public static func == (lhs: C8yModel, rhs: C8yModel) -> Bool {
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
