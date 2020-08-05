//
//  DeviceManager.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 13/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

import CoreLocation

public class C8yMutableDevice: ObservableObject  {
    
    @Published public var device: C8yDevice
    
    @Published public var position: CLLocationCoordinate2D? = nil {
        didSet {
            if (position != nil) {
                device.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
            }
        }
    }

    @Published public var reloadMetrics: Bool = false {
        didSet {
            
            if (self.reloadMetrics) {
                self.updateMetricsForToday()
            }
        }
    }
    
    @Published public var reloadLogs: Bool = false {
        didSet {
               
            if (self.reloadLogs) {
                self.updateEventLogsForToday()
            }
        }
    }
    
    @Published public var reloadAlarms: Bool = false {
        didSet {
            if (self.reloadAlarms) {
                self.updateAlarmsForToday()
            }
        }
    }
    
    @Published public var reloadOperations: Bool = false {
        didSet {
            if (self.reloadOperations) {
                self.updateOperationHistory()
            }
        }
    }
    
    public var primaryMetric: Measurement = Measurement()
    
    @Published public var primaryMetricHistory: MeasurementSeries = MeasurementSeries()

    public var primaryMetricUpdate: AnyPublisher<Measurement, Never> {

        if (self._monitorPublisher == nil) {
            return self.startMonitorForPrimaryMetric()
        } else {
            return self._monitorPublisher!.eraseToAnyPublisher()
        }
    }
    
    @Published public var measurements: [String:[C8yMeasurement]] = [:]

    @Published public var events: [C8yEvent] = []
    
    @Published public var alarms: [C8yAlarm] = []
    
    @Published public var operations: [C8yOperation] = []
    
    public private(set) var isMonitoring: Bool = false
       
    private var _include: Bool = false
    public var includePrimaryMetricHistory: Bool = false {
        willSet {
            _include = self.includePrimaryMetricHistory
        }
        didSet {
            if !self._include && self.includePrimaryMetricHistory && self._preferredMetric != nil {
                self.fetchMostRecentPrimaryMetric(self._preferredMetric)
                    .receive(on: RunLoop.main)
                    .sink { m in
                    self.primaryMetric = m
                }.store(in: &self._cancellable)
            }
        }
    }
    
    public internal(set) var lastAttachment: JcMultiPartContent.ContentPart? = nil

    public var conn: C8yCumulocityConnection?

    public var callBackForReloadMetrics: (() -> Void)?
    
    public var relayState: C8yManagedObject.RelayStateType? {
        get {
            return self.device.wrappedManagedObject.relayState
        }
    }
    
    private var _deviceMetricsTimer: JcRepeatingTimer?
    
    private var _preferredMetric: String?
    private var _refreshInterval: TimeInterval = -1
    private var _cancellable: [AnyCancellable] = []
    private var _monitorPublisher: CurrentValueSubject<Measurement, Never>?
    
    public init() {
        self.device = C8yDevice()
    }
    
    public init(_ device: C8yDevice, preferredMetric: String?, connection: C8yCumulocityConnection, refreshMetricsInterval: TimeInterval, dataSource: C8yMyGroups? = nil) {
        
        self.device = device
        self.conn = connection
        self._preferredMetric = preferredMetric
        
        if (self.device.position != nil) {
            self.position = CLLocationCoordinate2D(latitude: device.position!.lat, longitude: device.position!.lng)
        }
        
        if (refreshMetricsInterval > -1) {
            if (self.device.requiredResponseInterval != nil && Double(self.device.requiredResponseInterval!*60) > refreshMetricsInterval) {
                self._refreshInterval = Double(self.device.requiredResponseInterval!) * 60
            } else {
                self._refreshInterval = refreshMetricsInterval
            }
        }
        
        if (dataSource != nil && device.externalIds.count == 0) {
            dataSource!.fetchExternalIds(device.c8yId) { success, externalIds in
            
                if (success) {
                    self.device.setExternalIds(externalIds)
                }
            }
        }
    }
    
    deinit {
        self.stopMonitoring()
    }
    
