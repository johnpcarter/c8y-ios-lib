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
       
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
    
	/**
	Return an instance of your `C8yCustomAsset` retrieving values from the given container
	*/
    func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
       
        throw C8yCustomAssetProcessor.DecoderNotImplementedError.key(String(describing: self))
    }
}

public protocol C8ySimpleAsset: C8yCustomAsset {
		
	associatedtype ValueContent
	
	/**
	The value wrapped by the asset
	*/
	var value: ValueContent { get }
	
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
    mutating func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void
    
	/**
	Used to encode fragments to be included a `C8yManagedObject` instance that need to be uploaded to c8y
	- parameter container make a copy and encode the attributes into it before returning
	- parameter forKey attribute name of this instance, included for reference but isn't really required
	- returns Updated container including attributes from this class
	*/
    func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>
}

extension C8yCustomAsset {
	mutating public func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void {
		fatalError("decodex(container:forKey:) has not been implemented")
	}
	
	public func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
		fatalError("encodex(container:forKey:) has not been implemented")
	}
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
public struct C8yStringCustomAsset: C8ySimpleAsset {
   
	public typealias ValueContent = String
	
	public var value: String
	
	/**
	New instance wrapping giving String asset
	*/
	public init(_ value: String) {
	   self.value = value
	}
}

public struct C8yDictionaryCustomAsset: C8ySimpleAsset {
		
	public typealias ValueContent = [String:String]
	
	public var value: [String:String] = [:]
	
	public init(_ d: [String:String]) {
		self.value = d
	}
	
	init(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey key: C8yCustomAssetProcessor.AssetObjectKey) throws {
		
		let nested = try container.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: key)
		
		nested.allKeys.forEach( { key in
			do {
				self.value[key.stringValue] = try nested.decode(String.self, forKey: key)
			} catch {
				// omit non string values, sorry!!
			}
		})
	}
	
	public func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
		// TODO
		
		return container
	}
}

public struct C8yBoolCustomAsset: C8ySimpleAsset {

	public typealias ValueContent = Bool
	
	public var value: Bool
	
	/**
	New instance wrapping giving raw asset
	*/
	public init(_ value: Bool) {
	   self.value = value
	}
}

public struct C8yDoubleCustomAsset: C8ySimpleAsset {

	public typealias ValueContent = Double
	
	public var value: Double
	
	/**
	New instance wrapping giving raw asset
	*/
	public init(_ value: Double) {
	   self.value = value
	}
}
