//
//  ManagedObjects.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class JcPagedManagedObjects: Codable {
 
    let objects: [JcManagedObject]
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
        case  objects = "managedObjects"
        case statistics
    }
    
    required public init(from decoder:Decoder) throws {
       
        let values = try decoder.container(keyedBy: CodingKeys.self)
       
        objects = try values.decode([JcManagedObject].self, forKey: .objects)
        statistics = try values.decode(Statistics.self, forKey: .statistics)
    }
 
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(objects.self, forKey: .objects)
        try container.encode(statistics.self, forKey: .statistics)
    }
}
