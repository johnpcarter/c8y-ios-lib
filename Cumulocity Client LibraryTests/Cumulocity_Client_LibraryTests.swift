//
//  Cumulocity_Client_LibraryTests.swift
//  Cumulocity Client LibraryTests
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import XCTest
@testable import Cumulocity_Client_Library

class Cumulocity_Client_LibraryTests: XCTestCase {

    private let _conn: C8yCumulocityConnection = C8yCumulocityConnection(tenant: "frpresales", server: "cumulocity.com")
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        var result: JcRequestResponse<C8yCumulocityUser>? = nil
        let promise = expectation(description: "Status code: 200")

        _ = _conn.connect(user: "john", password: "6pmJp73FaKS9") { (response: JcRequestResponse<C8yCumulocityUser>) in
           
            result = response
            
            if (response.status == .SUCCESS) {
                
                print("\(String(describing: response.content?.firstName)), \(String(describing: response.content?.lastName)) connected okay")
                
            }
            
            promise.fulfill()
        }
        
        wait(for: [promise], timeout: 10)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.status, .SUCCESS)
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testGetManagedObjects() throws {
        
        var result: JcRequestResponse<C8yPagedManagedObjects>? = nil
        let promise = expectation(description: "Status code: 200")
        
        _ = C8yManagedObjectsService(_conn).get(pageNum: 0).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                promise.fulfill()
            case .finished:
                promise.fulfill()
            }
        }, receiveValue: { (response) in
            print("page \(response.content!.statistics.currentPage) of \(String(describing: response.content!.statistics.totalPages)), size \(response.content!.statistics.pageSize)")
            
            for object in response.content!.objects {
                print("\(String(describing: object.id))")
            }
            
            result = response
        })
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.status, .SUCCESS, "Failed to connect due to \(result!.status) - \(String(describing: result!.error?.localizedDescription))")
    }

    func testGetManagedObjectsWithWitQuery() throws {
        
        var result: JcRequestResponse<C8yPagedManagedObjects>? = nil
        let promise = expectation(description: "Status code: 200")
        
        var q = C8yManagedObjectQuery()
        q.add(key: "type", op: C8yManagedObjectQuery.Operator.eq, value: "c8y_Device")
        
        _ = C8yManagedObjectsService(_conn).get(forQuery: q, pageNum: 0).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                promise.fulfill()
            case .finished:
                promise.fulfill()
            }
        }, receiveValue: { (response) in
            
            result = response

            print("page \(response.content!.statistics.currentPage) of \(response.content!.statistics.totalPages), size \(response.content!.statistics.pageSize)")
            
            for object in response.content!.objects {
                print("\(String(describing: object.id))")
            }
        })
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.status, .SUCCESS, "Failed to connect due to \(result!.status) - \(String(describing: result!.error?.localizedDescription))")
    }
    
    func testGetManagedObject() throws {
        
        var result: JcRequestResponse<C8yManagedObject>? = nil
        var p: C8yPlanning? = nil
        var c: C8yContactInfo? = nil
        
        let promise = expectation(description: "Status code: 200")
        
        _ = C8yManagedObjectsService(_conn).get("15995151").sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                promise.fulfill()
            case .finished:
                promise.fulfill()
            }
        }, receiveValue: { (response) in
            result = response
            
            print("\(String(describing: response.content?.id))")
            
            p = response.content?.properties["xPlanning"] as? C8yPlanning
            c = response.content?.properties["xContact"] as? C8yContactInfo
        })
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.status, .SUCCESS, "Failed to connect due to \(result!.status) - \(String(describing: result!.error?.localizedDescription))")
        
        XCTAssertNotNil(p)
        XCTAssertNotNil(p!.planningDate)
        XCTAssertNotNil(p!.projectOwner)

        XCTAssertNotNil(c)
        XCTAssertNotNil(c!.contact)
        XCTAssertNotNil(c!.contactEmail)
        
        print("============== \(String(describing: p?.isDeployed)) && \(String(describing: p?.planningDate))")
    }
    
    func testPostManagedObject() {
        
        var result: JcRequestResponse<C8yManagedObject>? = nil
        var p: C8yPlanning? = nil
        var c: C8yContactInfo? = nil
        var pid: String? = nil
        
        let promise = expectation(description: "Status code: 200")
               
        var managedObject = C8yManagedObject(deviceWithSerialNumber: "s12345678", name: "Test Device from iOS Unit tests", type: "c8y_Device", supplier: "test", model: "test", notes: "delete me, I don't know care", revision: "1.0", requiredResponseInterval: -1)
        
        managedObject.requiredAvailability = C8yManagedObject.C8y_RequiredAvailability(responseInterval: -1)
        
        var planning: C8yPlanning = C8yPlanning()
        planning.projectOwner = "John Carter"
        planning.planningDate = Date()
        
        var contact: C8yContactInfo = C8yContactInfo()
        contact.contact = "John Carter"
        contact.contactEmail = "john.carter@softwarag.com"
        
        managedObject.properties["xPlanning"] = planning
        managedObject.properties["xContact"] = contact

        do {
            _ = try C8yManagedObjectsService(_conn).post(managedObject, withExternalId: "98765432112", ofType: "c8y_Serial").sink(receiveCompletion: { (completion) in
                switch completion {
                case .failure(let error):
                    print(error)
                    promise.fulfill()
                case .finished:
                    print("halfway")
                }
            }, receiveValue: { (response) in
                
                print("\(String(describing: response.content?.id))")
                
                 p = response.content?.properties["xPlanning"] as? C8yPlanning
                 c = response.content?.properties["xContact"] as? C8yContactInfo
                 
                 // try to get it back using external
                 
                _ = C8yManagedObjectsService(self._conn).get(forExternalId: "98765432112", ofType: "c8y_Serial").sink(receiveCompletion: { (completion) in
                    switch completion {
                    case .failure(let error):
                        print(error)
                        promise.fulfill()
                    case .finished:
                        print("done")
                    }
                }, receiveValue: { (rr) in
                    print("Got back \(String(describing: rr.content?.id)) for managed object with serial number 9876543211")
                    pid = rr.content!.id!
                })
            })
        } catch {
            XCTFail(error.localizedDescription)
            
            promise.fulfill()
        }
        
        wait(for: [promise], timeout: 60)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.status, .SUCCESS, "Failed to connect due to \(result!.status) - \(String(describing: result!.error?.localizedDescription))")
        
        XCTAssertNotNil(p)
        
        if (p != nil) {
            XCTAssertNotNil(p!.planningDate)
            XCTAssertNotNil(p!.projectOwner)
        }
        
        XCTAssertNotNil(c)
        
        if (c != nil) {
            XCTAssertNotNil(c!.contact)
            XCTAssertNotNil(c!.contactEmail)
        }
        
        XCTAssertNotNil(pid)
    }

    func testGetManagedObjectViaExternalId() {
        
        let promise = expectation(description: "Status code: 200")
        var managedObject: C8yManagedObject? = nil
        
        _ = C8yManagedObjectsService(self._conn).get(forExternalId: "98765432112", ofType: "c8y_Serial").sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                promise.fulfill()
            case .finished:
                print("done")
                promise.fulfill()
            }
        }, receiveValue: { (response) in
            print("=======> Got back \(String(describing: response.content?.id)) for managed object with serial number 9876543211")
            managedObject = response.content
        })
        
        wait(for: [promise], timeout: 60)

        XCTAssertNotNil(managedObject)
    }
    
    func testSendalarm() {
    
        let promise = expectation(description: "Status code: 200")
        var id: String? = nil
        
        let newAlarm = C8yAlarm(forSource: "15995151", type: "no idea", description: "This is a test", status: C8yAlarm.Status.ACTIVE, severity: C8yAlarm.Severity.CRITICAL)
        
        do {
            _ = try C8yAlarmsService(self._conn).post(newAlarm) { (response) in
                
                if (response.status == .SUCCESS) {
                    id = response.content!
                } else {
                    print("test failed with \(response.httpMessage ?? "notink")")
                }
                
                promise.fulfill()
            }
            
            wait(for: [promise], timeout: 60)

        } catch {
            print("test failed with error \(error.localizedDescription)")
        }
                
        XCTAssertNotNil(id)
    }

    func testSendEvent() {
    
        let promise = expectation(description: "Status code: 200")
        var id: String? = nil
        
        let newEvent = C8yEvent(forSource: "15995151", type: "Test Event", text: "test event")
        
        do {
            _ = try C8yEventsService(self._conn).post(newEvent) { (response) in
                
                if (response.status == .SUCCESS) {
                    id = response.content!
                } else {
                    print("test failed with \(String(describing: response.httpMessage))")
                }
                
                promise.fulfill()
            }
            
            wait(for: [promise], timeout: 60)

        } catch {
            print("test failed with error \(error.localizedDescription)")
        }
                
        XCTAssertNotNil(id)
    }
    
    func testSendComplexEvent() {
       
       let promise = expectation(description: "Status code: 200")
       var id: String? = nil
       
        let newEvent = C8yEvent(forSource: "15995151", type: "TestEvent", text: "test complex event", eventObject: TestEvent())
       
       do {
           _ = try C8yEventsService(self._conn).post(newEvent) { (response) in
               
               if (response.status == .SUCCESS) {
                   id = response.content!
               } else {
                print("test failed with \(String(describing: response.httpMessage))")
               }
               
               promise.fulfill()
           }
           
           wait(for: [promise], timeout: 60)

       } catch {
           print("test failed with error \(error.localizedDescription)")
       }
               
       XCTAssertNotNil(id)
    }
    
    func testGetEvents() {
    
        let promise = expectation(description: "Status code: 200")
        var count: Int = 0
            
        C8yCustomAssetProcessor.registerCustomPropertyClass(property: "TestEvent", decoder: TestEventFactory())
        
        _ = C8yEventsService(self._conn).get(source: "15995151", pageNum: 0) { (response) in
            
            if (response.status == .SUCCESS) {
                print("page \(response.content!.statistics.currentPage) of \(String(describing: response.content!.statistics.totalPages)), size \(response.content!.statistics.pageSize)")
                
                for object in response.content!.events {
                    print("\(String(describing: object.id))")
                }
                
                count = response.content!.events.count
                
                promise.fulfill()
            }
        }
        
        wait(for: [promise], timeout: 60)

        XCTAssertTrue(count > 0)
    }
    
    func testGetEvent() {
            
        let promise = expectation(description: "Status code: 200")
        var event: C8yEvent? = nil
           
       C8yCustomAssetProcessor.registerCustomPropertyClass(property: "TestEvent", decoder: TestEventFactory())
       
       _ = C8yEventsService(self._conn).get("15995939") { (response) in
           
           if (response.status == .SUCCESS) {
               
               event = response.content!
               
               promise.fulfill()
           }
       }
       
       wait(for: [promise], timeout: 60)

       XCTAssertNotNil(event)
    }
    
    func testSendMeasurement() {
    
        let promise = expectation(description: "Status code: 200")
        var ok: String? = "ok"
        
        do {
            var m = C8yMeasurement(fromSource: "15995151", type: "c8y_Temperature")
            m.addValues([C8yMeasurement.MeasurementValue(18.5, unit: "C", withLabel: "Living Room")], forType: "mean")
            
            _ = try C8yMeasurementsService(self._conn).post([m]) { (response) in
                
                if (response.status == .SUCCESS) {
                    print("done")
                } else {
                    ok = response.httpMessage
                }
                
                promise.fulfill()
            }
            
            wait(for: [promise], timeout: 60)
        } catch {
            ok = error.localizedDescription
        }
        
        XCTAssertEqual(ok, "ok")
    }
    
    func testGetMeasurements() {
    
        let promise = expectation(description: "Status code: 200")
        var ok: String? = "ok"
        
        _ = C8yMeasurementsService(self._conn).get(forSource: "15995151", pageNum: 0, from: Date().addingTimeInterval(TimeInterval(-24 * 3600)), to: Date(), reverseDateOrder: true) { (response) in
                
            if (response.status == .SUCCESS) {
                print("done")
            } else {
                ok = response.httpMessage
            }
            
            promise.fulfill()
        }
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertEqual(ok, "ok")
    }
    
    func testGetSeries() {
    
        let promise = expectation(description: "Status code: 200")
        var ok: String? = "ok"
        
        _ = C8yMeasurementsService(self._conn).getSeries(forSource: "15995151", type: "c8y_Temperature", series: "mean", from: Date().addingTimeInterval(TimeInterval(-24 * 3600)), to: Date(), aggregrationType: C8yMeasurementSeries.AggregateType.HOURLY) { (response) in
                
            if (response.status == .SUCCESS) {
                print("done")
            } else {
                ok = response.httpMessage
            }
            
            promise.fulfill()
        }
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertEqual(ok, "ok")
    }
    
    func testSendGetBinaryData() {
    
        let promise = expectation(description: "Status code: 200")
        var ok: String? = "ok"
        
        _ = C8yBinariesService(self._conn).post(name: "14742603_15849563977256864441769513288013.jpg", contentType: "application/jpeg", content: Data("bum".utf8)) { (response) in
            
            if (response.status == .SUCCESS) {
                
                _ = C8yBinariesService(self._conn).get(response.content!.parts[0].id!) { (r) in
                        
                    if (r.status == .SUCCESS) {
                        print("got back \(String(decoding: r.content!.parts[0].content, as: UTF8.self))")
                    } else {
                        ok = r.httpMessage
                    }
                        
                    promise.fulfill()
                }
            } else {
                ok = response.httpMessage
                promise.fulfill()
            }
        }
        
        wait(for: [promise], timeout: 60)
        
        XCTAssertEqual(ok, "ok")

    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

class TestEventFactory: C8yCustomAssetDecoder {
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
               
        return try container.decode(TestEvent.self, forKey: key)
    }
}

class TestEvent: C8yCustomAsset {
    
    func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
                
        var copy = container
        try copy.encode(self, forKey: forKey)
            
        return copy
    }
    
    let name: String
    let value: String
    
    enum CodingKeys : String, CodingKey {
        case name
        case value
    }
    
    init() {
        self.name = "wow"
        self.value = "pow"
    }
    
    required init(from decoder: Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.value = try container.decode(String.self, forKey: .value)
    }
    
    func decode(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
        
    }
}
