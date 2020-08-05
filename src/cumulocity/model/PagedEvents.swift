//
//  Events.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class JcPagedEvents: Codable {
 
    let events: [JcEvent]
    let statistics: Statistics
    
    struct Statistics: Codable {
        
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
        case  events = "events"
        case statistics
    }
    
    public required init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        events = try values.decode([JcEvent].self, forKey: .events)
        statistics = try values.decode(Statistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(events.self, forKey: .events)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
