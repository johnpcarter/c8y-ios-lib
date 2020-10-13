//
//  Cumulocity_Client_LibraryTests.swift
//  Cumulocity Client LibraryTests
//
//  Created by John Carter on 16/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Combine
import XCTest

@testable import Cumulocity_Client_Library

class Cumulocity_Client_LibraryTests: XCTestCase {

    private let _conn: C8yCumulocityConnection = C8yCumulocityConnection(tenant: "frpresales", server: "cumulocity.com")
	private var _cancellableSet: Set<AnyCancellable> = Set()
	
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
		let result: JcRequestResponse<C8yCumulocityUser>? = nil
        let promise = expectation(description: "Status code: 200")

		let conn: C8yCumulocityConnection = C8yCumulocityConnection(tenant: "<mytenant>", server: "cumulocity.com")

		conn.connect(user: "john", password: "appleseed").sink(receiveCompletion: { (completion) in
				switch completion {
				case .failure(let error):
					print("Connection refused! - \(error.localizedDescription)")
				default:
					print("Connection Success")
					
					C8yManagedObjectsService(conn).get(pageNum: 0).sink(receiveCompletion: { (completion) in
					
						switch completion {
						case .failure(let error):
							print("Get Failed \(error.localizedDescription)")
						default:
							print("Get Completed")
						}
						
					}, receiveValue: { results in
					
						if (results.status == .SUCCESS) {
					
							print("page \(results.content!.statistics.currentPage) of \(results.content!.statistics.totalPages!), size \(results.content!.statistics.pageSize)")
					
							for object in results.content!.objects {
									print("\(String(describing: object.id))")
							}
						}
					}).store(in: &self._cancellableSet)
				}
		}, receiveValue: ({ userInfo in
			
			print("User name is \(userInfo)")
			
		})).store(in: &self._cancellableSet)
		
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
        
        managedObject.requiredAvailability = C8yManagedObject.RequiredAvailability(responseInterval: -1)
        
        var planning: C8yPlanning = C8yPlanning()
        planning.projectOwner = "John Carter"
        planning.planningDate = Date()
        
        var contact: C8yContactInfo = C8yContactInfo()
        contact.contact = "John Carter"
        contact.contactEmail = "john.carter@softwarag.com"
        
        managedObject.properties["xPlanning"] = planning
        managedObject.properties["xContact"] = contact


    }

    func testGetManagedObjectViaExternalId() {
        
    }
    
    func testSendalarm() {
       
    }

    func testSendEvent() {
    
    }
    
    func testSendComplexEvent() {
     
    }
    
    func testGetEvents() {
       
    }
    
    func testGetEvent() {
            
    }
    
    func testSendMeasurement() {
    
    }
    
    func testGetMeasurements() {
    
    }
    
    func testGetSeries() {
    
    }
    
    func testSendGetBinaryData() {
    

    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

class TestEventFactory: C8yCustomAssetFactory {
    
    override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
               
        return try container.decode(TestEvent.self, forKey: key)
    }
}

class TestEvent: C8yCustomAsset {
    
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
	
	func encode(_ container: KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws -> KeyedEncodingContainer<C8yCustomAssetProcessor.AssetObjectKey> {
				
		var copy = container
		try copy.encode(self, forKey: forKey)
			
		return copy
	}
}
