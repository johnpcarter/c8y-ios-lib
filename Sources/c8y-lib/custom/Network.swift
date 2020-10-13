//
//  Network.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 15/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_NETWORK_TYPE = "LoRa Network Server type"
let C8Y_NETWORK_INSTANCE = "LNS Instance"

public class C8yNetworks: ObservableObject {
    
    @Published public var providers: [String] = []
    
    public var networkProviders: [String:[C8yDeviceNetworkInstance]] = [:]
    
    private var _cancellable: Set<AnyCancellable> = []
    
    private var _conn: C8yCumulocityConnection?

	public static func provision(_ device: C8yDevice, conn: C8yCumulocityConnection) throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		switch device.network.type {
			case C8yNetworkType.lora.rawValue:
				let lora = C8yLoRaNetworkService(conn)
				return try lora.provision(device)
			default:
				throw UnknownNetworkTypeError(type: device.network.type)
		}
	}
	
	public static func deprovision(_ device: C8yDevice, conn: C8yCumulocityConnection) throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		switch device.network.type {
			case C8yNetworkType.lora.rawValue:
				let lora = C8yLoRaNetworkService(conn)
				return try lora.deprovision(device)
			default:
				throw UnknownNetworkTypeError(type: device.network.type)
		}
	}
	
	public struct UnknownNetworkTypeError: Error {
		
		public var type: String?
	}
	
    init(_ conn: C8yCumulocityConnection?) {
        self._conn = conn
        self.loadNetworkProviders(networkType: C8Y_NETWORK_TYPE)
    }
    
    public func loadNetworkProviders(networkType: String) {

        self.networkProviders = [:]
        
		if (self._conn == nil) {
			return
		}
		
        C8yManagedObjectsService(self._conn!).get(forType: networkType, pageNum: 0)
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
                case .failure(let error):
                    print(error)
                case .finished:
                    self.providers = self.networkProviders.keys.sorted()
            }
        }, receiveValue: { (response) in
            
            if (response.content != nil) {
                for object in response.content!.objects {
                    
                    let networkInfo = C8yDeviceNetworkProvider(object)
                    
                    self.networkInstances(provider: networkInfo.lnsId)
                    self.networkProviders[networkInfo.lnsId] = []
                }

            }
        }).store(in: &self._cancellable)
    }
    
    public func networkInstances(provider: String) {

        var q = C8yManagedObjectQuery()
        q.add(key: "lnsId", op: .eq, value: provider)
        q.add(key: "type", op: .eq, value: C8Y_NETWORK_INSTANCE)
        
        C8yManagedObjectsService(self._conn!).get(forQuery: q, pageNum: 0).sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                
            case .finished:
                print("done")
            }
        }, receiveValue: { (response) in
            
            var instances: [C8yDeviceNetworkInstance] = []
            
            for m in response.content!.objects {
                instances.append(C8yDeviceNetworkInstance(m))
            }
            
            self.networkProviders[provider] = instances
            
        }).store(in: &self._cancellable)
    }
}

public enum C8yNetworkType: String, CaseIterable, Hashable, Identifiable {
       
    case none = "Device Credentials"
    case lora = "LoRa"
    case sigfox = "SigFox"
       
    public var id: C8yNetworkType {self}
}

public struct C8yDeviceNetworkProvider {

    public let name: String
    public let lnsId: String

    init(_ m: C8yManagedObject) {
        
        if (m.properties[CY_LORA_NETWORK_TYPE_ID] is C8yStringWrapper) {
            let n = (m.properties[CY_LORA_NETWORK_TYPE_ID] as! C8yStringWrapper).value
            self.name = m.name!
            self.lnsId = n
        } else {
            // old version, shouldn't be used any more
            
            let ni = m.properties[CY_LORA_NETWORK] as! C8yLoRaNetworkInfo
            self.name = ni.name
            self.lnsId = ni.id
        }
    }
}

public struct C8yDeviceNetworkInstance {

    public let id: String
    public let name: String

    public var useName: String?
    public var password: String?
    
    public var apiKey: String?
    
    init(_ m: C8yManagedObject) {

        self.id = m.id!
        name = m.name!
    }
}
