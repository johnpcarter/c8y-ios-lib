//
//  Planning.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let JC_MANAGED_OBJECT_PLANNING = "xPlanning"
let JC_MANAGED_OBJECT_PLANNING_IS_DEPLOYED = "xPlanningIsDeployed"
let JC_MANAGED_OBJECT_PLANNING_DATE = "xPlanningDate"
let JC_MANAGED_OBJECT_ATTACHMENTS = "xAttachmentIds"
let JC_MANAGED_OBJECT_PLANNING_OWNER = "xPlanningProjectOwner"

class JcPlanningBuilder: JcCustomAssetFactory<JcPlanning> {
    
    static func register() {
        JcAssetDecoder.shared.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_PLANNING, builder: JcPlanningBuilder())
    }
    
    override func make(_ values: Any) -> JcPlanning {
        return JcPlanning(values as! Dictionary)
    }
}

class JcPlanning: Codable {
    
    var isDeployed: Bool = false
    var planningDate: Date? = nil
    var attachmentIds: [String] = []
    var projectOwner: String? = nil
    
    init(_ data: Dictionary<String, Any>) {
    
        if (data[JC_MANAGED_OBJECT_PLANNING_IS_DEPLOYED] != nil) {
            self.isDeployed = data[JC_MANAGED_OBJECT_PLANNING_IS_DEPLOYED] as! String == "true"
        }
        
        if (data[JC_MANAGED_OBJECT_PLANNING_DATE] != nil) {
            self.planningDate = ISO8601DateFormatter.init().date(from: data[JC_MANAGED_OBJECT_PLANNING_DATE] as! String)
        }
        
        if (data[JC_MANAGED_OBJECT_ATTACHMENTS] != nil) {
            self.attachmentIds = data[JC_MANAGED_OBJECT_ATTACHMENTS] as! [String]
        }
        
        if (data[JC_MANAGED_OBJECT_PLANNING_OWNER] != nil) {
            self.projectOwner = data[JC_MANAGED_OBJECT_PLANNING_OWNER] as? String
        }
    }
}
