//
//  Operation.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public let C8Y_OPERATION_COMMAND = "c8y_Command"
public let C8Y_OPERATION_RESTART = "c8y_Restart"
public let C8Y_OPERATION_RELAY = "c8y_Relay"
public let C8Y_OPERATION_LOG_REQ = "c8y_LogfileRequest"

public let C8Y_OPERATION_RELAY_STATE = "state"

/**
Represents an c8y operation, that can be posted to a remote device [c8y API Reference Guide](https://cumulocity.com/guides/reference/device-control/#operation) for more info
*/
public struct C8yOperation: JcEncodableContent, Identifiable {
    
    public private(set) var id: String?
    public private(set) var bulkOperationId: String?
    
    public private(set) var deviceId: String
    public private(set) var deviceExternalIDs: [C8yExternalId]?
    
    public private(set) var creationTime: Date?
    public private(set) var status: Status?
    public private(set) var failureReason: String?
    
    public private(set) var type: String?
    public private(set) var description: String?
    
    public var operationDetails: OperationDetails?
    
    public enum Status: String, Codable {
        case SUCCESSFUL
        case FAILED
        case EXECUTING
        case PENDING
    }
    
    public init(source: String, type: String, description: String) {
            
        self.deviceId = source
        self.type = type
        self.description = description
        self.creationTime = Date()
        self.status = .PENDING
    }
    
    public init(from decoder:Decoder) throws {
        
        let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        self.deviceId = ""
        
        for (key) in values.allKeys {
            
            switch (key.stringValue) {
            case "id":
                self.id = try values.decode(String.self, forKey: key)
            case "deviceName":
                // ignore
                break
            case "bulkOperationId":
                self.bulkOperationId = try values.decode(String.self, forKey: key)
            case "deviceId":
                self.deviceId = try values.decode(String.self, forKey: key)
            case "deviceExternalIDs":
                self.deviceExternalIDs = try values.decode([C8yExternalId].self, forKey: key)
            case "creationTime":
                self.creationTime = try values.decode(Date.self, forKey: key)
            case "status":
                self.status = try values.decode(Status.self, forKey: key)
            case "failureReason":
                self.failureReason = try values.decode(String.self, forKey: key)
            default:
                do {
                    
                    if (key.stringValue.starts(with: "c8y_")) {
                        self.operationDetails = try values.decode(OperationDetails.self, forKey: key)
                        self.type = key.stringValue
                    }
                } catch {
                    print("bugger \(error.localizedDescription)")
                }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        try container.encode(deviceId, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "deviceId")!)
        try container.encode(description, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "description")!)

        if (operationDetails != nil) {
            try container.encode(operationDetails!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: self.type!)!)
        } else {
            try container.encode(C8yManagedObject.EmptyFragment("pow"), forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: self.type!)!)
        }
    }
    
    public struct OperationDetails: Codable {
        
        public private(set) var id: String?
        public private(set) var name: String?
        
        public var parameters: Dictionary<String, String> = [:]
        
        public init(_ name: String, value: String) {
        
            self.name = name
            self.parameters = [name: value]
        }
        
        public init(from decoder:Decoder) throws {
               
            let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
            
            for (key) in values.allKeys {
                switch (key.stringValue) {
                case "id":
                    self.id = try values.decode(String.self, forKey: key)
                case "name":
                    self.name = try values.decode(String.self, forKey: key)
                default:
                    
                    do {
                        self.parameters[key.stringValue] = try values.decode(String.self, forKey: key)
                    } catch {
                        print("operation details error: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
            
            if (self.id != nil) {
                try container.encode(self.id!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "id")!)
            }
            
            if (self.name != nil) {
                try container.encode(self.name, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: name!)!)
            }
            
            for kv in self.parameters {
                try container.encode(kv.value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: kv.key)!)

            }
        }
    }
}
