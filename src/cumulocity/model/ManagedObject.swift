//
//  ManagedObject.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let C8Y_MANAGED_OBJECT_API = "/inventory/managedObject"

/**
Wraps a c8y ManagedObject, refer to [c8y API Reference guid](https://cumulocity.com/guides/reference/inventory/#managed-object) for more info
 
 # Notes: #
 
Represent nearly all assets that can be stored in c8y such as devices, groups etc. Can be enriched with custom attributes, incidentally these can be accessed
here through the dictionary property `properties`, keyed by the name of the attribute in c8y, but ONLY if they are prefixed with '#x#'
 
 If the custom property is not a String, then it will be flatted into constitute parts e.g.
 ```
 "c8y_LoRaDevice": {
    "id" : "1234"
    ...
 }
 ```
 
 would be accessible via
 ```
 var loRaId = obj.properties["c8y_LoRaDevice.id"]
 ```
 
 If you cannot prefix your custom property with 'x' or you don't want flattened Strings then you will need to the custom processor to identify a class of your own
 to encode/decode the custom structure, refer to `C8yCustomAssetProcessor` class for more information
*/
public struct C8yManagedObject: JcEncodableContent {
        
    public private(set) var id: String?
    
    public var type: String = "c8y_Device"
    public var name: String?
    
    public private(set) var createdTime: Date = Date()
    public internal(set) var lastUpdated: Date = Date()
    
    public private(set) var owner: String = ""

    public private(set) var status: Status?
    
    public var applicationOwner: String?
    public var applicationId: String?
    public var notes: String?
    
    public var firmware: Firmware?

    public private(set) var childDevices: ChildReferences?
    public private(set) var childAssets: ChildReferences?
    
    public internal(set) var connectionStatus: ConnectionStatus?
    public internal(set) var availability: Availability?
    public internal(set) var activeAlarmsStatus: ActiveAlarmsStatus?
    public internal(set) var isDevice: Bool = false
    
    public var requiredAvailability: RequiredAvailability?
    public var dataPoints: C8yDataPoints?
    public var sensorType: [SensorType] = []
    
    public var relayState: RelayStateType?
    
    public internal(set) var position: Position?

    public internal(set) var supportedOperations: [String]?
    public internal(set) var hardware: Hardware?
    
    public internal(set) var network: C8yAssignedNetwork?
    
    /**
     Access custom properties through this class, only properties prefixed with 'x' or provided with a dedicated custom processor class will be available
     */
    public var properties: Dictionary<String, C8yCustomAsset> = Dictionary()

    public enum ConnectionStatusType: String, Codable {
        case DISCONNECTED
        case CONNECTED
        case MAINTENANCE
    }
    
    public enum AvailabilityStatus: String, Codable {
        case AVAILABLE
        case UNAVAILABLE
        case MAINTENANCE
        case UNKNOWN
    }
    
    public enum SensorType: String, Codable {
        case TemperatureSensor = "c8y_TemperatureSensor"
        case MotionSensor = "c8y_MotionSensor"
        case AccelerationSensor = "c8y_AccelerationSensor"
        case LightSensor = "c8y_LightSensor"
        case HumiditySensor = "c8y_HumiditySensor"
        case MoistureSensor = "MoistureSensor"
        case DistanceMeasurement = "c8y_DistanceMeasurement"
        case SinglePhaseElectricitySensor = "c8y_SinglePhaseElectricitySensor"
        case CurrentSensor = "c8y_CurrentSensor"
    }
    
    public enum RelayStateType: String, Codable {
        case OPEN
        case CLOSED
        case OPEN_PENDING
        case CLOSE_PENDING
    }
    
    public struct ChildReferences: Decodable {
        
        public  let ref: String?
        public let references: [ReferencedObject]?
        
        public struct ReferencedObject: Decodable {
            
            public let id: String?
            public let name: String?
            public let ref: String?
            
            enum WrapperKey: String, CodingKey {
                case managedObject
            }
            
            enum CodingKeys: String, CodingKey {
                case id
                case name
                case ref = "self"
            }
            
            public init(from decoder: Decoder) throws {
            
                let container = try decoder.container(keyedBy: WrapperKey.self)
                let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .managedObject)
                
