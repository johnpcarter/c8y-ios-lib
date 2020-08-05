//
//  Device.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 23/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

let C8Y_MANAGED_OBJECTS_ATTACHMENTS = "xAttachmentIds"
let JC_MANAGED_OBJECT_WEBLINK = "xWebLink"

public enum C8yDeviceCategory: String, CaseIterable, Hashable, Identifiable, Encodable {
    case Unknown
    case Group
    case Gauge
    case Temperature
    case Motion
    case Accelerator
    case Light
    case Humidity
    case Moisture
    case Distance
    case Current
    case ElectricMeter
    case GasMeter
    case Thermostat
    case Motor
    case Camera
    case Alarm
    case Lock
    case Network
    case Router
    case Phone
    case Computer
    
    public var id: C8yDeviceCategory {self}
}

public struct C8yDevice: C8yObject {
        
    public var id = UUID().uuidString

    public var externalIds: [String:C8yExternalId] = [String:C8yExternalId]()

    public static func == (lhs: C8yDevice, rhs: C8yDevice) -> Bool {
        lhs.c8yId == rhs.c8yId
    }
    
    public func isDifferent(_ device: C8yDevice) -> Bool {
    
        return  self.operationalLevel != device.operationalLevel
                || self.attachments.count != device.attachments.count
                || self.isDeployed != device.isDeployed
                || self.firmware != device.firmware
                || self.lastMessage != device.lastMessage
                || self.lastUpdated != device.lastUpdated
                || self.deviceCategory != device.deviceCategory
                || self.name != device.name
                || self.isNew != device.isNew
                || self.webLink != device.webLink
                || self.model != device.model
                || self.network != device.network
                || self.notes != device.notes
                || self.requiredResponseInterval != device.requiredResponseInterval
                || self.revision != device.revision
                || self.position == nil && device.position != nil
                || (self.position != nil && self.position!.isDifferent(device.position))
    }
    
    public var groupCategory: C8yGroupCategory {
         return .device
    }
     
    public var orgCategory: C8yOrganisationCategory {
        get {
         return .na
        }
     }
    
