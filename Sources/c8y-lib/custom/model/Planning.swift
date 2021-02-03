//
//  Planning.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_PLANNING = "xPlanning"

class C8yPlanningAssetDecoder: C8yCustomAssetFactory {
    
    static func register() {
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_PLANNING, decoder: C8yPlanningAssetDecoder())
    }
    
    override func make() -> C8yCustomAsset {
        return C8yPlanning()
    }
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
                
        return try container.decode(C8yPlanning.self, forKey: key)
    }
}

public struct C8yPlanning: C8yCustomAsset {
    
    public var isDeployed: Bool = false
    public var deployedDate: Date?
    public var planningDate: Date? = nil
    public var projectOwner: String? = nil

    enum CodingKeys : String, CodingKey {
        case isDeployed = "xPlanningIsDeployed"
        case deployedDate = "xPlanningDeployedDate"
        case planningDate = "xPlanningDate"
        case projectOwner = "xPlanningProjectOwner"
    }
    
    init() {
        
    }
    
    public init(from decoder: Decoder) throws {
        
        fatalError("init(from:) has not been implemented, as is should never get called (Duh!!), should have called decode(container:forKey:)")
        
       /* let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if (container.contains(.planningDate)) {
            self.planningDate = try container.decode(Date.self, forKey: .planningDate)
        }
        
        if (container.contains(.planningDate)) {
            self.projectOwner = try container.decode(String.self, forKey: .projectOwner)
        }
        
        if (container.contains(.isDeployed)) {
            self.isDeployed = try container.decode(Bool.self, forKey: .isDeployed)
        }
            
        if (container.contains(.deployedDate)) {
            self.deployedDate = try container.decode(Date.self, forKey: .deployedDate)
        }
        
        super.init()*/
    }
    
    public func isDifferent(_ planning: C8yPlanning?) -> Bool {
        
        if (planning == nil) {
            return true
        } else {
            return self.deployedDate != planning?.deployedDate || self.isDeployed != planning?.isDeployed || self.planningDate != planning?.planningDate || self.projectOwner != planning?.projectOwner
        }
    }
    
    public func encodex(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {

        var copy = container
        
        try copy.encode(self.isDeployed, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "xPlanningIsDeployed")!)
        
        if (self.deployedDate != nil) {
           try copy.encode(self.deployedDate, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "xPlanningDeployedDate")!)
        }
        
        if (self.planningDate != nil) {
            try copy.encode(self.planningDate, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "xPlanningDate")!)
        }
                
        if (self.projectOwner != nil) {
            try copy.encode(self.projectOwner, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "xPlanningProjectOwner")!)
        }
        
        return copy
    }
    
    public mutating func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> Void {
        
        switch forKey.stringValue {
            case CodingKeys.isDeployed.stringValue:
                isDeployed = try container.decode(Bool.self, forKey: forKey)
            case CodingKeys.deployedDate.stringValue:
                do { deployedDate = try container.decode(Date.self, forKey: forKey) } catch {}
            case CodingKeys.planningDate.stringValue:
                do { planningDate = try translateISO8601Date(container, forKey: forKey) } catch {}
            case CodingKeys.projectOwner.stringValue:
                projectOwner = try container.decode(String.self, forKey: forKey)
            default:
                break // do nothing
        }
    }
    
    private func translateISO8601Date(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey key: C8yCustomAssetProcessor.AssetObjectKey) throws -> Date? {
            
        if (container.contains(key)) {
            return C8yManagedObject.dateFormatter().date(from: try container.decode(String.self, forKey: key))
        } else {
            return nil
        }
    }
}
