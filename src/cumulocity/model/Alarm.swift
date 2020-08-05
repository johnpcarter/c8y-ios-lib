//
//  C8yAlarm.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Represents an c8y alarm, refer to [c8y API Reference Guide](https://cumulocity.com/guides/reference/alarms/#alarm) for more info
 */
public struct C8yAlarm: JcEncodableContent, Identifiable {

    public enum Status: String, Codable {
         /** Alarm is currently live and has not yet been resolved
         */
        case ACTIVE

        /**
         * Alarm is still active, but has been acknowledged by someone
         */
        case ACKNOWLEDGED

        /**
         * Alarm has been resolved, is visible only for monitoring reasons
         */
        case CLEARED
    }

    /**
     * Allowed values for Alarm Severity
     */
    public enum Severity: String, Codable {
        case CRITICAL
        case MAJOR
        case MINOR
        case WARNING
    }
    
    public internal(set) var id: String?
    
    public let type: String?
    public let source: String
    public let time: Date
    public let severity: Severity
    public let description: String?

    public var status: Status

    enum CodingKeys : String, CodingKey {
        case id
        case source
        case type
        case time
        case status
        case severity
        case description = "text"
    }
    
    enum EncodingKeys : String, CodingKey {
        case type
        case source
        case time
        case status
        case severity
        case description = "text"
    }
    
    enum SourceCodingKeys: String, CodingKey {
        case id
    }
    
    public init(forSource: String, type: String, description: String, status: Status, severity: Severity) {
        
        self.source = forSource
        self.type = type
        self.description = description
        self.status = status
        self.severity = severity
        self.time = Date()
    }
    
    public init(from decoder:Decoder) throws {
        
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try values.decode(String.self, forKey: .id)
        
        type = try values.decode(String.self, forKey: .type)
        time = try values.decode(Date.self, forKey: .time)
        status = try values.decode(Status.self, forKey: .status)
        severity = try values.decode(Severity.self, forKey: .severity)
        description = try values.decode(String.self, forKey: .description)
        
        let nestedContainer = try values.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
        source = try nestedContainer.decode(String.self, forKey: .id)
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: EncodingKeys.self)

        if (!self._updateOnly) {
            try container.encode(self.type, forKey: .type)
            try container.encode(self.time, forKey: .time)
            try container.encode(self.severity, forKey: .severity)
        }
        
        try container.encode(self.status, forKey: .status)
        try container.encode(self.description, forKey: .description)
        
        var nestedContainer = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
        try nestedContainer.encode(self.source, forKey: .id)
    }
    
    private var _updateOnly: Bool = false
    
    func copy(_ updateOnly: Bool) -> C8yAlarm {
        var copy = C8yAlarm(forSource: self.source, type: self.type!, description: self.description!, status: self.status, severity: self.severity)
        copy._updateOnly = true
        
        return copy
    }
    
    public func toJsonString(_ updateOnly: Bool) throws -> Data {

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(self.copy(updateOnly))
    }
    
    mutating func updateId(_ id: String) {
        self.id = id
    }
}