    public var deviceCategory: C8yDeviceCategory {
         get {
            if (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] != nil) {
                return C8yDeviceCategory(rawValue: (self.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] as! C8yStringWrapper).value) ?? .Unknown
            } else if self.wrappedManagedObject.sensorType.count > 0 {
                return C8yDeviceCategory(rawValue: self.wrappedManagedObject.sensorType[0].rawValue.substring(from: 3))!
            } else {
                return .Unknown
            }
         }
        set(v) {
            if (self.wrappedManagedObject.sensorType.count == 0 || (C8yManagedObject.SensorType(rawValue: "c8y_\(v)") != nil && !self.wrappedManagedObject.sensorType.contains(C8yManagedObject.SensorType(rawValue: "c8y_\(v)")!))) {
                wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_XDEVICE_CATEGORY] = C8yStringWrapper(v.rawValue)
            }
        }
     }
    
     public var operationalLevel: C8yOperationLevel {
        get {
            if (self.wrappedManagedObject.availability?.status == .MAINTENANCE || self.wrappedManagedObject.activeAlarmsStatus == nil || self.wrappedManagedObject.activeAlarmsStatus?.total == 0) {
                if (self.wrappedManagedObject.availability?.status == .AVAILABLE) {
                    return .nominal
                } else if (self.wrappedManagedObject.availability?.status == .UNAVAILABLE) {
                    return .offline
                } else if (self.wrappedManagedObject.availability?.status == .MAINTENANCE) {
                    return .maintenance
                } else {
                    return .unknown
                }
            }
            else if (self.wrappedManagedObject.activeAlarmsStatus?.critical ?? 0 > 0) {
                return .error
            }
            else if (self.wrappedManagedObject.activeAlarmsStatus?.major ?? 0 > 0) {
                return .failing
            } else if (self.wrappedManagedObject.activeAlarmsStatus?.minor ?? 0 > 0) {
                return .operating
            } else if (self.wrappedManagedObject.activeAlarmsStatus?.warning ?? 0 > 0) {
                return .operating
            } else {
                return .unknown
            }
        }
    }
    
    public var alarmsCount: Int
    {
        get {
            var count: Int = 0
            
            self._counter{ (obj) in
                count += obj.alarmsCount
            }
            
            if (self.alarms != nil) {
                count += self.alarms!.critical
                count += self.alarms!.major
                count += self.alarms!.minor
                count += self.alarms!.warning
            }
            
            return count
        }
    }
    
    public var status: C8yManagedObject.AvailabilityStatus {
        get {
            return self.wrappedManagedObject.availability?.status ?? .UNKNOWN
        }
    }
    
    public var serialNumber: String? {
        get {
            return self.externalIds["c8y_Serial"]?.externalId
            
        }
        set(v) {
            
            var ext = self.externalIds["c8y_Serial"]
            
            if (ext == nil && v != nil) {
                self.externalIds["c8y_Serial"] = C8yExternalId(withExternalId: v!, ofType: "c8y_Serial")
            } else if (v != nil) {
                ext!.externalId = v!
            }
        }
    }
    
    public var supplier: String? {
        get {
            return self.wrappedManagedObject.hardware?.supplier
        }
        set(s) {
            
            if (self.wrappedManagedObject.hardware == nil) {
               self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware?.supplier = s
        }
    }
    
    public var model: String? {
        get {
            return self.wrappedManagedObject.hardware?.model
        }
        set(m) {
            
            if (self.wrappedManagedObject.hardware == nil) {
                self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware!.model = m
        }
    }
    
    public var revision: String? {
        get {
            return self.wrappedManagedObject.hardware?.revision
        }
        set(r) {
            
           if (self.wrappedManagedObject.hardware == nil) {
                self.wrappedManagedObject.hardware = C8yManagedObject.Hardware()
            }
            
            self.wrappedManagedObject.hardware?.revision = r
        }
    }
    
    public var firmware: String? {
        get {
            return self.wrappedManagedObject.firmware?.version
        }
    }
    
    public var operations: [String] {
        get {
            if (self.wrappedManagedObject.supportedOperations != nil) {
                return self.wrappedManagedObject.supportedOperations!
            } else {
                return []
            }
        }
    }
    
    public var network: C8yAssignedNetwork! {
        get {
            return self.wrappedManagedObject.network
        }
        set {
            self.wrappedManagedObject.network = newValue
        }
    }
    
    public var notes: String? {
        get {
            return self.wrappedManagedObject.notes
        }
        set(notes) {
            self.wrappedManagedObject.notes = notes
        }
    }
    
    public var lastUpdated: Date? {
        get {
            return self.wrappedManagedObject.lastUpdated
        }
    }
    
    public var lastMessage: Date? {
        get {
            return self.wrappedManagedObject.availability?.lastMessage
        }
    }
    
    public var requiredResponseInterval: Int? {
        get {
            return self.wrappedManagedObject.requiredAvailability?.responseInterval
        }
    }
    
    public var webLink: String? {
        get {
            return (self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_WEBLINK] as? C8yStringWrapper)?.value
        }
        set(lnk) {
            
            if (lnk != nil) {
                self.wrappedManagedObject.properties[JC_MANAGED_OBJECT_WEBLINK] = C8yStringWrapper(lnk!)
            }
        }
    }
    
    public var isDeployed: Bool {
        get {
            return self.network == nil || self.network.type == C8yNetworkType.none.rawValue || self.network.isProvisioned
        }
    }
    
    public var connected: Bool {
        get {
            if (self.wrappedManagedObject.status != nil) {
                return self.wrappedManagedObject.connectionStatus!.status == .CONNECTED
            } else {
                return false
            }
        }
    }
    
    public var alarms: C8yManagedObject.ActiveAlarmsStatus? {
        get {
            return self.wrappedManagedObject.activeAlarmsStatus
        }
    }
    
    public var dataPoints: C8yDataPoints? {
        get {
            return self.wrappedManagedObject.dataPoints
        }
    }
    
    public var wrappedManagedObject: C8yManagedObject
    public internal(set) var location: String?
    public internal(set) var attachments: [String] = []
    public internal(set) var children: [AnyC8yObject] = []
    
    init() {
        self.wrappedManagedObject = C8yManagedObject("_none_")
        self.wrappedManagedObject.isDevice = true
    }
    
    public init(externalId: String, type: String) {
        self.init()
        self.externalIds[type] = C8yExternalId(withExternalId: externalId, ofType: type)
    }
    
    public init(_ m: C8yManagedObject) {
                
        self.wrappedManagedObject = m
        
        if (wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] != nil) {
            let subs = (wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] as! C8yStringWrapper).value.split(separator: ",")
            
            for s in subs {
                self.attachments.append(String(s))
            }
        }
    }
    
    init(_ m: C8yManagedObject, location: String) {
                
        self.init(m)
        self.wrappedManagedObject.isDevice = true

        self.location = location
    }
    
    public init(_ c8yId: String) {
    
        self.wrappedManagedObject = C8yManagedObject(c8yId)
        self.wrappedManagedObject.isDevice = true
    }
    
    init(_ c8yId: String?, serialNumber: String?, withName name: String, type: String, supplier: String?, model: String?, notes: String?, requiredResponseInterval: Int, revision: String, category: C8yDeviceCategory?) {
    
        self.wrappedManagedObject = C8yManagedObject(deviceWithSerialNumber: serialNumber, name: name, type: type, supplier: supplier, model: model!, notes: notes, revision: revision, requiredResponseInterval: requiredResponseInterval)
                
        if (c8yId != nil) {
            self.wrappedManagedObject.updateId(c8yId!)
        }
        
        if (category != nil) {
            self.deviceCategory = category!
        }
    }
    
    public func defaultExternalIdAndType() -> String {
       
       var idString: String
       
       if (self.externalIds.count > 0) {
           idString = "\(externalIds.first!.value.type)=\(externalIds.first!.value.externalId)"
       } else if (self.serialNumber != nil) {
           idString = "c8y_Serial=\(self.serialNumber!)"
       } else {
           idString = "c8yId=\(self.c8yId)"
       }
       
       return idString
    }
    
    public func match(forExternalId id: String, type: String?) -> Bool {
                   
        return (self.externalIds[type ?? "c8y_Serial"] != nil && self.externalIds[type ?? "c8y_Serial"]!.externalId == id)
    }
    
    public func generateQRCodeImage() throws -> UIImage {
        
        return try self.generateQRCodeImage(forType: nil)
    }
    
    public func generateQRCodeImage(forType type: String?) throws -> UIImage {
    
        var idString: String
        
        if (type == nil) {
            idString = self.defaultExternalIdAndType()
        } else {
            let ext = self.externalIds[type!]
            
            if (ext == nil) {
                throw C8yNoValidIdError.error
            }
            
            idString = "\(ext!.type)=\(ext!.externalId)"
        }
        
        if (self.supplier != nil && self.supplier!.count > 0) {
            idString += "\n"
            idString += "supplier=\(self.supplier!)"
        }
        
        if (self.model != nil && self.model!.count > 0 && self.model! != "-") {
            idString += "\n"
            idString += "model=\(self.model!)"
        }
        
        if (self.network != nil && self.network!.appKey != nil) {
            idString += "\n"
            idString += "appKey=\(self.network!.appKey!)"
        }
        
        if (self.network != nil && self.network!.appEUI != nil) {
            idString += "\n"
            idString += "appEUI=\(self.network!.appEUI!)"
        }
               
        let data = Data(idString.utf8)
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
    
    public func qrCodeScannedLineDoesMatchExternalId(line: String, separator: String.Element?) -> Bool {
                
        if (separator != nil) {
    
            let parts = line.split(separator: separator!)
            let type: String = String(parts[0])
            let ref: String = String(parts[1])
            var id = self.externalIds[type]
                   
            if (id == nil) {
                id = self.externalIds[type.lowercased()]
            }
            
            return id != nil && id?.externalId == ref.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of:":", with:"")
        } else {
            
            for id in self.externalIds.values {
                if (id.externalId == line) {
                    return true
                }
            }
            
            return false
        }
    }
    
    public func availableMetrics() -> [C8yDataPoints.DataPoint]? {
    
        if (self.dataPoints != nil) {
            return self.dataPoints!.dataPoints
        } else {
            return nil
        }
    }
    
}
