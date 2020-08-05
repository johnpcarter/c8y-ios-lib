//
//  Measurement.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
Represents an c8y event, refer to [c8y API Reference Guide](https://cumulocity.com/guides/reference/measurements/#measurement) for more info
*/
public struct C8yMeasurement: Codable {
    
    public private(set) var id: String?
    
    public private(set) var source: String
    public private(set) var type: String?
    public private(set) var time: Date
    
    public private(set) var measurements: Dictionary<String, [MeasurementValue]>?
    
    enum SourceCodingKeys: String, CodingKey {
        
        case id
    }
    
    public init(fromSource source: String, type: String) {
    
        self.source = source
        self.type = type
        self.time = Date()
        
        self.measurements = [:]
    }
    
    public init(from decoder:Decoder) throws {
        
        let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        self.source = ""
        self.time = Date()
        self.measurements = [:]
        
        for (key) in values.allKeys {
            
            switch (key.stringValue) {
            case "id":
                self.id = try values.decode(String.self, forKey: key)
            case "time":
                self.time = try values.decode(Date.self, forKey: key)
            case "type":
                self.type = try values.decode(String.self, forKey: key)
            case "source":
                self.source = try C8yMeasurement.getIdFromSourceContainer(key, container: values)
            case "self":
                break
            default:
                try addValues(key, container: values)
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)

        try container.encode(self.type, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "type")!)
        try container.encode(self.time, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "time")!)
        
        var nestedContainer = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey:  C8yCustomAssetProcessor.AssetObjectKey(stringValue: "source")!)
        try nestedContainer.encode(self.source, forKey: .id)
        
        if (measurements != nil) {
            for (k,l) in measurements! {
                
                var nestedContainer = container.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: k)!)
                
                for (v) in l {
                    try nestedContainer.encode(v, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: v.label)!)
                }
            }
        }
    }
    
    public mutating func addValues(_ values: [MeasurementValue], forType type: String) {
        
        self.measurements![type] = values
    }
    
    private mutating func addValues(_ key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws {
        
        let nestedContainer = try container.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: key)
        
        var vals: [MeasurementValue] = []
        for (k) in nestedContainer.allKeys {
            vals.append(try MeasurementValue(forKey: k, inContainer: nestedContainer.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: k)))
        }
        
        measurements![key.stringValue] = vals //try container.decode(MeasurementValue.self, forKey: key)
    }
    
    private static func getIdFromSourceContainer(_ key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> String {
            
        return try container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: key).decode(String.self, forKey: .id)
    }
    
    func toJsonString() -> Data {

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
           
        return try! encoder.encode(self)
    }
       
    /**
     A specific measurable value including a human readable label and unit of measure
     */
    public struct MeasurementValue: Encodable {
                
        public let label: String
        public let value: Double
        public let unit: String?

        enum CodingKeys: String, CodingKey {
            case value
            case unit
        }
        
        init(forKey key: C8yCustomAssetProcessor.AssetObjectKey, inContainer container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws {
            
            self.label = key.stringValue
            self.value = try container.decode(Double.self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "value")!)

            if (container.contains(C8yCustomAssetProcessor.AssetObjectKey(stringValue: "unit")!)) {
                self.unit = try container.decode(String.self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "unit")!)
            } else {
                self.unit = nil
            }
        }
        
        public init(_ value: Double, unit: String, withLabel label: String) {
            
            self.label = label
            self.value = value
            self.unit = unit
        }
    }
}

