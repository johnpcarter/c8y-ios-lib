//
//  NewDevice.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yEditableDevice: ObservableObject, Equatable {
        
    public static func == (lhs: C8yEditableDevice, rhs: C8yEditableDevice) -> Bool {
        return lhs.c8yId == rhs.c8yId
    }
    
    public private(set) var madeChanges: Bool = false
    
    @Published public var externalId: String = "" {
        didSet {
            if (!self._ignoreChanges) {
                self.idChanged.send(self.externalId + self.externalIdType)
            }
        }
    }
    
    @Published public var externalIdType: String = "c8y_Serial" {
        didSet {
            if (!self._ignoreChanges) {
                self.idChanged.send(self.externalId + self.externalIdType)
            }
        }
    }
    
    @Published public var c8yId: String = ""
    
    @Published public var name: String = "" {
        didSet {
            self.emitDidChange(self.name)
        }
    }
    
    @Published public var type: String = "" {
        didSet {
            self.emitDidChange(self.type)
        }
    }
    
    @Published public var revision: String = "" {
        didSet {
            self.emitDidChange(self.revision)
        }
    }
    
    @Published public var firmware: String = "" {
        didSet {
            self.emitDidChange(self.firmware)
        }
    }
    
    @Published public var supplier: String = "generic" {
        didSet {
            self.emitDidChange(self.supplier)
        }
    }
    
    //@Published
    public var model: String = "" {
        didSet {
            self.emitDidChange(self.model)
        }
    }
    
    @Published public var notes: String = "" {
        didSet {
            self.emitDidChange(self.notes)
        }
    }
    
    @Published public var requiredResponseInterval: Int = -1 {
        didSet {
            self.emitDidChange(String(self.requiredResponseInterval))
        }
    }
    
    @Published public var operations: [String] = [] {
        didSet {
            //self.emitDidChange(self.operations)
        }
    }
    
    @Published public var dataPoints: C8yDataPoints? {
        didSet {
            //self.emitDidChange(self.dataPoints as Any)
        }
    }

    // extras
    
    @Published public var networkType: C8yNetworkType = .none {
        didSet {
            
            self.emitDidChange(self.networkType.rawValue)
        }
    }
    
    @Published public var networkProvider: String = "" {
        didSet {
            self.emitDidChange(self.networkProvider)
        }
    }
    
    @Published public var networkInstance: String = "" {
        didSet {
            self.emitDidChange(self.networkInstance)
        }
    }
    
    @Published public var networkAppKey: String = "" {
        didSet {
            self.emitDidChange(self.networkAppKey)
        }
    }

    @Published public var networkAppEUI: String = "" {
        didSet {
            self.emitDidChange(self.networkAppEUI)
        }
    }
    
    @Published public var category: C8yDeviceCategory = .Unknown {
        didSet {
            self.emitDidChange(self.category.rawValue)
        }
    }

    public var isDeployed: Bool {
        get {
            if (self._deviceWrapper != nil) {
                return self._deviceWrapper!.device.isDeployed
            } else {
                return self.networkType == .none || self.networkInstance.count > 0
            }
        }
    }
    
    @Published public var webLink: String = ""
        
    public var group: C8yGroup? = nil
    
    public var isNew: Bool {
        get {
            return c8yId.isEmpty
        }
    }
    
    public enum LookupResponse: String {
        case Error
        case NewDevice
        case UnDeployedDevice
        case DeployedDevice
    }
    
    public let idChanged = PassthroughSubject<String, Never>()

    public var externalIdChanged: AnyPublisher<String, Never> {
        return self.idChanged
            .removeDuplicates()
            .map { input in
                return self.externalId
            }.eraseToAnyPublisher()
    }
        
    public let didChange = PassthroughSubject<String, Never>()
    
    public var onChange: AnyPublisher<C8yEditableDevice, Never> {
        return self.didChange
        .debounce(for: 0.8, scheduler: RunLoop.main)
        .removeDuplicates()
        .map { input in
            return self
        }.eraseToAnyPublisher()
    }
    
    private var _ignoreChanges: Bool = false
    private var _deviceWrapper: C8yMutableDevice? = nil
    
    private var _lastMessage: Date? = nil
    private var _lastUpdated: Date? = nil
    private var _lastStatus: C8yManagedObject.AvailabilityStatus?
    private var _lastPosition: C8yManagedObject.Position?
    
    public init() {
    
    }
    
    public convenience init(group: C8yGroup?) {
        self.init()
        self.group = group
    }
    
    public convenience init(_ device: C8yDevice) {
        
        self.init()
        
        self.mergeDevices(device)
        
        if (device.externalIds.count > 0) {
            self.externalId = device.externalIds.values.first!.externalId
            self.externalIdType = device.externalIds.values.first!.type
        } else {
            self.externalId = "-undefined-"
        }
    }
    
    public convenience init(group: C8yGroup?, deviceWrapper: C8yMutableDevice) {
        
        self.init(deviceWrapper.device)
        self.group = group
        
        _deviceWrapper = deviceWrapper
    }
    
    public init(_ id: String, name: String, supplierName: String?, modelName: String, category: C8yDeviceCategory, operations: [String], revision: String?, firmware: String?,  requiredResponseInterval: Int) {
        
        self.externalId = id
        self.externalIdType = "UUID"
        self.name = name
        
        if (supplierName != nil) {
            self.supplier = supplierName!//C8ySupplier(supplierId, name: supplierName, networkType: networkType, site: supplierWebSite)
        }
        
        self.model = modelName//C8yModel(modelId, name: modelName, category: category, link: modelWebLink)
        self.category = category
        self.operations = operations
        self.requiredResponseInterval = requiredResponseInterval
        
        if (revision != nil) {
            self.revision = revision!
        }
        
        if (firmware != nil) {
            self.firmware = firmware!
        }
    }
    
    public func clear() {
            
        self._ignoreChanges = true
        
        self.externalId = ""
        self.c8yId = ""
        self.dataPoints = C8yDataPoints()
        self.notes = ""
        self.webLink = ""
        self.name = ""
        self.supplier = ""
        self.model = ""
        self.operations = []
        self.revision = ""
        self.firmware = ""
        self.networkType = .none
        self.networkAppEUI = ""
        self.networkAppKey = ""
        self.networkInstance = ""
        self.networkProvider = ""
        
        self._ignoreChanges = false
    }
    
    public func updateId(_ id: String, ofType type: String) {
        
        self._ignoreChanges = true
        self.externalId = id
        self.externalIdType = type
        
        self._ignoreChanges = false
        
        self.idChanged.send(self.externalId + self.externalIdType)
    }
    
    public func clearIds() {
    
        self._ignoreChanges = true
        self.externalId = ""
        self.externalIdType = "c8y_Serial"
        self._ignoreChanges = false
        
    }
    
    private var _cachedPos: C8yManagedObject.Position? = nil
    
    public func toDevice() -> C8yDevice {
        return toDevice(_cachedPos)
    }
    
    public func toDevice(_ position: C8yManagedObject.Position?) -> C8yDevice {
        
        self._cachedPos = position
        
        var device: C8yDevice = C8yDevice(self.c8yId, serialNumber: self.externalIdType == "c8y_Serial" && self.externalId != "-undefined-" ? self.externalId : nil, withName: self.name, type: self.category.rawValue, supplier: self.supplier != "generic" ? self.supplier : nil, model: self.model, notes: self.notes, requiredResponseInterval: self.requiredResponseInterval, revision: self.revision, category: self.category)
                
        if (self._lastPosition != nil) {
            device.position = self._lastPosition
        }
        
        if (self._lastUpdated != nil) {
            device.wrappedManagedObject.lastUpdated = self._lastUpdated!
        }
        
        if (self._lastMessage != nil) {
            device.wrappedManagedObject.availability = C8yManagedObject.Availability(status: self._lastStatus!, lastMessage: self._lastMessage!)
        }
        
        device.webLink = self.webLink
        device.wrappedManagedObject.dataPoints = self.dataPoints
        device.wrappedManagedObject.supportedOperations = self.operations
        
        if (self.type != "") {
            device.wrappedManagedObject.type = self.type
        } else {
            device.wrappedManagedObject.type = "c8yDevice"
        }
        
        if (self.networkType != .none) {
            
            if (device.network == nil) {
                device.network = C8yAssignedNetwork(self._deviceWrapper?.device.network == nil ? false: self._deviceWrapper?.device.network.isProvisioned)
            }
            
            device.network.type = self.networkType.rawValue
            device.network.provider = self.networkProvider
            device.network.instance = self.networkInstance
            device.network.appKey = self.networkAppKey
            device.network.appEUI = self.networkAppEUI
            
            if (self.networkType == .lora) {
                device.wrappedManagedObject.type = "c8y_LoRaDevice"
            } else if (self.networkType == .sigfox) {
                device.wrappedManagedObject.type = "c8y_SigfoxDevice"
            }
                  
        } else {
            
            if (device.network == nil) {
                device.network = C8yAssignedNetwork()
            }
            
            device.network.type = C8yNetworkType.none.rawValue
            device.network.provider = nil
            device.network.instance = nil
        }
        
        if (self.externalId != "-undefined-") {
            device.externalIds[self.externalIdType] = C8yExternalId(withExternalId: self.externalId, ofType: self.externalIdType)
        } else if (self._deviceWrapper != nil) {
            device.externalIds = self._deviceWrapper!.device.externalIds
        }
        
        if (position != nil) {
            device.wrappedManagedObject.updatePosition(latitude: position!.lat, longitude: position!.lng, altitude:  position?.alt)
        }
        
        if (self._deviceWrapper != nil) {
            _deviceWrapper!.device = device
        }
        
        return device
    }
    
    public func mergeDevices(_ c8yDevice: C8yDevice) {
    
        self._ignoreChanges = true
        
        if (c8yDevice.c8yId != "_new_") {
            self.c8yId = c8yDevice.c8yId
        }
    
        if (c8yDevice.name != c8yDevice.model && c8yDevice.name != c8yDevice.type) {
            self.name = c8yDevice.name
        }

        if (c8yDevice.supplier != nil) {
            self.supplier = c8yDevice.supplier!
        }
        
        if (c8yDevice.model != nil) {
            self.model = c8yDevice.model!
        }
        
        if (c8yDevice.revision != nil) {
            self.revision = c8yDevice.revision!
        }
        
        if (c8yDevice.firmware != nil) {
            self.firmware = c8yDevice.firmware!
        }
        
        self.operations = c8yDevice.operations
        
        if (c8yDevice.lastMessage != nil) {
            self._lastMessage = c8yDevice.lastMessage
        }
        
        self._lastStatus = c8yDevice.wrappedManagedObject.availability?.status
        
        if (c8yDevice.lastUpdated != nil) {
            self._lastUpdated = c8yDevice.lastUpdated
        }
        
        if (c8yDevice.position != nil) {
            self._lastPosition = c8yDevice.position
        }
        
        if (c8yDevice.notes != nil) {
            self.notes = c8yDevice.notes!
        }
        
        if (c8yDevice.requiredResponseInterval != nil) {
            self.requiredResponseInterval = c8yDevice.requiredResponseInterval!
        }
        
        if (c8yDevice.dataPoints != nil) {
            self.dataPoints = c8yDevice.dataPoints!
        }
        
        // external id's
        
        if (c8yDevice.externalIds.count > 0) {
            self.externalIdType = c8yDevice.externalIds.keys.first!
            self.externalId = c8yDevice.externalIds[self.externalIdType]!.externalId
        }
        
        // extras
        
        if (c8yDevice.network != nil) {
        
            if (c8yDevice.network!.type != nil) {
                self.networkType = C8yNetworkType(rawValue: c8yDevice.network!.type!)!
            }
            
            if (c8yDevice.network!.provider != nil) {
                self.networkProvider = c8yDevice.network!.provider!
            }
            
            if (c8yDevice.network!.instance != nil) {
                self.networkInstance = c8yDevice.network!.instance!
            }
            
            if (c8yDevice.network!.appKey != nil) {
                self.networkAppKey = c8yDevice.network!.appKey!
            }
            
            if (c8yDevice.network!.appEUI != nil) {
                self.networkAppEUI = c8yDevice.network!.appEUI!
            }
        }
        
        self.type = c8yDevice.type != nil ? c8yDevice.type! : ""
        self.category = c8yDevice.deviceCategory
        
        if (c8yDevice.supplier != nil) {
            self.supplier = c8yDevice.supplier!
        }
        
        if (c8yDevice.webLink != nil) {
            self.webLink = c8yDevice.webLink!
        }
        
        self._ignoreChanges = false
    }
    
    private func emitDidChange(_ v: String) {
        if (!self._ignoreChanges) {
            self.madeChanges = true
            self.didChange.send(v)
        }
    }
}
