//
//  PagedMeasurements.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 List of paged measurements returned from `C8yMeasurementsService`
 */
public struct C8yPagedMeasurements: JcEncodableContent {
 
    /**
     measurements for current page
     */
    let measurements: [C8yMeasurement]
    
    /**
     Paging info, to show what page these results represent, refer to `C8yPageStatistics`
     */
    let statistics: C8yPageStatistics?
    
    enum CodingKeys : String, CodingKey {
        case  measurements
        case statistics
    }
    
    public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        measurements = try values.decode([C8yMeasurement].self, forKey: .measurements)
        statistics = try values.decode(C8yPageStatistics.self, forKey: .statistics)
    }
 
    public init(_ measurements: [C8yMeasurement]) {
    
        self.measurements = measurements
        self.statistics = nil
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(measurements.self, forKey: .measurements)
    }
}
