//
//  Network.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 15/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

import CoreLocation

public let C8Y_NETWORK_NONE = "Device Credentials"

let C8Y_DEVICE_AGENT = "c8y_Device_Agent"

let JC_MANAGED_OBJECT_NETWORK_TYPE = "agent"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGTYPE = "provisioningInput"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGCATEGORY = "category"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_CREATIONURL = "defineUrl"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGURL = "provisioningUrl"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_DEPROVISIONINGURL = "deprovisioningUrl"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_INFOMESSAGE = "infoMessage"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGMESSAGE = "provisioningMessage"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGPOSTMESSAGE = "provisioningPostMessage"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_TYPE = "providerType"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_INSTANCEQUERYKEY = "queryKeyForInstance"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROPERTIES = "provisioningProperties"
let JC_MANAGED_OBJECT_NETWORK_PROVIDER_DEVICE_TYPE = "deviceType"
let JC_MANAGED_OBJECT_NETWORK_OAUTH2 = "oauth2"
let JC_MANAGED_OBJECT_NETWORK_INSTANCE_TOKEN = "instanceQuery"

/**
List available connection agents, associated providers and their connections
*/
public class C8yNetworkAgentManager: ObservableObject {
	
	@Published public var types: [String] = []
	@Published public var networkTypes: [String:C8yNetworkAgent] = [:]
		
	@Published public var deviceModels: C8yDeviceModels = C8yDeviceModels()
	
	public init(_ controlTemplates: C8yOperationTemplateDelegate? = nil) {
			
		self.types = [C8Y_NETWORK_NONE]
		self.deviceModels.operationTemplateDelegate = controlTemplates
	}
	
	public func load(_ conn: C8yCumulocityConnection) {
		
		self.loadAgents(conn)
		self.loadModels(conn)
	}
	
	public func loadModels(_ conn: C8yCumulocityConnection) {
	
		self.deviceModels.load(conn)
	}
	
	public func loadAgents(_ conn: C8yCumulocityConnection) {
		
		C8yManagedObjectsService(conn).get(forType: C8Y_DEVICE_AGENT, pageNum: 0)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				switch completion {
					case .failure(let error):
						// TODO: report error
						print(error)
					case .finished:
						break
				}
			}, receiveValue: { response in
				
				if (response.content != nil) {
					
					self.networkTypes = [:]
					self.types = [C8Y_NETWORK_NONE]
					
					for object in response.content!.objects {
						
						let networkInfo = C8yNetworkAgent(object)
						
						if (networkInfo.providerManagedObjectType != nil) {
							networkInfo.load(conn: conn)
								.receive(on: RunLoop.main)
								.subscribe(Subscribers.Sink(receiveCompletion: { success in
								
								}, receiveValue: { result in
									if (result) {
										self.networkTypes[networkInfo.type] = networkInfo
										self.types.append(networkInfo.type)
									}
								}))
						} else {
							self.networkTypes[networkInfo.type] = networkInfo
							self.types.append(networkInfo.type)
						}
					}
				}
			}
		))
	}
	
	public func define(_ network: C8yNetworkAgent, properties: [String:String], location: CLLocation? = nil, conn: C8yCumulocityConnection) -> AnyPublisher<C8yDevice, Error> {
			
		return C8yNetworkProvisioningService(network, conn: conn).makeDevice(properties)
	}
	
	public func provision(_ device: C8yDevice, conn: C8yCumulocityConnection) throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		let network = self.networkTypes[device.network.type]
		
		if (network != nil) {
					
			return try C8yNetworkProvisioningService(network!, conn: conn).provision(device)
	
		} else {
			throw UnknownNetworkTypeError(type: device.network.type)
		}
	}
	
	public func deprovision(_ device: C8yDevice, conn: C8yCumulocityConnection) throws -> AnyPublisher<C8yDevice, JcConnectionRequest<C8yCumulocityConnection>.APIError> {
		
		let network = self.networkTypes[device.network.type]

		if (network != nil) {
			
			return try C8yNetworkProvisioningService(network!, conn: conn).deprovision(device)
			
		} else {
			throw UnknownNetworkTypeError(type: device.network.type)
		}
	}

	public struct UnknownNetworkTypeError: Error {
		
		public var type: String?
	}
}

/**
Represents definition for a network provider type
*/
public class C8yNetworkAgent {
	
	public let id: String
	public let name: String

