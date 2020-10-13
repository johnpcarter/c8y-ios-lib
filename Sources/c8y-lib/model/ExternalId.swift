//
//  ExternalId.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

/**
 Wrapper for external id's that are used to reference `C8yManagedObject`
 */
public struct C8yExternalIds: JcEncodableContent {
    
    /**
     List of external id's and their types for a `C8yManagedObject`
     */
    let externalIds: [C8yExternalId]
    
    enum CodingKeys : String, CodingKey {
        case externalIds
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.externalIds = try container.decode([C8yExternalId].self, forKey: .externalIds)
    }
}

/**
 Represents an external id for a `C8yManagedObject` e.g. 'c8y_Serial' or 'c8y_LoRa_DevEUI'
 */
public struct C8yExternalId: JcEncodableContent, Identifiable {
    
    /**
     Internal id of the associated Managed Object `C8yManagedObject`
     */
    public let id: String?
    
    /**
     Label identifying the type of external id .e.g.'c8y_Serial' or 'c8y_LoRa_DevEUI'
     */
    public let type: String
    
    /**
     The external id itself
     */
    public internal(set) var externalId: String
    
    enum CodingKeys : String, CodingKey {
        case type
        case externalId
        case managedObject
    }
    
    enum ManagedObjectCodingKeys : String, CodingKey {
        case id
        case ref = "self"
    }
    
    /**
     Define a new external id
     */
    public init(withExternalId: String, ofType: String) {
                
        self.id = nil
        self.type = ofType
        self.externalId = withExternalId
    }
    
    public init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.type = try container.decode(String.self, forKey: .type)
        self.externalId = try container.decode(String.self, forKey: .externalId)
        
        let nestedContainer = try container.nestedContainer(keyedBy: ManagedObjectCodingKeys.self, forKey: .managedObject)
        self.id = try nestedContainer.decode(String.self, forKey: .id)
    
    }
    
    mutating func update(externalId id :String) {
        self.externalId = id
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(type, forKey: .type)
        try container.encode(externalId, forKey: .externalId)
    }
}
