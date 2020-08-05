//
//  NewDevice.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yNewDevice: ObservableObject {
    
    @Published public var externalId: String = ""
    @Published public var externalIdType: String = "c8y_Serial"
    
    @Published public var c8yId: String = ""
    @Published public var name: String = ""
    @Published public var category: C8yObjectCategory = .unknown
    @Published public var revision: String = ""
    @Published public var supplier: String = ""
    @Published public var model: String = ""
    @Published public var notes: String = ""
    @Published public var webLink: String = ""
    @Published public var isDeployed: Bool = false
    @Published public var requiredResponseInterval: Int = -1
    @Published public var operations: [String] = []
    @Published public var position: C8yManagedObject.C8y_Position?
    @Published public var dataPoints: [C8yDataPoints]?
    @Published public var networkType: String = ""
    
    public var readyToDeploy: Bool {
        get {
            return !name.isEmpty && !model.isEmpty && !externalId.isEmpty && !externalIdType.isEmpty
        }
    }
    
    public var isNew: Bool {
        get {
            return c8yId.isEmpty
        }
    }
    
    public init() {
        
    }
}
