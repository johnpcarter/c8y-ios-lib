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
public let C8Y_OPERATION_MESSAGE = "c8y_Message"
public let C8Y_OPERATION_RELAY = "c8y_Relay"
public let C8Y_OPERATION_LOG_REQ = "c8y_LogfileRequest"
public let C8Y_OPERATION_PROPERTY = "c8y_Property"
public let C8Y_OPERATION_FIRMWARE = "c8y_Firmware"
public let C8Y_OPERATION_UPLOAD = "c8y_UploadConfigFile"
public let C8Y_OPERATION_DOWNLOAD = "c8y_DownloadConfigFile"
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
    public internal(set) var status: Status?
    public private(set) var failureReason: String?
    
    public private(set) var type: String?
    public private(set) var description: String?
    
    public var operationDetails: OperationDetails
    
    public enum Status: String, Codable {
        case SUCCESSFUL
        case FAILED
        case EXECUTING
        case PENDING
    }
    
	/**
	Creates a new operation for the associated `C8yManagedObject`
	- parameter forSource internal c8y id of the associated managed object/asset
	- parameter type free form text to categorise the measurement type
	- parameter description free form text to describe the operation
	*/
    public init(forSource source: String, type: String, description: String) {
            
        self.deviceId = source
        self.type = type
        self.description = description
        self.creationTime = Date()
        self.status = .PENDING
		self.operationDetails = OperationDetails()
    }
    
    public init(from decoder:Decoder) throws {
        
        let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        self.deviceId = ""
        
		self.operationDetails = OperationDetails()
		
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

		if (!operationDetails.params.isEmpty) {
            try container.encode(operationDetails, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: self.type!)!)
        } else {
            try container.encode(C8yManagedObject.EmptyFragment("pow"), forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: self.type!)!)
        }
    }
    
	/**
	Defines the details of the operation to be executed by the device
	*/
    public struct OperationDetails: Codable {
        
        public private(set) var id: String?
        public private(set) var name: String?
        
        public var values: Dictionary<String, String> = [:]
		public var params: Dictionary<String, String> = [:]
		
		public init() {
		}
		
		/**
		Creates a new instance with a single key/value attribute pair
		- parameter name name of the attribute to be set
		- parameter value the value to be assigned to the attribute
		*/
        public init(_ name: String, value: String) {
        
            self.name = name
            self.values = [name: value]
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
                        self.values[key.stringValue] = try values.decode(String.self, forKey: key)
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
            
            for kv in self.values {
                try container.encode(kv.value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: kv.key)!)

            }
        }
    }
}