	public internal(set) var type: String // lora, sigfox etc -- linked to model
	public internal(set) var category: String // must match a valid SF Symbol!!
	public internal(set) var properties: [String:C8yProperty] = [:]
	
	public internal(set) var provisioningType: ProvisioningType
	public internal(set) var defineUrl: String?
	public internal(set) var provisioningUrl: String
	public internal(set) var deprovisioningUrl: String?
	
	public internal(set) var infoMessage: String?
	public internal(set) var provisioningMessage: String?
	public internal(set) var provisioningPostMessage: String?
	
	public internal(set) var providerManagedObjectType: String? // use value to filter for managed objects that describe providers for this type e.g. "LoRa Network Server type"
	public internal(set) var queryForProviderInstances: String? // query argument used to filter for managed objects that represent instances for provider e.g. LNSType eq 'objenious'
	
	public internal(set) var deviceType: String? = nil
		
	public internal(set) var providers: [C8yNetworkProvider] = [] // built from above arguments
	
	public enum ProvisioningType: String {
		case manual = "manual"
		case oauth2 = "oauth2"
	}
	
	public init(_ object: C8yManagedObject) {

		self.id = object.id!
		self.name = object.name!
		self.type = (object.properties[JC_MANAGED_OBJECT_NETWORK_TYPE] as! C8yStringCustomAsset).value
		self.category = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGCATEGORY] as! C8yStringCustomAsset).value
		self.provisioningType = ProvisioningType(rawValue: (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGTYPE] as? C8yStringCustomAsset)?.value ?? "manual") ?? .manual
		self.defineUrl = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_CREATIONURL] as? C8yStringCustomAsset)?.value
		self.provisioningUrl = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGURL] as! C8yStringCustomAsset).value
		self.deprovisioningUrl = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_DEPROVISIONINGURL] as? C8yStringCustomAsset)?.value
		self.infoMessage = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_INFOMESSAGE] as? C8yStringCustomAsset)?.value
		self.provisioningMessage = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGMESSAGE] as? C8yStringCustomAsset)?.value
		self.provisioningPostMessage = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROVISIONINGPOSTMESSAGE] as? C8yStringCustomAsset)?.value
		self.providerManagedObjectType = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_TYPE] as? C8yStringCustomAsset)?.value
		self.queryForProviderInstances = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_INSTANCEQUERYKEY] as? C8yStringCustomAsset)?.value
		
		self.deviceType = (object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_DEVICE_TYPE] as? C8yStringCustomAsset)?.value
		
		let props = object.properties[JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROPERTIES] as! C8yNetworkProviderPropertiesWrapper
		
		props.properties.forEach({ p in
			self.properties[p.name] = p
		})
	}
	
	public func load(conn: C8yCumulocityConnection) -> AnyPublisher<Bool, Never> {
		
		let onLoadPublisher = PassthroughSubject<Bool, Never>()
		
		C8yManagedObjectsService(conn).get(forType: providerManagedObjectType!, pageNum: 0)
			.receive(on: RunLoop.main)
			.subscribe(Subscribers.Sink(receiveCompletion: { completion in
				// nothing to do
				
			}, receiveValue: { response in
				
				if (response.content != nil) {
					
					for object in response.content!.objects {
												
						if (self.queryForProviderInstances != nil) {
							
							// we have to fetch the predefined provider connections from c8y
							
							var q = C8yManagedObjectQuery()
							q.add(key: self.queryForProviderInstances!, op: .eq, value: ((object.properties[self.queryForProviderInstances!] as! C8yStringCustomAsset).value))
							
							//q.add(key: "lnsId", op: .eq, value: provider)
							//q.add(key: "type", op: .eq, value: C8Y_NETWORK_INSTANCE)
							
							C8yManagedObjectsService(conn).get(forQuery: q, pageNum: 0)
								.receive(on: RunLoop.main)
								.subscribe(Subscribers.Sink(receiveCompletion: {completion in
								
								switch completion {
									case .failure:
										onLoadPublisher.send(false)
									case .finished:
										onLoadPublisher.send(true)
								}
								
								onLoadPublisher.send(completion: .finished)
							}, receiveValue: { response in
								
								var connections: [C8yNetworkProviderInstance] = []
								
								for m in response.content!.objects {
									connections.append(C8yNetworkProviderInstance(m))
								}
								
								self.providers.append(C8yNetworkProvider(object, connections: connections))
							}))
						} else {
							// no predefined connection instances, add provider as is.
							
							self.providers.append(C8yNetworkProvider(object))
							onLoadPublisher.send(true)
							onLoadPublisher.send(completion: .finished)
						}
					}
				} else {
					onLoadPublisher.send(false)
					onLoadPublisher.send(completion: .finished)
				}
			}))
		
		return onLoadPublisher.eraseToAnyPublisher()
	}
	
	public func provider(for name: String) -> C8yNetworkProvider? {
		
		var provider: C8yNetworkProvider? = nil
		
		self.providers.forEach( { p in
			if (p.name == name) {
				provider = p
			}
		})
		return provider
	}
	
	public func isValid(properties: [String:String]) -> Bool {
		
		var isValid = true
		
		self.properties.forEach( { k, v in
			if (v.required && properties[k] == nil) {
				isValid = false
			}
		})
		
		return isValid
	}
}

