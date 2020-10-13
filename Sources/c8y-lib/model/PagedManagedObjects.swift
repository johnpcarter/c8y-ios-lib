//
//  ManagedObjects.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Results from `C8yManagedObjectService` request
 
 */
public struct C8yPagedManagedObjects: Codable {
 
    /**
     The wrapped objects, limited by page size
     */
    public let objects: [C8yManagedObject]
    
    /**
     Paging info, to show what page these results represent, refer to `C8yPageStatistics`
     */
    public let statistics: C8yPageStatistics
    
    enum CodingKeys : String, CodingKey {
        case objects = "managedObjects"
        case statistics
    }
    
    public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        objects = try values.decode([C8yManagedObject].self, forKey: .objects)
        statistics = try values.decode(C8yPageStatistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.objects, forKey: .objects)
    }
}
