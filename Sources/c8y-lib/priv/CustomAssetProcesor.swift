//
//  CustomAssetProcesor.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct C8yCustomAssetProcessor {

    // dynamic version of enum CodingKeys
    public struct AssetObjectKey : CodingKey {
         
        public var stringValue: String
         
        public init?(stringValue: String) {
            self.stringValue = stringValue
        }
         
        public var intValue: Int? { return nil }
        public init?(intValue: Int) { return nil }

        // this represents the sub-element, referenced by an intermediary dynamic value
        static let value = AssetObjectKey(stringValue: "value")!
    }
    
    // JC CUSTOM FIELDS
   
    static var _customPropertyCodable: Dictionary<String, C8yCustomAssetFactory> = Dictionary()
   
    static func registerDefaultExtensions() {
        C8yPlanningAssetDecoder.register()
        C8yAddressAssetDecoder.register()
        C8yContactInfoAssetDecoder.register()
        C8yLoRaNetworkInfoAssetDecoder.register()
        C8yAssignedNetworkDecoder.register()
        C8ySupplierAssetDecoder.register()
        C8yModelAssetDecoder.register()
    }
   
    public static func registerCustomPropertyClass(property: String, decoder: C8yCustomAssetFactory) {
       
       _customPropertyCodable[property] = decoder
    }
    
    enum EncoderNotImplementedError: Error {
        case key(_ key: String)
    }
    
    enum DecoderNotImplementedError: Error {
        case key(_ key: String)
    }
    
    static func decode(_ key: AssetObjectKey, container: KeyedDecodingContainer<AssetObjectKey>) throws -> C8yCustomAsset {
    
        if (C8yCustomAssetProcessor._customPropertyCodable[key.stringValue] == nil) {
            
            throw DecoderNotImplementedError.key(key.stringValue)
        } else {
            return try C8yCustomAssetProcessor._customPropertyCodable[key.stringValue]!.make(key: key, container: container)
        }
    }
    
    static func decode(key: AssetObjectKey, container: KeyedDecodingContainer<AssetObjectKey>, propertiesHolder: Dictionary<String, C8yCustomAsset>) throws -> Dictionary<String, C8yCustomAsset> {
            
        var properties = propertiesHolder
        
        if (C8yCustomAssetProcessor._customPropertyCodable.keys.contains(key.stringValue)) {
            
            // custom class for sub-structure
            
            properties[key.stringValue] = try C8yCustomAssetProcessor.decode(key, container: container)
        
        } else if (key.stringValue.hasPrefix("x")) {
                
            // may have a custom class for simple attributes in top-level starting with some kind of prefix preceded by "x"
            // e.g. xPlanningName xPlanningDate could be associated with a custom class xPlanning with attributes name and date
                
            var done: Bool = false
            
            for (pk, pv) in C8yCustomAssetProcessor._customPropertyCodable {
                
                if (key.stringValue.hasPrefix(pk)) {
                           
                    // got one, however check if we have already created it, remember potentially may have more than one attribute
                    if (properties[pk] == nil) {
                        properties[pk] = try pv.make()
                    }
                    
                    try properties[pk]?.decode(container, forKey: key)
                    
                    done = true
                    break
                }
            }
               
            // no specify class to decode, so just decode as simple string(s) into properties
            
            if (!done) {
                do {
                    let v: String = try container.decode(String.self, forKey: key)
                    properties[key.stringValue] = C8yStringCustomAsset(v)
                } catch {
                    // h'mm it's not a String, need to flatten it
                 
                    self.flatten(key: key, container: container, propertiesHolder: properties)
                }
            }
        }
        
        return properties
    }
        
    private static func flatten(key: AssetObjectKey, container: KeyedDecodingContainer<AssetObjectKey>, propertiesHolder: Dictionary<String, C8yCustomAsset>) -> Void {
            
        self._flatten(key: key, container: container, path: key.stringValue, propertiesHolder: propertiesHolder)
    }
        
    private static func _flatten(key: AssetObjectKey, container: KeyedDecodingContainer<AssetObjectKey>, path: String, propertiesHolder: Dictionary<String, C8yCustomAsset>) -> Void {
            
        var properties = propertiesHolder

        do {
            let nested = try container.nestedContainer(keyedBy: AssetObjectKey.self, forKey: key)
            
            for nkey in nested.allKeys {
            
                var nKeyPath = path
                       
                if (nKeyPath.count > 0) {
                    nKeyPath = String(format: "%@.%@", path, nkey.stringValue)
                } else {
                    nKeyPath = nkey.stringValue
                }
                
                do {
                    let v: String = try nested.decode(String.self, forKey: nkey)
                    properties[nKeyPath] = C8yStringCustomAsset(v)
                } catch {
                    // h'mm it's not a String, need to flatten it again
                 
                    self._flatten(key: nkey, container: nested, path: nKeyPath, propertiesHolder: properties)
                }
            }
        }
        catch {
            // ignore it
        
        }
    }
}
