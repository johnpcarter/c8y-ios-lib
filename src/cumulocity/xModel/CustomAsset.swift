//
//  CustomAsset.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class C8yCustomAssetDecoder {
    
    func make() throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.EncoderNotImplementedError.key(String(describing: self))
    }
    
    func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

public protocol C8yCustomAsset: Codable {
    
    /**
     * Optional 
     */
    mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void /*{
    }*/
    
    func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> /*{
        return container
    }*/
}

public class C8yStringAssetDecoder: C8yCustomAssetDecoder {
    
    override func make() throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.EncoderNotImplementedError.key(String(describing: self))
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        return try C8yStringWrapper(container.decode(String.self, forKey: key))
    }
}

public struct C8yStringWrapper: C8yCustomAsset {
   
    public var value: String
    
    public init(_ value: String) {
       self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    public mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        fatalError("init(from:) has not been implemented")
    }
    
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        fatalError("init(from:) has not been implemented")
    }
}
