//
//  DeviceManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 13/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class C8yMutableDevice: Identifiable  {
    
    public var device: C8yDevice
    
    public internal(set) var primaryMeasurement: C8yMeasurementSeries?
    public internal(set) var lastPrimaryMeasurements: [C8yMeasurementSeries] = []
    
    public internal(set) var lastAttachment: JcMultiPartContent.ContentPart? = nil

    public private(set) var deviceDidMutate: Bool = false
    
    private let _conn: C8yCumulocityConnection

    public init(_ device: C8yDevice, _ conn: C8yCumulocityConnection) {
        
        self.device = device
        self._conn = conn
    }
    
    public func fetchMostRecentPrimaryMetric(completionHandler: @escaping (C8yMeasurementSeries?, Error?) -> Void) {
           
        if (device.c8yId != "_new_") {
           
            let metric: [C8yDataPoints.DataPoint] = self.primaryDataPoints(device)

            if (metric.count > 0) {
                let interval: Double = Double(device.requiredResponseInterval == nil ? 60 : device.requiredResponseInterval! * 60)

                self._getLast(device, type: metric[0].reference, series: metric[0].value.series, interval: interval, connection: self._conn) { m, error in
                       
                    self.primaryMeasurement = m
                    completionHandler(m, error)
                }
            } else {
                completionHandler(nil, nil)
            }
        }
    }

    public func fetchLastRecordedMetrics(completionHandler: @escaping ([C8yMeasurementSeries]) -> Void) {
        
        if (self.device.c8yId != "_new_") {
        
            var lastPrimaryMeasurements: [C8yMeasurementSeries] = []
            let dataPoints: [C8yDataPoints.DataPoint] = self.primaryDataPoints(device)
            
            let interval: Double = 1440 // 24 hours past in seconds

            var seq = 0
            
            for m in dataPoints {

                self._getLast(device, type: m.reference, series: m.value.series, interval: interval, connection: self._conn) { m, error in
                    
                    if (m != nil) {
                        lastPrimaryMeasurements.append(m!)
                    }
                    
                    seq += 1
                    
                    if (seq >= dataPoints.count && lastPrimaryMeasurements.count > 0) {
                        self.lastPrimaryMeasurements = lastPrimaryMeasurements
                        
                        completionHandler(lastPrimaryMeasurements)
                    }
                }
            }
        }
    }
    
    public func measurements(forType type: String, andSeries series: String, aggregrationType: C8yMeasurementSeries.AggregateType, hoursBack: Int, completionHandler: @escaping (C8yMeasurementSeries?, Error?) -> Void) {
               
        _ = C8yMeasurementsService(self._conn).getSeries(forSource: device.c8yId, type: type, series: series, from: Date().addingTimeInterval(TimeInterval(-hoursBack * 3600)), to: Date(), aggregrationType: aggregrationType) { (response:JcRequestResponse<C8yMeasurementSeries>) in

            if (response.status == .SUCCESS) {
                completionHandler(response.content, nil)
            } else {
                completionHandler(nil, self.makeError(response))
            }
        }
    }
    
    private func _getLast(_ device: C8yDevice, type: String, series: String, interval: Double, connection: C8yCumulocityConnection, completionHandler: @escaping (C8yMeasurementSeries?, Error?) -> Void) {
    
        print("Fetching metrics for device \(device.name), \(type), \(series)")

        _ = C8yMeasurementsService(connection).getSeries(forSource: device.c8yId, type: type, series: series, from: Date().addingTimeInterval(-interval), to: Date(), aggregrationType: .MINUTELY) { response in
            
            if (response.status == .SUCCESS) {
                completionHandler(response.content, nil)
            } else {
                completionHandler(nil, self.makeError(response))
            }
        }
    }
        
    public func attachmentForId(id: String, completionHandler: @escaping (C8yDevice?, JcMultiPartContent.ContentPart?) -> Void) {

        if (self.lastAttachment == nil || self.lastAttachment?.id != id) {
            
            _ = C8yBinariesService(self._conn).get(id) { r in

                if (r.status == .SUCCESS) {
                    self.lastAttachment = r.content!.parts[0]
                    completionHandler(self.device, self.lastAttachment)
                } else {
                    completionHandler(nil, nil)
                }
            }
        } else if (self.lastAttachment != nil) {

            completionHandler(nil, self.lastAttachment)
        } else {
            completionHandler(nil, nil)
        }
    }

    public func addAttachment(filename: String, fileType: String, content: Data, completionHandler: @escaping (C8yDevice?) -> Void) {

        var fname = filename
        
        if (!fname.contains(".")) {
            
            if (fname.contains("png")) {
                fname += ".png"
            } else {
                fname += ".jpg"
            }
        }
        
        _ = C8yBinariesService(self._conn).post(name: "\(device.c8yId)-\(fname)", contentType: fileType, content: content) { r in

            if (r.status == .SUCCESS) {
                
                self.deviceDidMutate = true
                
                self.lastAttachment = r.content!.parts[0]
                self.device.attachments.insert(self.lastAttachment!.id!, at: 0)

                self.device.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] = C8yStringWrapper(String.make(array: self.device.attachments)!)
                
                // this should be done by caller
                
                /*do {
                    _ = try C8yManagedObjectsService(self._conn).put(self.device.wrappedManagedObject) { r in
                        
                        if (r.status == .SUCCESS) {
                            completionHandler(self.device)
                        } else {
                            completionHandler(nil)
                        }
                    }
                } catch {
                    completionHandler(nil)
                }*/
            } else {
                completionHandler(nil)
            }
        }
    }
    
    public func replaceAttachment(index: Int, filename: String, fileType: String, content: Data, completionHandler: @escaping (C8yDevice) -> Void) {

        _ = C8yBinariesService(self._conn).post(name: filename, contentType: fileType, content: content) { r in

            let oldRef = self.lastAttachment?.id
            
            self.deviceDidMutate = true
            
            self.lastAttachment = r.content!.parts[0]
            self.device.attachments = self.device.attachments.filter() {
                $0 != oldRef
            }
            
            completionHandler(self.device)
        }
    }
    
    func primaryDataPoints(_ device: C8yDevice) -> [C8yDataPoints.DataPoint] {
               
       //TODO: link this to C8yModels
       
        if (device.dataPoints != nil && device.dataPoints!.dataPoints.count > 0) {
            return device.dataPoints!.dataPoints
       } else {
            return []
       }
    }
    
    func makeError<T>(_ response: JcRequestResponse<T>) -> Error? {

        if (response.status != .SUCCESS) {
            if (response.httpMessage != nil) {
                return C8yDeviceUpdateError.reason(response.httpMessage)
            } else if (response.error != nil){
                return C8yDeviceUpdateError.reason(response.error?.localizedDescription)
            } else {
                return C8yDeviceUpdateError.reason("undocumented")
            }
        } else {
            return nil
        }
    }
}