/**
Attributes required to identify a new provider instance
*/
public struct C8yNetworkProvider {
	
	public internal(set) var name: String // equiv to instance e.g. Objenious
	public var id: String? // an API key or oauth client id
	public var secret: String? // nil or oauth client secret

	public internal(set) var description: String?
	public internal(set) var properties: [String:C8yCustomAsset] = [:]
	public internal(set) var oauth2: OAuth2?
	
	public internal(set) var connections: [C8yNetworkProviderInstance] = []
	
	init(_ name: String, apiKey: String, secret: String) {
		
		self.name = name
		self.id = apiKey
		self.secret = secret
	}
	
	 init(_ object: C8yManagedObject, connections: [C8yNetworkProviderInstance] = []) {
		self.name = object.name ?? ""
		self.id = object.applicationId
		self.description = object.notes
		self.connections = connections
		self.properties = object.properties
		
		if (object.properties[JC_MANAGED_OBJECT_NETWORK_OAUTH2] != nil) {
			self.oauth2 = OAuth2((object.properties[JC_MANAGED_OBJECT_NETWORK_OAUTH2] as! C8yDictionaryCustomAsset).value)
		}
	}
	
	public func connection(for id: String) -> C8yNetworkProviderInstance? {
		
		var conn: C8yNetworkProviderInstance? = nil
		
		self.connections.forEach( { c in
			if (c.id == id) {
				conn = c
			}
		})
		return conn
	}
	
	public struct OAuth2 {
		
		public var authorisationUrl: String
		public var accessToken: String
		public var clientId: String
		public var clientSecret: String
		public var scope: String?
		public var requestUrl: String?
		public var requestMethod: String?
		public var requestPayload: String?
		
		init(_ dict: [String:String]) {
			
			self.authorisationUrl = dict["authorisationUrl"]!
			self.accessToken = dict["accessToken"]!
			self.clientId = dict["clientId"]!
			self.clientSecret = dict["clientSecret"]!
			self.scope = dict["scope"]
			
			self.requestUrl = dict["requestUrl"]
			self.requestMethod = dict["requestMethod"]
			self.requestPayload = dict["requestPayload"]
		}
	}
}

/**
attribute of device to define specific connection
*/
public struct C8yNetworkProviderInstance {
		
	public var id: String
	public var name: String  // equiv to instance e.g. sag
	public var type: String
	public internal(set) var properties: [String:C8yCustomAsset] = [:]

	init(_ object: C8yManagedObject) {
		
		self.id = object.id!
		self.name = object.name!
		self.type = object.type
		self.properties = object.properties
	}
}

class C8yNetworkProviderPropertiesWrapperDecoder: C8yCustomAssetFactory {
   
	static func register() {
		C8yCustomAssetProcessor.registerCustomPropertyClass(property: JC_MANAGED_OBJECT_NETWORK_PROVIDER_PROPERTIES, decoder: C8yNetworkProviderPropertiesWrapperDecoder())
	}
	
	override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
		
		return try container.decode(C8yNetworkProviderPropertiesWrapper.self, forKey: key)
	}
}

struct C8yNetworkProviderPropertiesWrapper: C8yCustomAsset {
	
	public internal(set) var properties: [C8yProperty] = []
	
	enum CodingKeys: String, CodingKey {
		case properties
	}
	
	public init(from decoder: Decoder) throws {
		
		let container = try decoder.container(keyedBy: CodingKeys.self)
				
		self.properties = try container.decode([C8yProperty].self, forKey: .properties)
	}
	
	public mutating func decodex(_ container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>, forKey: C8yCustomAssetProcessor.AssetObjectKey) throws {
		
		self.properties = try container.decode([C8yProperty].self, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "properties")!)
	}
}
