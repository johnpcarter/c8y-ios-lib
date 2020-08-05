//
//  C8yMockedMyGroups.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 13/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation


class MockedData : C8yMyGroups {
    
    override var groups: [AnyC8yObject] = []
    
    override init() {
        
        var p: C8yPlanning = C8yPlanning()
         p.planningDate = Date()
         p.projectOwner = "John"
        
         var c: C8yContactInfo = C8yContactInfo()
         c.contact = "John Carter"
         c.contactEmail = "john.carter@softwareag.com"
         c.contactPhone = "0622851648"
         
         var a = C8yAddress(addressLine1: "53, Boulevard Saint Germain", city: "Paris", zipCode: "75005", country: "FRANCE", phone: "01223232")
            
         var group = C8yMockedManager.shared.addGroup("Ecole Saint Jaques, Paris, 75005", orgCategory: .School, category: .organisation, planning: p, contact: c, notes: "Test Group", address: a, location: "5th floor, toilet")
         _ = C8yMockedManager.shared.addGroup("Libraire Eyrolles", orgCategory: .Commercial, category: .organisation, planning:nil, contact: nil, notes: "Test Group")
         _ = C8yMockedManager.shared.addGroup("Ecole Saint Jaques", orgCategory: .School, category: .organisation, planning: nil, contact: nil, notes: "Test Group")
         _ = C8yMockedManager.shared.addGroup("Franprix", orgCategory: .Commercial, category: .organisation, planning: nil, contact: nil, notes: "Test Group")
         _ = C8yMockedManager.shared.addGroup("Renault", orgCategory: .Industrial, category: .organisation, planning: nil, contact: nil, notes: "Test Group")

         _ = C8yMockedManager.shared.addDevice(groupId: "Ecole Saint Jaques, Paris, 75005", name: "ACS-Guage", type: "c8y_temperature", model: "ACS-SWITCH", notes: "Test Device", location: "5th floor, reception", operationLevel: C8yOperationLevel.failing, critical: 0, major: 2, minor: 0, warning: 0)
         _ = C8yMockedManager.shared.addDevice(groupId: "Ecole Saint Jaques, Paris, 75005", name: "Light", type: "c8y_temp", model: "Other", notes: "Test Device", location: "5th floor, reception", operationLevel: C8yOperationLevel.nominal, critical: 0, major: 0, minor: 0, warning: 0)
         _ = C8yMockedManager.shared.addDevice(groupId: "Ecole Saint Jaques, Paris, 75005", name: "Light", type: "c8y_temp", model: "Other", notes: "Test Device", location: "5th floor, reception", operationLevel: C8yOperationLevel.offline, critical: 1, major: 0, minor: 0, warning: 0)
         _ = C8yMockedManager.shared.addDevice(groupId: "Libraire Eyrolles", name: "ACS-Guage", type: "c8y_temperature", model: "ACS-SWITCH", notes: "Test Device", location: "5th floor, reception", operationLevel: C8yOperationLevel.failing, critical: 1, major: 0, minor: 0, warning: 0)
         
         let ga: C8yGroup = group.addGroup("Classe A", category: .room, planning: nil, contact: nil, address: a, notes: "Classroom for kids")
         _ = group.addGroup("Classe B", category: .room, planning: nil, contact: nil, address: a, notes: "Classroom for kids")
         
         _ = (ga as! C8yMockedGroup).addMockedDevice("Temperature", type: "c8y_Temperature", model: "tado thermostat", notes: "how now brown cow testing 123", operationLevel: .operating, location: "Site B, Classe A", critical: 2, major: 1, minor: 0, warning: 0)
         
         _ = (ga as! C8yMockedGroup).addMockedDevice("Temperature", type: "c8y_Temperature", model: "tado thermostat", notes: "how now brown cow testing 123", operationLevel: .nominal, location: "Site B, Classe A", critical: 2, major: 1, minor: 0, warning: 0)
         
         return group
    }
    
    private func setup() {
    
        var saintJaques = makeSiteGroup("12345", name: "Ecole Saint Jaques, Paris, 75005", orgCategory: .organisation, category: .)
    }
    
    private func makeSiteGroup(_ c8yId: String, name: String, orgCategory: C8yGroupCategory, category: C8yGroupCategory) -> C8yGroup {
        
        var p: C8yPlanning = C8yPlanning()
        p.planningDate = Date()
        p.projectOwner = "John"
       
        var c: C8yContactInfo = C8yContactInfo()
        c.contact = "John Carter"
        c.contactEmail = "john.carter@softwareag.com"
        c.contactPhone = "0622851648"
        
        var a = C8yAddress(addressLine1: "53, Boulevard Saint Germain", city: "Paris", zipCode: "75005", country: "FRANCE", phone: "01223232")
           
        var group = C8yGroup(c8yId, name: name, category: .organisation, location: nil, notes: "How now brown cow, this is a mocked object", flattenSubGroups: false)
    }
    
    private func addGroupToGroup(_ c8yId: String, name: String, parentGroup: C8yGroup) -> C8yGroup {
           
            var p: C8yPlanning = C8yPlanning()
            p.planningDate = Date()
            p.projectOwner = "John"
          
            var c: C8yContactInfo = C8yContactInfo()
            c.contact = "John Carter"
            c.contactEmail = "john.carter@softwareag.com"
            c.contactPhone = "0622851648"
           
            var newGroup = C8yGroup(c8yId, name: name, category: .organisation, location: nil, notes: "How now brown cow, this is a mocked object", flattenSubGroups: false)
            parentGroup.addToGroup(c8yIdOfGroup: group.c8yId, object: group)
    }
    
    private func addGroupToGroup(_ c8yId: String, name: String, model: String, category: C8yDeviceCategory, parentGroup: C8yGroup) -> C8yGroup {
           
        var device: C8yDevice = C8yDevice(c8yId, serialNumber: "123456789", withName: name, type: "c8y_device", supplier: "apple", model: model, notes: "Mocked device, how now now brown cow", requiredResponseInterval: 1, revision: "1.1.1", category: category)
           
            var newGroup = C8yGroup(c8yId, name: name, category: .organisation, location: nil, notes: "How now brown cow, this is a mocked object", flattenSubGroups: false)
            parentGroup.addToGroup(c8yIdOfGroup: group.c8yId, object: group)
    }
}
