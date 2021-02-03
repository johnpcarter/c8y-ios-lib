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
public let C8Y_OPERATION_RELAY_STATE = "relayState"

/**
Represents an c8y operation, that can be posted to a remote device [c8y API Reference Guide](https://cumulocity.com/guides/reference/device-control/#operation) for more info
*/
public struct C8yOperation: JcEncodableContent, Identifiable {
    
    public private(set) var id: String = UUID().uuidString
    public private(set) var bulkOperationId: String?
    
    public var deviceId: String
    public private(set) var deviceExternalIDs: [C8yExternalId]?
    
    public private(set) var creationTime: Date?
    public var status: Status?
    public private(set) var failureReason: String?
    
    public var type: String = "unknown"
    public var description: String?
    
    public var operationDetails: OperationDetails
    
	// populated from model info
	
	public var model: OperationTemplate = OperationTemplate()
	
    public enum Status: String, Codable {
        case SUCCESSFUL
        case FAILED
        case EXECUTING
        case PENDING
    }
    
	public init() {
		self.deviceId = ""
		self.description = ""
		self.operationDetails = OperationDetails()
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
        
		print("Decoding operation:")
		
        let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
        
        self.deviceId = ""
        
		self.operationDetails = OperationDetails()
		
        for (key) in values.allKeys {
            
			print("processing key \(key)")
			
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
        
		try container.encode(self.deviceId, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "deviceId")!)
		try container.encode(self.description, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "description")!)
		
		if (self.status != nil && self.status != .PENDING) {
			try container.encode(self.status!.rawValue, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "status")!)
		}
		
		if (self.operationDetails.values.count > 0) {
			
			if (self.type != "unknown") {
				try container.encode(self.operationDetails, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: self.type)!)
			} else {
				try self.operationDetails.values.keys.forEach { key in
					
					if (self.operationDetails.values[key]! is C8yStringCustomAsset) {
						try container.encode((self.operationDetails.values[key]! as! C8yStringCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: key)!)
					} else if (self.operationDetails.values[key]! is C8yDoubleCustomAsset) {
						try container.encode((self.operationDetails.values[key]! as! C8yDoubleCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: key)!)
					} else if (self.operationDetails.values[key]! is C8yBoolCustomAsset) {
						try container.encode((self.operationDetails.values[key]! as! C8yBoolCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: key)!)
					}
				}
			}
		}
    }
	
	public struct OperationTemplate: Codable {
		
		public var type: String = "c8y_Relay"
		public var description: String? = nil
		public var value: String? = nil
		public var valueAsPercentage: Bool?
		public var label: String? = nil
		public var activeLabel: String? = nil
		
		public var uom: String? = nil
		public var min: Double? = nil
		public var max: Double? = nil
		public var values: [String]? = nil
		
		public var symbolForMin: String? = nil
		public var symbolForMax: String? = nil
		
		public init() {
			
		}
	}
	
	/**
	Defines the details of the operation to be executed by the device
	*/
	public struct OperationDetails: Codable {
		
		public private(set) var id: String = UUID().uuidString
		
		public var name: String?
		public var values: Dictionary<String, C8yCustomAsset> = [:]
		
		public init() {
		}
		
		/**
		Creates a new instance with a single key/value attribute pair
		- parameter name name of the attribute to be set
		- parameter value the value to be assigned to the attribute
		*/
		public init(_ name: String, value: String?) {
		
			self.name = name
			
			if (value != nil) {
				self.values = [name: C8yStringCustomAsset(value!)]
			}
		}
		
		public init(_ name: String, value: Double?) {
		
			self.name = name
			
			if (value != nil) {
				self.values = [name: C8yDoubleCustomAsset(value!)]
			}
		}
		
		public init(_ name: String, value: Bool?) {
		
			self.name = name
			
			if (value != nil) {
				self.values = [name: C8yBoolCustomAsset(value!)]
			}
		}
		
		public init(from decoder:Decoder) throws {
			   
			let values = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
			
			for key in values.allKeys {
				switch (key.stringValue) {
				case "id":
					self.id = try values.decode(String.self, forKey: key)
				case "name":
					self.name = try values.decode(String.self, forKey: key)
				default:
					
					do { self.values[key.stringValue] = C8yStringCustomAsset(try values.decode(String.self, forKey: key))
					} catch {
						do { self.values[key.stringValue] = C8yDoubleCustomAsset(try values.decode(Double.self, forKey: key))
						} catch {
							do { self.values[key.stringValue] =  C8yBoolCustomAsset(try values.decode(Bool.self, forKey: key))
							} catch {
								// h'mm no good
								
								throw InvalidOperationTypeValue(key: key.stringValue)
							}
						}
					}
				}
			}
		}
		
		public struct InvalidOperationTypeValue: Error {
			public var key: String?
		}
		
		public func encode(to encoder: Encoder) throws {
			
			var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
			
			if (self.name != nil) {
				try container.encode(self.name, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: name!)!)
			}
			

			for kv in self.values {
				
				if (kv.value is C8yStringCustomAsset) {
					try container.encode((kv.value as! C8yStringCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: kv.key)!)
				} else if (kv.value is C8yDoubleCustomAsset) {
					try container.encode((kv.value as! C8yDoubleCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: kv.key)!)
				} else if (kv.value is C8yBoolCustomAsset) {
					try container.encode((kv.value as! C8yBoolCustomAsset).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: kv.key)!)
				}
			}
		}
	}
}
