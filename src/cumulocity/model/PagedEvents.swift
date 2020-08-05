//
//  Events.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
Results from `C8yEventsService` request

*/
public struct C8yPagedEvents: Codable {
 
    /**
     Events for current page
     */
    let events: [C8yEvent]
    
    /**
     Paging info, to show what page these results represent, refer to `C8yPageStatistics`
     */
    let statistics: C8yPageStatistics
    
    enum CodingKeys : String, CodingKey {
        case  events = "events"
        case statistics
    }
    
    public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        events = try values.decode([C8yEvent].self, forKey: .events)
        statistics = try values.decode(C8yPageStatistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(events.self, forKey: .events)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