                self.id = try nestedContainer.decode(String.self, forKey: .id)
                self.name = try nestedContainer.decode(String.self, forKey: .name)
                self.ref = try nestedContainer.decode(String.self, forKey: .ref)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case ref = "self"
            case references
        }
        
        public init(from decoder: Decoder) throws {
        
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.ref = try container.decode(String.self, forKey: .ref)
            self.references = try container.decode([ReferencedObject].self, forKey: .references)
        }
    }

    public struct Status: Decodable {
        
        public let status: String
        public let lastUpdated: Date?

        enum CodingKeys: String, CodingKey {
            case status
            case lastUpdated
        }

        enum lastUpdatedCodingKeys: String, CodingKey {
            case date
        }
        
        enum embeddedDateCodingKeys: String, CodingKey {
            case date = "$date"
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.status = try container.decode(String.self, forKey: .status)
            
            let nestedContainer = try container.nestedContainer(keyedBy: lastUpdatedCodingKeys.self, forKey: .lastUpdated)
            let nestedContainer2 = try nestedContainer.nestedContainer(keyedBy: embeddedDateCodingKeys.self, forKey: .date)
            
            if (nestedContainer2.contains(.date)) {
                self.lastUpdated = try nestedContainer2.decode(Date.self, forKey: .date)
            } else {
                self.lastUpdated = nil
            }
        }
    }
    
    public struct Availability: Decodable {
        
        public let status: AvailabilityStatus
        public let lastMessage: Date
    }

    public struct Firmware: Codable {
        public var version: String
    }

    public struct ActiveAlarmsStatus: Decodable {
        public let warning: Int
        public let minor: Int
        public let major: Int
        public let critical: Int
        
        enum CodingKeys: String, CodingKey {
            case critical
            case major
            case minor
            case warning

        }
        
        public init(warning: Int, minor: Int, major: Int, critical: Int) {
                
            self.warning = warning
            self.minor = minor
            self.major = major
            self.critical = critical
        }
        
        public init(from decoder: Decoder) throws {
            
            let container = try decoder.container(keyedBy: CodingKeys.self)
        
            if (container.contains(.critical)) {
                self.critical = try container.decode(Int.self, forKey: .critical)
            } else {
                self.critical = 0
            }
            
            if (container.contains(.major)) {
                self.major = try container.decode(Int.self, forKey: .major)
            } else {
                self.major = 0
            }
            
            if (container.contains(.minor)) {
                self.minor = try container.decode(Int.self, forKey: .minor)
            } else {
                self.minor = 0
            }
                
            if (container.contains(.warning)) {
                self.warning = try container.decode(Int.self, forKey: .warning)
            } else {
                self.warning = 0
            }
        }
        
        public var total: Int {
            return warning + minor + major + critical
        }
    }

    public struct EmptyFragment: Codable {
        
        private var _name: String? = nil
        
        public init() {
            
        }
        
        public init(_ name: String) {
            self._name = name
        }
        
        public func encode(to encoder: Encoder) throws {
            
            var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)

