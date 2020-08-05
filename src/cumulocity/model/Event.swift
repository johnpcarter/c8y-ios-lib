//
//  Event.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let C8yLocationUpdate_EVENT = "c8y_LocationUpdate"

/**
Represents an c8y event, refer to [c8y API Reference Guide](https://cumulocity.com/guides/reference/events/#event) for more info
*/
public struct C8yEvent: JcEncodableContent, Identifiable {
    
    public private (set) var id: String?
    
    public private (set) var source: String
    public private (set) var type: String?
    public private (set) var time: Date
    public private (set) var text: String

    public private (set) var creationTime: Date?
    public private (set) var eventDecodeError: String?
    
    public private (set) var position: C8yManagedObject.Position?
    
    public private (set) var info: Dictionary<String, C8yCustomAsset>?
    
    enum SourceCodingKeys: String, CodingKey {
        
        case id
    }
    
    public init(forSource: String, type: String, text: String) {
    
        self.source = forSource
        self.time = Date()
        self.type = type
        self.text = text
    }
    
    public init(forSource: String, position: C8yManagedObject.Position) {
    
        self.source = forSource
        self.time = Date()
        self.type = C8yLocationUpdate_EVENT
        self.text = "Location Change"
        
        self.position = position
    }
    
    public init(forSource: String, type: String, text: String, eventObject: C8yCustomAsset) {
        
        self.source = forSource
        self.time = Date()
        self.type = type
        self.text = text
        
        self.info = Dictionary()
        self.info![type] = eventObject
    }
    
    public init(from decoder:Decoder) throws {
        
        let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        self.source = ""
        self.time = Date()
        self.text = ""
        
        for (key) in values.allKeys {
            
            switch (key.stringValue) {
            case "id":
                self.id = try values.decode(String.self, forKey: key)
            case "time":
                self.time = try values.decode(Date.self, forKey: key)
            case "creationTime":
                self.creationTime = try values.decode(Date.self, forKey: key)
            case "type":
                self.type = try values.decode(String.self, forKey: key)
            case "text":
                self.text = try values.decode(String.self, forKey: key)
            case "source":
                self.source = try C8yEvent.getIdFromSourceContainer(key, container: values)
            case "self":
                break
            case C8yLocationUpdate_EVENT:
                self.position = try values.decode(C8yManagedObject.Position.self, forKey: key)
            default:
                if (self.info == nil) {
                    self.info = Dictionary()
                }
                
                do {
                    self.info![key.stringValue] = try C8yCustomAssetProcessor.decode(key, container: values)
                } catch {
                    // failed
                    eventDecodeError = error.localizedDescription
                }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)

        var nestedContainer = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "source")!)
        try nestedContainer.encode(self.source, forKey: .id)
        
        try container.encode(self.type, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "type")!)
        try container.encode(self.time, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "time")!)
        try container.encode(self.text, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "text")!)

        if (self.position != nil) {
            try container.encode(self.position, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: C8yLocationUpdate_EVENT)!)
        }
        
        if (info != nil) {
            for (k,v) in info! {
                
                if (v is C8yStringWrapper) {
                    try container.encode((v as! C8yStringWrapper).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue:k)!)
                } else {
                    _ = try v.encode(container, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: k)!)
                }
                
                //try container.encode(v, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: k)!)
            }
        }
    }
    
    func toJsonString() -> Data {

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        return try! encoder.encode(self)
    }
    
    mutating func updateId(_ id: String) {
        self.id = id
    }
    
    private static func getIdFromSourceContainer(_ key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> String {
            
        return try container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: key).decode(String.self, forKey: .id)
    }
}

