//
//  DataPoint.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let C8Y_MANAGED_OBJECT_DATA_POINTS = "c8y_DataPoint"

public struct C8yDataPoints: Codable {

    public let dataPoints: [DataPoint]
    
    public struct DataPoint: Codable {
        
        public let reference: String
        public let value: DataPointValue
    }
    
    public struct DataPointValue: Codable {

        private(set) var id: String?
        
        public var fragment: String
        public var unit: String
        public var color: String // rgb e.g. #ffffff
        public var series: String
        public var  lineType: String
        public var label: String
        public var renderType: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case fragment
            case unit
            case color // rgb e.g. #ffffff
            case series
            case lineType
            case label
            case renderType
        }
    }
    
    // dynamic version of enum CodingKeys
    struct DataPointKey : CodingKey {
      
        var stringValue: String
      
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
      
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }

        // this represents the sub-element, referenced by an intermediary dynamic value
        static let value = DataPointKey(stringValue: "value")!
    }
    
    public init() {
        self.dataPoints = []
    }
    
    public init(_ reference: String, series: String, unit: String, color: String, label: String) {
        
        self.dataPoints = [DataPoint(reference: reference, value: DataPointValue(id: nil, fragment: series, unit:  unit, color: color, series: series, lineType: "thin", label: label, renderType: "line"))]
    }
    
    public init(from decoder: Decoder) throws {
        
        do {
            let container = try decoder.container(keyedBy: DataPointKey.self)

            var values: [DataPoint] = []
            
            for key in container.allKeys {
                            
                let value = try container.decode(DataPointValue.self, forKey: key)
                values.append(DataPoint(reference: key.stringValue, value: value))
            }

            self.dataPoints = values
        } catch {
            // assume error is because we have an empty structure, just ignore it
            self.dataPoints = []
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: DataPointKey.self)
        
        for d in dataPoints {
            let key = DataPointKey(stringValue: d.reference)!
            try container.encode(d.value, forKey: key)
            //var nested = container.nestedContainer(keyedBy: DataPointKey.self, forKey: key)
            //try nested.encode(d.value, forKey: .value)
        }
    }
}
