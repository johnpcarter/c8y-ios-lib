//
//  CustomAsset.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class C8yCustomAssetFactory {
    
    func make() throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.EncoderNotImplementedError.key(String(describing: self))
    }
    
    func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

public protocol C8yCustomAsset: Codable {
    
    /**
	Optional, used to decode fragments fetched from c8y in `C8yManagedObject` instances
	- parameter container contains the attributes to be retrieved and represented by the implementation of this protocol
	- parameter forKey attribute name of this instance, included for reference but isn't really required unless decoding attributes from parent structure into common asset (See `Address` or `Planning` examples)
     */
    mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void /*{
    }*/
    
	/**
	Used to encode fragments to be included a `C8yManagedObject` instance that need to be uploaded to c8y
	- parameter container make a copy and encode the attributes into it before returning
	- parameter forKey attribute name of this instance, included for reference but isn't really required
	- returns Updated container including attributes from this class
	*/
    func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> /*{
        return container
    }*/
}

public class C8yStringAssetDecoder: C8yCustomAssetFactory {
    
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