    public func setup(_ device: C8yDevice, connection: C8yCumulocityConnection) {
        self.device = device
        self.conn = connection
        if (self.device.position != nil) {
            self.position = CLLocationCoordinate2D(latitude: device.position!.lat, longitude: device.position!.lng)
        }
    }
    
    private var _cachedResponseInterval: Int = 30
        
    public func toggleMaintainanceMode() throws {
            
        if (device.wrappedManagedObject.requiredAvailability == nil) {
            self.device.wrappedManagedObject.requiredAvailability = C8yManagedObject.RequiredAvailability(responseInterval: -1)
        } else if (device.operationalLevel == .maintenance) {
            self.device.wrappedManagedObject.requiredAvailability!.responseInterval = self._cachedResponseInterval
        } else {
            self._cachedResponseInterval = self.device.wrappedManagedObject.requiredAvailability!.responseInterval
            self.device.wrappedManagedObject.requiredAvailability!.responseInterval = -1
        }
        
        try C8yManagedObjectsService(self.conn!).put(C8yManagedObject.init(self.device.c8yId, requiredAvailability: self.device.wrappedManagedObject.requiredAvailability!))
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
            }) { (response) in
                self.device.wrappedManagedObject.availability = C8yManagedObject.Availability(status: self.device.wrappedManagedObject.requiredAvailability!.responseInterval == -1 ? .MAINTENANCE : .AVAILABLE, lastMessage: self.device.wrappedManagedObject.availability!.lastMessage)
                self.objectWillChange.send()
        }.store(in: &self._cancellable)
    }
    
    public func toggleRelay() throws {
    
        var state: C8yManagedObject.RelayStateType = .CLOSED
        
        if (self.relayState != nil) {
            if (self.relayState! == .CLOSED) {
                state = .OPEN
            } else {
                state = .CLOSED
            }
        }
        
        var op = C8yOperation(source: self.device.c8yId, type: C8Y_OPERATION_RELAY, description: "Relay Operation")
        op.operationDetails = C8yOperation.OperationDetails(C8Y_OPERATION_RELAY_STATE, value: state.rawValue)
        
        try C8yOperationService(self.conn!).post(operation: op, version: 1)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
            }) { (response) in
                if (state == .CLOSED) {
                    self.device.wrappedManagedObject.relayState = .CLOSE_PENDING
                } else {
                    self.device.wrappedManagedObject.relayState = .OPEN_PENDING
                }
                self.operations.insert(op, at: 0)
        }.store(in: &self._cancellable)
    }
    
    public func provision(completionHandler: @escaping (Error?) -> Void) {
    
        do {
            try C8yLoRaNetworkService(self.conn!).provision(self.device) { error in
                
                if (error == nil) {
                    self.device.wrappedManagedObject.network?.isProvisioned = true
                }
                
                completionHandler(error)
            }
        } catch {
            completionHandler(error)
        }
    }
    
    public func deprovision(completionHandler: @escaping (Error?) -> Void) {
    
        C8yLoRaNetworkService(self.conn!).deprovision(self.device) { error in
            
            if (error == nil) {
                self.device.wrappedManagedObject.network?.isProvisioned = false
            }
            
            completionHandler(error)
        }
    }
    
    public func runOperation(_ op: C8yOperation) throws {
    
        try C8yOperationService(self.conn!).post(operation: op, version: 1)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                // nothing to do
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { (response) in
                self.operations.insert(op, at: 0)
                self.objectWillChange.send()
        }.store(in: &self._cancellable)
    }
    
    public func toDevicePositionUpdate() -> C8yDevice {
            
        var pd: C8yDevice = C8yDevice(self.device.c8yId)
        
        if (self.position != nil) {
            pd.position = C8yManagedObject.Position(lat: self.position!.latitude, lng: self.position!.longitude, alt: 0)
        } else {
            pd.position = self.device.position
        }
        
        return pd
    }

    public func updateMetricsForToday() {
        self.fetchAllMetricsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
                self.reloadMetrics = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.measurements = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchAllMetricsForToday() -> AnyPublisher<[String:[C8yMeasurement]], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                    
        return C8yMeasurementsService(self.conn!).get(forSource: self.device.c8yId, pageNum: 0, from: Date().advanced(by: -86400), to: Date(), reverseDateOrder: true).map({response in
            
            var results: [String:[C8yMeasurement]] = [:]
            
            for m in response.content!.measurements {
                let type = self.generaliseType(type: m.type!)
                var measurements: [C8yMeasurement]? = results[type]
                
                if (measurements == nil) {
                    measurements = []
                }
                
                measurements!.append(m)
                results[type] = measurements
            }
            
            return results

            }).eraseToAnyPublisher()
    }
    
    public func updateEventLogsForToday() {
        
        self.fetchEventLogsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadLogs = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.events = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchEventLogsForToday() -> AnyPublisher<[C8yEvent], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                    
        return C8yEventsService(self.conn!).get(source: self.device.c8yId, pageNum: 0).map({response in
            
            return response.content!.events
            
        }).eraseToAnyPublisher()
    }

    public func updateOperationHistory() {
        
        self.fetchOperationHistory()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadOperations = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.operations = results.reversed()
                
                for op in self.operations {
                    if op.type == C8Y_OPERATION_RELAY {
                        if (op.status == .SUCCESSFUL) {
                            self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType(rawValue: op.type!)
                        } else if (op.status == .FAILED) {
                            if (op.type == C8yManagedObject.RelayStateType.OPEN.rawValue) {
                                self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType.CLOSED
                            } else {
                                self.device.wrappedManagedObject.relayState = C8yManagedObject.RelayStateType.OPEN
                            }
                        }
                    }
                }
        }.store(in: &self._cancellable)
    }
    
    public func fetchOperationHistory() -> AnyPublisher<[C8yOperation], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
                      
        return C8yOperationService(self.conn!).get(self.device.c8yId).map({response in
            return response.content!.operations
        }).eraseToAnyPublisher()
    }
    
    public func updateAlarmsForToday() {
        
        self.fetchActiveAlarmsForToday()
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
                self.reloadAlarms = false
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    print("done")
                }
            }) { results in
                self.alarms = results
        }.store(in: &self._cancellable)
    }
    
    public func fetchActiveAlarmsForToday() -> AnyPublisher<[C8yAlarm], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
            
        return C8yAlarmsService(self.conn!).get(source: self.device.c8yId, status: .ACTIVE, pageNum: 0)
            .merge(with: C8yAlarmsService(self.conn!).get(source: self.device.c8yId, status: .ACKNOWLEDGED, pageNum: 0))
            .collect()
            .map({response in
                var array: [C8yAlarm] = []
        
                for p in response {
                    array.append(contentsOf: p.content!.alarms)
                }
                
                return array
        }).eraseToAnyPublisher()
    }
    
    public func fetchMostRecentPrimaryMetric(_ preferredMetric: String?) -> AnyPublisher<C8yMutableDevice.Measurement, Never> {
           
        if (device.c8yId != "_new_") {
            
            var mType: String? = nil
            var mSeries: String? = nil
            
            if (preferredMetric != nil) {
                let parts = preferredMetric!.split(separator: ".")
                mType = String(parts[0])
                mSeries = String(parts[1])
            } else if (self.primaryDataPoints(device).count > 0) {
                let metric: [C8yDataPoints.DataPoint] = self.primaryDataPoints(device)
                mType = metric[0].reference
                mSeries = metric[0].value.series
            }
            
            if (mType != nil) {
                var interval: Double =  Double(device.requiredResponseInterval == nil ? 60 : device.requiredResponseInterval! * 60)
                    
                if (self.includePrimaryMetricHistory) {
                    interval = interval * 10
                }
                
                return self.getMeasurementSeries(device, type: mType!, series: mSeries!, interval: interval, connection: self.conn!).map({response in
                    return self.populatePrimaryMetric(response, type: mType!)
                }).replaceError(with:C8yMutableDevice.Measurement())
                .eraseToAnyPublisher()
            } else {
                return Just(C8yMutableDevice.Measurement()).eraseToAnyPublisher() // dummy
            }
        } else {
            return Just(C8yMutableDevice.Measurement()).eraseToAnyPublisher() // dummy
        }
    }
    
    private func populatePrimaryMetric(_ m: C8yMeasurementSeries, type: String) -> Measurement {
     
        if (m.values.count > 0) {
            self.primaryMetric = Measurement(min: m.values.last!.values[0].min, max: m.values.last!.values[0].max, unit: m.series.last!.unit, label: m.series.last!.name, type: type)
            
            var v: [Double] = []
            var t: [String] = []
            
            for r in m.values {
                v.append(r.values[0].min)
                t.append(r.time.timeString())
            }
            
            DispatchQueue.main.async {
                self.primaryMetricHistory = MeasurementSeries(name: m.series.last!.name, label: type, unit: m.series.last!.unit, yValues: v, xValues: t)
            }
        }

        print("setting primary metric to \(String(describing: self.primaryMetric.min)) for \(self.device.name)")
        
        return self.primaryMetric
    }
    
    private func getMeasurementSeries(_ device: C8yDevice, type: String, series: String, interval: Double, connection: C8yCumulocityConnection) -> AnyPublisher<C8yMeasurementSeries, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
        
        print("Fetching metrics for device \(device.name), \(type), \(series)")
        
        return C8yMeasurementsService(connection).getSeries(forSource: device.c8yId, type: type, series: series, from: Date().addingTimeInterval(-interval), to: Date(), aggregrationType: .MINUTELY).map({response in
            return response.content!
            }).eraseToAnyPublisher()
    }
    
    public func startMonitorForPrimaryMetric(preferredMetric: String) -> AnyPublisher<C8yMutableDevice.Measurement, Never> {
        self._preferredMetric = preferredMetric
        return self.startMonitorForPrimaryMetric()
    }
        
    public func startMonitorForPrimaryMetric() -> AnyPublisher<C8yMutableDevice.Measurement, Never> {

        self._monitorPublisher = CurrentValueSubject<Measurement, Never>(Measurement())
        
        if (self._deviceMetricsTimer != nil) {
            self._deviceMetricsTimer!.suspend()
        }
        
        self.fetchMostRecentPrimaryMetric(self._preferredMetric)
            .receive(on: RunLoop.main)
            .sink(receiveValue: { (v) in
                self._monitorPublisher?.send(self.primaryMetric)
        }).store(in: &self._cancellable)
          
        self.updateOperationHistory()

        if (self._refreshInterval > -1) {
            self._deviceMetricsTimer = JcRepeatingTimer(timeInterval: self._refreshInterval)
            
            self.isMonitoring = true
            
            self._deviceMetricsTimer!.eventHandler = {
                
                self.fetchOperationHistory()
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { completion in
                    // do nothing
                    
                }, receiveValue: { (ops) in
                    
                }).store(in: &self._cancellable)
                
                self.fetchMostRecentPrimaryMetric(self._preferredMetric)
                    .receive(on: RunLoop.main)
                    .sink(receiveValue: { (v) in
                        self._monitorPublisher?.send(self.primaryMetric)
                    }).store(in: &self._cancellable)
            }
            
            self._deviceMetricsTimer!.resume()
        }
        
        return self._monitorPublisher!.eraseToAnyPublisher()
    }
    
    public func stopMonitoring() {
        
        if (self._deviceMetricsTimer != nil) {
            
            if (self._monitorPublisher != nil) {
                self._monitorPublisher!.send(completion: .finished)
            }
            
            for c in self._cancellable {
                c.cancel()
            }
            
            self._deviceMetricsTimer?.suspend()
            self.isMonitoring = false
        }
    }
        
    public func postNewAlarm(type: String, severity: C8yAlarm.Severity, text: String, completionHandler: @escaping (C8yAlarm?) -> Void) throws {
        
        var alarm = C8yAlarm(forSource: self.device.c8yId, type: type, description: text, status: C8yAlarm.Status.ACTIVE, severity: severity)
        
        try C8yAlarmsService(self.conn!).post(alarm)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { completion in
           print("done")
                
        }, receiveValue: { response in
            if (response.content != nil) {
                alarm.id = response.content!
                self.alarms.append(alarm)
                completionHandler(alarm)
            } else {
                completionHandler(nil)
            }
        }).store(in: &self._cancellable)
    }
    
    public func updateAlarm(_ alarm: C8yAlarm) throws {
    
        try C8yAlarmsService(self.conn!).put(alarm)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: {
                completion in
                switch completion {
                case .failure(let error):
                    print("failed due to \(error)")
                default:
                    for z in self.alarms.indices {
                        if self.alarms[z].id == alarm.id {
                            self.alarms[z] = alarm
                        }
                    }
                }
            }) { (result) in
                // do nothing
        }.store(in: &self._cancellable)
    }
    
    public func postOperations(_ operation: C8yOperation) {
        
    }
    
    public func statusForOperation(_ type: String) -> C8yOperation? {
    
        var op: C8yOperation? = nil
        
        for o in self.operations {
            
            if (o.type == type) {
                op = o
                break
            }
        }
        
        return op
    }
    
    public func attachmentForId(id: String) -> AnyPublisher<JcMultiPartContent.ContentPart, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        if (self.lastAttachment == nil || self.lastAttachment?.id != id) {
            
            return C8yBinariesService(self.conn!).get(id).map({ response in
                self.lastAttachment = response.content!.parts[0]
                return self.lastAttachment!
                }).eraseToAnyPublisher()
        } else {
            return Just(self.lastAttachment!).mapError { (never) -> Error in
                 return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: "Never happen!")
            }.mapError({ error -> JcConnectionRequest<C8yCumulocityConnection>.APIError in
                switch (error) {
                case let error as JcConnectionRequest<C8yCumulocityConnection>.APIError:
                    return error
                default:
                    return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: error.localizedDescription)
                }
            }).eraseToAnyPublisher()
        }
    }

    public func addAttachment(filename: String, fileType: String, content: Data) -> AnyPublisher<JcMultiPartContent.ContentPart, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        var fname = filename
        
        if (!fname.contains(".")) {
            
            if (fname.contains("png")) {
                fname += ".png"
            } else {
                fname += ".jpg"
            }
        }
        
        return C8yBinariesService(self.conn!).post(name: "\(device.c8yId)-\(fname)", contentType: fileType, content: content).map({ response in
            
            self.lastAttachment = response.content!.parts[0]
            self.device.attachments.insert(self.lastAttachment!.id!, at: 0)

            self.device.wrappedManagedObject.properties[C8Y_MANAGED_OBJECTS_ATTACHMENTS] = C8yStringWrapper(String.make(array: self.device.attachments)!)
            
            return self.lastAttachment!
        }).eraseToAnyPublisher()
    }
    
    public func replaceAttachment(index: Int, filename: String, fileType: String, content: Data) -> AnyPublisher<JcMultiPartContent.ContentPart?, JcConnectionRequest<C8yCumulocityConnection>.APIError> {

        return C8yBinariesService(self.conn!).post(name: filename, contentType: fileType, content: content).map({ response in

            let oldRef = self.lastAttachment?.id
                        
            self.lastAttachment = response.content!.parts[0]
            self.device.attachments = self.device.attachments.filter() {
                $0 != oldRef
            }
            
            return response.content!.parts[0]
        }).eraseToAnyPublisher()
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
    
    private func generaliseType(type: String) -> String {
        
        if (type.lowercased().starts(with: "min") || type.lowercased().starts(with:"max") || type.lowercased().starts(with:"avg")) {
            return type.substring(from: 4)
        } else if (type.lowercased().starts(with: "mean")) {
            return type.substring(from: 5)
        } else if (type.lowercased().starts(with: "average")) {
            return type.substring(from: 8) // TODO: Find labels for average, mean, median and standard deviation)
        } else {
            return type
        }
    }
    
    public struct MeasurementSeries {
        public var name: String?
        public var label: String?
        public var unit: String?
        public var yValues: [Double] = []
        public var xValues: [String] = []
    }
    
    public struct Measurement {
        public var min: Double?
        public var max: Double?
        public var unit: String?
        public var label: String?
        public var type: String?
        
        public init() {
            
        }
        
        public init(min: Double, max: Double, unit: String, label: String, type: String) {
            self.min = min
            self.max = max
            self.unit = unit
            self.label = label
            self.type = type
        }
    }
}
