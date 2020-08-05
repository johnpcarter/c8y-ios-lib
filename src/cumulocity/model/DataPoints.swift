//
//  DataPoint.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let C8Y_MANAGED_OBJECT_DATA_POINTS = "c8y_DataPoint"

struct JcDataPoints: Codable {

    struct JcDataPointKey : CodingKey {
      
        var stringValue: String
      
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
      
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }

        static let value = JcDataPointKey(stringValue: "value")!
    }
    
    struct JcDataPoint: Codable {
        
        let reference: String
        let value: JcDataPointValue
    }
   
    let dataPoints: [JcDataPoint]
    
    init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: JcDataPointKey.self)

        var values: [JcDataPoint] = []
        
        for key in container.allKeys {
            
            let nested = try container.nestedContainer(keyedBy: JcDataPointKey.self, forKey: key)
            
            let value = try nested.decode(JcDataPointValue.self, forKey: .value)
            values.append(JcDataPoint(reference: key.stringValue, value: value))
        }

        self.dataPoints = values
    }
    
    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: JcDataPointKey.self)
        
        for style in dataPoints {
            let key = JcDataPointKey(stringValue: style.reference)!
            var nested = container.nestedContainer(keyedBy: JcDataPointKey.self, forKey: key)
            try nested.encode(style.value, forKey: .value)
        }
    }
}

struct JcDataPointValue: Codable {

    let id: String?
    
    var fragment: String
    var unit: String
    var color: String // rgb e.g. #ffffff
    var series: String
    var  lineType: String
    var label: String
    var renderType: String
    
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
