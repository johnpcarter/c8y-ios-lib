//
//  Alarms.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class JcPagedAlarms: Codable {
 
    let alarms: [JcAlarm]
    let statistics: Statistics
    
    public struct Statistics: Codable {
        
        let currentPage: Int
        let pageSize: Int
        let totalPages: Int
        
        enum CodingKeys : String, CodingKey {
            case currentPage
            case pageSize
            case totalPages
        }
    }
    
    enum CodingKeys : String, CodingKey {
        case  alarms
        case statistics
    }
    
    public required init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        alarms = try values.decode([JcAlarm].self, forKey: .alarms)
        statistics = try values.decode(Statistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(alarms.self, forKey: .alarms)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
