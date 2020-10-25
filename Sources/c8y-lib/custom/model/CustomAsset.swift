//
//  CustomAsset.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
Abstract factory class, override implementation to return appropriate sub class of `C8yCustomAsset`
*/
public class C8yCustomAssetFactory {
    
	/**
	Return an instance of your `C8yCustomAsset`
	*/
    func make() throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.EncoderNotImplementedError.key(String(describing: self))
    }
    
	/**
	Return an instance of your `C8yCustomAsset` retrieving values from the given container
	*/
    func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

/**
Your custom asset Struct must implement the following methods in order that it can decoded/encoded as a JSON fragment from the c8y ManageObject
*/
public protocol C8yCustomAsset: Codable {
    
    /**
	Optional, used to decode fragments fetched from c8y in `C8yManagedObject` instances
	- parameter container contains the attributes to be retrieved and represented by the implementation of this protocol
	- parameter forKey attribute name of this instance, included for reference but isn't really required unless decoding attributes from parent structure into common asset (See `Address` or `Planning` examples)
     */
    mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void
    
	/**
	Used to encode fragments to be included a `C8yManagedObject` instance that need to be uploaded to c8y
	- parameter container make a copy and encode the attributes into it before returning
	- parameter forKey attribute name of this instance, included for reference but isn't really required
	- returns Updated container including attributes from this class
	*/
    func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>
}

/**
Concrete implementation of `C8yCustomAssetFactory` to manage custom string attributes in your managed object
*/
public class C8yStringAssetDecoder: C8yCustomAssetFactory {
    
    override func make() throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.EncoderNotImplementedError.key(String(describing: self))
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        return try C8yStringCustomAsset(container.decode(String.self, forKey: key))
    }
}

/**
Concrete implementation of `C8yCustomAsset` to encode a string based custom asset
*/
public struct C8yStringCustomAsset: C8yCustomAsset {
   
    public var value: String
    
	/**
	New instance wrapping giving String asset
	*/
    public init(_ value: String) {
       self.value = value
    }
    
	/**
	Not used
	*/
    public init(from decoder: Decoder) throws {
        fatalError("init(from:) has not been implemented")
    }
    
	/**
	Not used
	*/
    public mutating func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        fatalError("init(from:) has not been implemented")
    }
    
	/**
	Not used
	*/
    public func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        fatalError("init(from:) has not been implemented")
    }
}