            if (_name != nil) {
                try container.encode(_name, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "name")!)
            }
        }
    }

    public struct RequiredAvailability: Codable {
        public var responseInterval: Int
    }

    public struct ConnectionStatus : Decodable {
        public let status: ConnectionStatusType
    }

    public struct Position: Codable {
        
        public var lat: Double
        public var lng: Double
        public var alt: Double?
        
        public init(lat: Double, lng: Double, alt: Double?) {
            
            self.lat = lat
            self.lng = lng
            self.alt = alt
        }
        
        enum CodingKeys: String, CodingKey {
            case lat
            case lng
            case alt
        }
        
        public init(from decoder: Decoder) throws {
         
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            do { self.lat = try container.decode(Double.self, forKey: .lat) } catch {
                self.lat = Double(try container.decode(String.self, forKey: .lat))!
            }
            
            do { self.lng = try container.decode(Double.self, forKey: .lng) } catch {
                self.lng = Double(try container.decode(String.self, forKey: .lng))!
            }
            
            if (container.contains(.alt)) {
                do { self.alt = try container.decode(Double.self, forKey: .alt) } catch {
                    do { self.alt = Double(try container.decode(String.self, forKey: .alt))! } catch { }//ignore
                }
            }
        }
        
        public func isDifferent(_ pos: Position?) -> Bool {
            
            if (pos == nil) {
                return true
            } else {
                return self.lat != pos?.lat || self.lng != pos?.lng || self.alt != pos?.alt
            }
        }
    }
   
    public struct LpwanDevice: Decodable {
        public let provisioned: Bool
    }

    public struct Hardware: Codable {
        public var serialNumber: String?
        public var model: String?
        public var supplier: String?
        public var revision: String?
    }
    
    public init(_ id: String) {
            
        self.id = id
    }
    
    public init(name: String, type: String, notes: String?) {
        self.name = name
        self.type = type
        self.notes = notes
        
        //super.init()
    }
    
    public init(_ id: String, requiredAvailability: RequiredAvailability) {
            
        self.id = id
        self.requiredAvailability = requiredAvailability
    }
    
    public init(deviceWithSerialNumber serialNumber: String?, name: String, type: String, supplier: String?, model: String, notes: String?, revision: String?, requiredResponseInterval: Int?) {
        
        self.name = name
        self.type = type
        self.notes = notes

        if (serialNumber != nil || model.count > 0 || supplier != nil || revision != nil) {
            self.hardware = Hardware(serialNumber: serialNumber, model: model, supplier: supplier, revision: revision)
        }
        
        self.isDevice = true
        
        if (requiredResponseInterval != nil) {
            self.requiredAvailability = RequiredAvailability(responseInterval: requiredResponseInterval!)
        }
        
        //super.init()
    }
    
    public init(from decoder: Decoder) throws {
           
        let container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey> = try decoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
           
        do {
        for key in container.allKeys {
               
            switch key.stringValue {
                case "id":
                    self.id = try container.decode(String.self, forKey: key)
                case "type":
                    self.type = try container.decode(String.self, forKey: key)
                case "name":
                    self.name = try container.decode(String.self, forKey: key)
                case "createdTime":
                    self.createdTime = try container.decode(Date.self, forKey: key)
                case "lastUpdated":
                    self.lastUpdated = try container.decode(Date.self, forKey: key)
                case "owner":
                    self.owner = try container.decode(String.self, forKey: key)
                case "applicationId":
                    self.applicationId = try container.decode(String.self, forKey: key)
                case "applicationOwner":
                    self.applicationOwner = try container.decode(String.self, forKey: key)
                case "c8y_Status":
                    self.status = try container.decode(Status.self, forKey: key)
                case "c8y_Notes":
                    self.notes = try container.decode(String.self, forKey: key)
                case "c8y_Firmware":
                    self.firmware = try container.decode(Firmware.self, forKey: key)
                case "childAssets":
                    self.childAssets = Self.safeDecodeChildAssets(key, container: container)
                case "childDevices":
                    self.childDevices = Self.safeDecodeChildReferences(key, container: container)
                case "c8y_IsDevice":
                    self.isDevice = true
                case "c8y_Connection":
                    self.connectionStatus = try container.decode(ConnectionStatus.self, forKey: key)
                case "c8y_Availability":
                    self.availability = try container.decode(Availability.self, forKey: key)
                case "c8y_RequiredAvailability":
                    self.requiredAvailability = try container.decode(RequiredAvailability.self, forKey: key)
                case "c8y_Position":
                    self.position = try container.decode(Position.self, forKey: key)
                case "c8y_Relay":
                    self.relayState = try container.decode(RelayStateType.self, forKey: key)
                case "c8y_Hardware":
                    self.hardware = try container.decode(Hardware.self, forKey: key)
                case "c8y_DataPoint":
                    self.dataPoints = try container.decode(C8yDataPoints.self, forKey: key)
                case "c8y_SupportedOperations":
                    self.supportedOperations = try container.decode([String].self, forKey: key)
                case "c8y_ActiveAlarmsStatus":
                    self.activeAlarmsStatus = try container.decode(ActiveAlarmsStatus.self, forKey: key)
                default:
                
                    let sensorType = SensorType(rawValue: key.stringValue)
                    
                    if (sensorType != nil) {
                        self.sensorType.append(sensorType!)
                    } else {
                        
                        if (self.network == nil && (key.stringValue == JC_MANAGED_OBJECT_NETWORK_INSTANCE || key.stringValue == JC_MANAGED_OBJECT_NETWORK_LPWAN || key.stringValue == JC_MANAGED_OBJECT_NETWORK_EUI)) {
                            self.network = try Self.setupNetwork(container, keys: container.allKeys)
                        } else {
                            self.properties = try C8yCustomAssetProcessor.decode(key: key, container: container, propertiesHolder: self.properties)
                        }
                    }
                }
            }
        } catch {
            throw error
        }
    }
       
    public func encode(to encoder: Encoder) throws {
           
        var container = encoder.container(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self)
           
        if (self.id == nil || self.type != "c8y_Device") {
            try container.encode(self.type, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "type")!)
        }
        
        if (self.name != nil) {
            try container.encode(self.name, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "name")!)
        }
        
        if (self.notes != nil) {
            try container.encode(self.notes, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_Notes")!)
        }
        
        if (self.firmware != nil) {
            try container.encode(self.firmware, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_Firmware")!)
        }
        
        if (self.isDevice) {
            try container.encode(EmptyFragment(), forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_IsDevice")!)
        }
        
        if (self.sensorType.count > 0) {
            for k in self.sensorType {
                try container.encode(EmptyFragment(), forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: k.rawValue)!)
            }
        }
        
        if (self.requiredAvailability != nil) {
            try container.encode(self.requiredAvailability, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_RequiredAvailability")!)
        }
        
        if (self.position != nil) {
            try container.encode(self.position, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_Position")!)
        }
        
        if (self.relayState != nil) {
            try container.encode(self.position, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_Relay")!)
        }
        
        if (self.hardware != nil) {
            try container.encode(self.hardware, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_Hardware")!)
        }
        
        if (self.dataPoints != nil) {
            try container.encode(self.dataPoints, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_DataPoint")!)
        }
        
        if (self.supportedOperations != nil) {
            try container.encode(self.supportedOperations, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "c8y_SupportedOperations")!)
        }
        
        if (self.network != nil) {
                
            if (self.network!.type != nil) {
                try container.encode(self.network!.type!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_TYPE)!)
            }
            
            if (self.network!.provider != nil) {
                try container.encode(self.network!.provider!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_PROVIDER)!)
            }
            
            if (self.network!.instance != nil) {
                try container.encode(self.network!.instance!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_INSTANCE)!)
            }
            
            if (self.network!.appEUI != nil) {
                try container.encode(self.network!.appEUI!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_EUI)!)
            }
            
            if (self.network!.appKey != nil) {
                try container.encode(self.network!.appKey!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_KEY)!)
            }
            
            if (self.network!.codec != nil) {
                try container.encode(self.network!.codec!, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: JC_MANAGED_OBJECT_NETWORK_CODEC)!)
            }
        }
        
        for (k, v) in properties {
            
            // cannot serialise complex structures that have been flattened by decoder below (need to declare explicit class that case via registerCustomDecoder)
            if (!k.contains(".")) {
                
                if (v is C8yStringWrapper) {
                    try container.encode((v as! C8yStringWrapper).value, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue:k)!)
                } else {
                    _ = try v.encode(container, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: k)!)
                }
            }
        }
    }
    
    mutating func updateId(_ id: String) {
        self.id = id
    }
    
    mutating func updatePosition(latitude: Double, longitude: Double, altitude: Double?) {
        self.position = Position(lat: latitude, lng: longitude, alt: altitude)
    }
    
    func toJsonString() -> Data {

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        return try! encoder.encode(self)
    }
    
    private static func safeDecodeChildAssets(_ key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) -> ChildReferences? {
        do {
            return try container.decode(ChildReferences.self, forKey: key)
        } catch {
            return nil
        }
    }

    private static func safeDecodeChildReferences(_ key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) -> ChildReferences? {
        
        do {
            return try container.decode(ChildReferences.self, forKey: key)
        } catch {
            return nil
        }
    }
    
    private static func setupNetwork(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, keys: [C8yCustomAssetProcessor.AssetObjectKey]) throws -> C8yAssignedNetwork {
        var network = C8yAssignedNetwork()
        
        for key in keys {
            try network.decode(container, forKey: key)
        }
        
        return network
    }

    static func dateFormatter() -> DateFormatter {
        
        let rFC3339DateFormatter = DateFormatter()
        rFC3339DateFormatter.locale = Locale(identifier: "enUSPOSIX")
        rFC3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" // c8y = 2020-02-25T19:58:13.925Z
        rFC3339DateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        return rFC3339DateFormatter
    }
}
