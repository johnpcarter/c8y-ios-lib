//
//  PagedOperations.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct C8yPagedOperations: Codable {
 
    /**
     Events for current page
     */
    let operations: [C8yOperation]
    
    /**
     Paging info, to show what page these results represent, refer to `C8yPageStatistics`
     */
    let statistics: C8yPageStatistics
    
    enum CodingKeys : String, CodingKey {
        case  operations = "operations"
        case statistics
    }
    
    public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        operations = try values.decode([C8yOperation].self, forKey: .operations)
        statistics = try values.decode(C8yPageStatistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(operations.self, forKey: .operations)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
