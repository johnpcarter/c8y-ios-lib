//
//  Alarms.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
Results from `C8yAlarmsService` request

*/
public struct C8yPagedAlarms: Codable {
 
    /**
     Alarms for current page
     */
    let alarms: [C8yAlarm]
    
    /**
     Paging info, to show what page these results represent, refer to `C8yPageStatistics`
     */
    let statistics: C8yPageStatistics
    
    enum CodingKeys : String, CodingKey {
        case  alarms
        case statistics
    }
    
    public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        alarms = try values.decode([C8yAlarm].self, forKey: .alarms)
        statistics = try values.decode(C8yPageStatistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(alarms.self, forKey: .alarms)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
