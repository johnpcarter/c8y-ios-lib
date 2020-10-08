//
//  LoRaService.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 19/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

let C8Y_NETWORK_ENDPOINT = "/service/lora-ns-{TYPE}/{LNS_INSTANCE_ID}/devices"
let C8Y_NETWORK_LORA_DEVEUI = "LoRa devEUI"

internal class C8yLoRaNetworkService: JcConnectionRequest<C8yCumulocityConnection> {
        
    public func provision(_ device: C8yDevice) throws -> AnyPublisher<C8yDevice, APIError> {
        
        if (device.externalIds[C8Y_NETWORK_LORA_DEVEUI] == nil || device.network.type == nil || device.network.instance == nil || device.network.appKey == nil || device.network.appEUI == nil) {
            throw APIError(httpCode: -1, reason: "Invalid request, missing network credentials")
        }
        
        let externalId: String = device.externalIds[C8Y_NETWORK_LORA_DEVEUI]!.externalId
        
        let req: String = """
        {
            \"appEUI\": \"\(device.network.appEUI!)\",
            \"appKey\": \"\(device.network.appKey!)\",
            \"devEUI\": \"\(externalId)\",
            \"deviceModel\": \"\(device.model))\",
            \"lat\": \(device.position?.lat ?? 0),
            \"lng\": \(device.position?.lng ?? 0),
            \"name\": \"\(device.name)\"
        }
        """
        
        return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: path(provider: device.network.provider!, lnsInstanceId: device.network.instance!), contentType: "application/json", request: Data(req.utf8))
			.tryMap{ response -> C8yDevice in
				
				if (response.status == .SUCCESS) {
					var d = device
					d.isDeployed = true
					
					return d
				} else {
					throw APIError(httpCode: response.httpStatus, reason: response.httpMessage)
				}

			}.mapError { error -> APIError in
				switch (error) {
				case let error as JcConnectionRequest<C8yCumulocityConnection>.APIError:
					return error
				default:
					return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: error.localizedDescription)
				}
			}.combineLatest(try self.updateIsProvisionedProperty(device, isProvisioned: true))
			.map{ device, nowt -> C8yDevice in
				return device
			}.eraseToAnyPublisher()
    }
    
	public func deprovision(_ device: C8yDevice) throws -> AnyPublisher<C8yDevice, APIError>  {
		
		return super._delete(resourcePath: path(provider: device.network.provider!, lnsInstanceId: device.network.instance!, devEUI: device.externalIds[C8Y_NETWORK_LORA_DEVEUI]!.externalId))
			.tryMap { response -> C8yDevice in
				
				if (response.content!) {
					
					var d = device
					d.isDeployed = false
					
					return d
				} else {
					throw APIError(httpCode: response.httpStatus, reason: response.httpMessage)
				}
			}.mapError { error -> APIError in
				switch (error) {
				case let error as JcConnectionRequest<C8yCumulocityConnection>.APIError:
					return error
				default:
					return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: error.localizedDescription)
				}
			}.combineLatest(try self.updateIsProvisionedProperty(device, isProvisioned: false))
			.map{ device, nowt -> C8yDevice in
				return device
			}.eraseToAnyPublisher()
	}
	
	private func updateIsProvisionedProperty(_ device: C8yDevice, isProvisioned: Bool) throws -> AnyPublisher<Void, APIError> {
	
		var m: C8yManagedObject = C8yManagedObject(device.c8yId)
		
		m.network = C8yAssignedNetwork(isProvisioned: isProvisioned)
		m.network!.type = C8yNetworkType.lora.rawValue
		
		return try C8yManagedObjectsService(self._connection).put(m)
			.tryMap({ response -> Void in
				if (response.status != .SUCCESS) {
					throw APIError(httpCode: response.httpStatus, reason: response.httpMessage)
				}
			}).mapError { error -> APIError in
				switch (error) {
				case let error as JcConnectionRequest<C8yCumulocityConnection>.APIError:
					return error
				default:
					return JcConnectionRequest<C8yCumulocityConnection>.APIError(httpCode: -1, reason: error.localizedDescription)
				}
			}.eraseToAnyPublisher()
	}
	
    private func path(provider: String, lnsInstanceId: String, devEUI: String) -> String {
           
        return  path(provider: provider, lnsInstanceId: lnsInstanceId) + "/" + devEUI
    }
    
    private func path(provider: String, lnsInstanceId: String) -> String {
           
        return  C8Y_NETWORK_ENDPOINT.replacingOccurrences(of: "{TYPE}", with: provider).replacingOccurrences(of: "{LNS_INSTANCE_ID}", with: lnsInstanceId)
    }
}
