//
//  MeasurementSeries.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Collated list of measurement for a specific series [c8y API Reference Guide](https://cumulocity.com/guides/reference/measurements/#measurement-collection)
 */
public struct C8yMeasurementSeries: JcEncodableContent {
    
    /**
     Specifies how the measurements results to be grouped, by minute, hour or 24 hours (DAILY)
     */
    public enum AggregateType: String {
        case DAILY
        case HOURLY
        case MINUTELY
    }
    
    public private(set) var series: [Series]
    public private(set) var values: [ValuesWrapper]
    
    enum CodingKeys: String, CodingKey {
        
        case series
        case values
    }
    
    public init(from decoder:Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.series = try container.decode([Series].self, forKey: .series)

        let valuesAtTime = try container.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: .values)

        var unorderedValues: [ValuesWrapper] = []
        
        for (key) in valuesAtTime.allKeys {
            let vals = try valuesAtTime.decode([Values].self, forKey: key)
            
            unorderedValues.append(ValuesWrapper(forTime: C8yManagedObject.dateFormatter().date(from: key.stringValue)!, andValues: vals))
        }
        
        self.values = unorderedValues.sorted(by: { (v1, v2) in
            return v1.time.compare(v2.time) == .orderedAscending
        })
    }
    
    public func encode(to encoder: Encoder) throws {
        
    }
    
    public struct Series: Decodable {
        
        public let name: String
        public let unit: String
        public let type: String
    }
    
    public struct ValuesWrapper {
    
        public private(set) var time: Date
        public let values: [Values]
        
        init(forTime: Date, andValues: [Values]) {
            
            self.time = forTime
            self.values = andValues
        }
    }
    
    public struct Values: Decodable {
        
        public let min: Double
        public let max: Double
    }
}

