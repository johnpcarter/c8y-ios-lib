//
//  Supplier.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct C8ySupplier: Hashable {
       
    public private(set) var name: String = ""
	public private(set) var description: String = ""
	public private(set) var site: String?

	public var models: [String:String] = [:]

    enum CodingKeys: String, CodingKey {
        case name
		case description = "c8y_Notes"
		case models
		case site
    }
    
	init(_ object: C8yManagedObject) {
		
		self.name = object.name!
		self.description = object.notes ?? ""
		self.models = (object.properties["models"] as! C8yDictionaryCustomAsset).value
	}
	
	public init(name: String, description: String, site: String?) {
        
        self.name = name
        self.description = description
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
		self.description = try container.decode(String.self, forKey: .description)
		self.models = try container.decode([String:String].self, forKey: .models)
		
		if (container.contains(.site)) {
			self.site = try container.decode(String.self, forKey: .site)
		}
    }
    
    public static func == (lhs: C8ySupplier, rhs: C8ySupplier) -> Bool {
        return lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        
        hasher.combine(self.name.hashValue)
    }
}
