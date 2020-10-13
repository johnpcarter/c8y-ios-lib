//
//  C8yMockedMyGroups.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 13/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

public class C8yMockedAssetCollection : C8yAssetCollection {
            
    var saintJaques: C8yGroup? = nil
    var libr: C8yGroup? = nil
    var shop: C8yGroup? = nil
    var car: C8yGroup? = nil
    
    public override init() {
                
        super.init()
        
        setup()
    }
    
    public func setConnection(_ conn: C8yCumulocityConnection) {
        self.connection = conn
    }
    
    public func newDevice() -> C8yDevice {
        
        return makeDevice(nil, name: "New Device", model: "c8y_Device", category: .Alarm, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
    }
    
    public func testDevice(_ id: String) -> C8yDevice {
        
        return makeDevice(id, name: "Device with id \(id)", model: "tado-smart-thermostat", category: .Temperature, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
    }
    
	public func testDeviceWithChildren(_ id: String) -> C8yDevice {
	
		var device = makeDevice(id, name: "Device with id \(id)", model: "c8y_Device", category: .Alarm, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
		device.children = [AnyC8yObject(testDevice("434334")), AnyC8yObject(testDevice("3223354"))]

		return device
	}
	
    public func testDevice() -> C8yDevice {
        
        return saintJaques!.device(forId: "D0001")!
    }

    public func testDevice2() -> C8yDevice {
        
        return saintJaques!.device(forId: "D0002")!
    }
    
    public func testDevice3() -> C8yDevice {

        return saintJaques!.device(forId: "D0003")!
    }

    public func testDevice4() -> C8yDevice {

        return saintJaques!.device(forId: "D0003")!
    }

    public func testDevice7() -> C8yDevice {

        return shop!.device(forId: "D0007")!
    }
    
    public func testGroup() -> C8yGroup {
        
        return saintJaques!
    }
    
    public func testGroup2() -> C8yGroup {
        
        return libr!
    }
    
    public func testGroup3() -> C8yGroup {
        
        return shop!
    }
    
    public override func load(_ conn: C8yCumulocityConnection?, c8yReferencesToLoad: [String], includeSubGroups: Bool) -> AnyPublisher<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError> {
        // do nothing
        let p = PassthroughSubject<[AnyC8yObject], JcConnectionRequest<C8yCumulocityConnection>.APIError>()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            p.send(completion: .finished)
        }
        
        return p.eraseToAnyPublisher()
    }
    
    private func setup() {
    
        var saintJaques = makeSiteGroup("SJ0001", name: "Ecole Saint Jaques, 75005", category: .organisation, organisationType: .School)
        
        saintJaques.position = C8yManagedObject.Position(lat: 48.85003920540231, lng: 2.3466991482459334, alt: 0)
        saintJaques.setExternalIds([C8yExternalId(withExternalId: "56445345", ofType: C8yEditableGroup.GROUP_ID_TYPE)])
        saintJaques.info.address = C8yAddress(addressLine1: "12, rue Saint Jaques", city: "Paris", postCode: "75003", country: "France", phone: "0303033")
        saintJaques.info.siteOwner = C8yContactInfo("John Carter", phone: "0622851648", email: "john.carter@softwareag.com")
        saintJaques.info.subName = "Educational Institute"
        saintJaques.info.planning = C8yPlanning()
        saintJaques.info.planning?.planningDate = Date()
        
        var libr = makeSiteGroup("EYR0001", name: "Libraire Eyrolles", category: .organisation, organisationType: .Commercial)
        var shop = makeSiteGroup("FR0001", name: "Franprix", category: .organisation, organisationType: .Commercial)
        let car = makeSiteGroup("REN0001", name: "Renault", category: .organisation, organisationType: .Industrial)

        libr.position = C8yManagedObject.Position(lat: 48.8576378, lng: 2.3505911, alt: 0)

        shop.position = C8yManagedObject.Position(lat: 48.8504704, lng: 2.3473746, alt: 0)

        var buildA = makeBuildingGroup("SJB001", name: "Building A", category: .building)
        var buildB = makeBuildingGroup("SJB002", name: "Building B", category: .building)
        
        var device1 = makeDevice("D0001", name: "Device 1 in A", model: "acs-switch", category: .Temperature, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
        device1.position = C8yManagedObject.Position(lat: 48.850158350000555, lng: 2.345681232918291, alt: 0)
        
        var device2 = makeDevice("D0002", name: "Device 2 in A", model: "c8y_Device", category: .Router, status: .UNAVAILABLE, criticalAlarms: 3, majorAlarms: 2, minorAlarms: 1, warningAlarms: 1)
        device2.position = C8yManagedObject.Position(lat: 48.8496215, lng: 2.3494371, alt: 0)
        
        var device3 = makeDevice("D0003", name: "Device 1 in B", model: "c8y_Device", category: .Camera, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
        device3.position = C8yManagedObject.Position(lat: 48.8509226, lng: 2.345821, alt: 0)
		device3.network = C8yAssignedNetwork(isProvisioned: false)
        device3.network.type = "loRa"
        
        var device4 = makeDevice("D0004", name: "Device 2 in B", model: "c8y_Device", category: .Temperature, status: .MAINTENANCE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
        device4.position = C8yManagedObject.Position(lat: 48.851885, lng: 2.3432522, alt: 0)
            
        buildA.position = C8yManagedObject.Position(lat: 48.8501583500005556, lng: 2.345681232918290, alt: 0)
        buildB.position = C8yManagedObject.Position(lat: 48.8509227, lng: 2.3458212, alt: 0)
        
        buildA.addToGroup(device1)
        buildA.addToGroup(device2)
        buildB.addToGroup(device3)
        buildB.addToGroup(device4)

        saintJaques.addToGroup(buildA)
        saintJaques.addToGroup(buildB)
        
        let device5 = makeDevice("D0005", name: "Device in Lib", model: "c8y_Device", category: .Temperature, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
        let device6 = makeDevice("D0006", name: "Device in Lib", model: "c8y_Device", category: .Temperature, status: .AVAILABLE, criticalAlarms: 0, majorAlarms: 0, minorAlarms: 0, warningAlarms: 0)
        libr.addToGroup(device5)
        libr.addToGroup(device6)
        
        let device7 = makeDevice("D0007", name: "Device 1 in Franprix", model: "c8y_Device", category: .Light, status: .MAINTENANCE, criticalAlarms: 0, majorAlarms: 3, minorAlarms: 0, warningAlarms: 1)
        shop.addToGroup(device7)
        
        self.add(saintJaques)
        self.add(libr)
        self.add(shop)
        self.add(car)
        
        self.saintJaques = saintJaques
        self.libr = libr
        self.car = car
        self.shop = shop
        
        self.objects = [AnyC8yObject(saintJaques), AnyC8yObject(libr), AnyC8yObject(shop), AnyC8yObject(car)]
    }
    
    private func makeSiteGroup(_ c8yId: String, name: String, category: C8yGroupCategory, organisationType: C8yOrganisationCategory) -> C8yGroup {
        
        var p: C8yPlanning = C8yPlanning()
        p.planningDate = Date()
        p.projectOwner = "John"
       
        var c: C8yContactInfo = C8yContactInfo()
        c.contact = "John Carter"
        c.contactEmail = "john.carter@softwareag.com"
        c.contactPhone = "0622851648"
        
        _ = C8yAddress(addressLine1: "53, Boulevard Saint Germain", city: "Paris", postCode: "75005", country: "FRANCE", phone: "01223232")
           
        return C8yGroup(c8yId, name: name, category: .organisation, parentGroupName: nil, notes: "How now brown cow, this is a mocked object")
    }
    
    private func makeBuildingGroup(_ c8yId: String, name: String, category: C8yGroupCategory) -> C8yGroup {
        
       var p: C8yPlanning = C8yPlanning()
       p.planningDate = Date()
       p.projectOwner = "John"
     
       var c: C8yContactInfo = C8yContactInfo()
       c.contact = "John Carter"
       c.contactEmail = "john.carter@softwareag.com"
       c.contactPhone = "0622851648"
      
       let newGroup = C8yGroup(c8yId, name: name, category: .building, parentGroupName: nil, notes: "How now brown cow, this is a mocked object")
        
        return newGroup
    }
    
    private func makeDevice(_ c8yId: String?, name: String, model: String, category: C8yDeviceCategory, status: C8yManagedObject.AvailabilityStatus, criticalAlarms: Int, majorAlarms: Int, minorAlarms: Int, warningAlarms: Int) -> C8yDevice {
           
        var device: C8yDevice = C8yDevice(c8yId, serialNumber: "123456789", withName: name, type: "c8y_device", supplier: "apple", model: model, notes: "Mocked device, how now now brown cow", requiredResponseInterval: 30, revision: "1.1.1", category: category)
            
        device.wrappedManagedObject.activeAlarmsStatus = C8yManagedObject.ActiveAlarmsStatus(warning: warningAlarms, minor: minorAlarms, major: majorAlarms, critical: criticalAlarms)
        device.wrappedManagedObject.connectionStatus = C8yManagedObject.ConnectionStatus(status: .CONNECTED)
        device.wrappedManagedObject.availability = C8yManagedObject.Availability(status: status, lastMessage: Date().advanced(by: -3000))
        device.wrappedManagedObject.relayState = .CLOSED
        device.webLink = "https://www.apple.com"
        device.setExternalIds([C8yExternalId(withExternalId: "EXT-\(c8yId ?? "xxx")", ofType: "IMEI")])
        device.wrappedManagedObject.supportedOperations = [C8Y_OPERATION_RESTART, C8Y_OPERATION_COMMAND, "c8y_Property_TEMP_ROOM"]
        device.wrappedManagedObject.activeAlarmsStatus = C8yManagedObject.ActiveAlarmsStatus(warning: 1, minor: 2, major: 3, critical: 1)
        
        return device
    }
}
