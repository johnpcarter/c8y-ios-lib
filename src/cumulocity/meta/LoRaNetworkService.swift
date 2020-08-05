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

public class C8yLoRaNetworkService: JcConnectionRequest<C8yCumulocityConnection> {
    
    private var cancellable: [AnyCancellable] = []
    
    public func provision(_ device: C8yDevice, completionHandler: @escaping (APIError?) -> Void) throws {
        
        if (device.externalIds[C8Y_NETWORK_LORA_DEVEUI] == nil || device.network.type == nil || device.network.instance == nil || device.network.appKey == nil || device.network.appEUI == nil) {
            throw APIError(httpCode: -1, reason: "Invalid request, missing network credentials")
        }
        
        let externalId: String = device.externalIds[C8Y_NETWORK_LORA_DEVEUI]!.externalId
        
        let req: String = """
        {
            \"appEUI\": \"\(device.network.appEUI!)\",
            \"appKey\": \"\(device.network.appKey!)\",
            \"devEUI\": \"\(externalId)\",
            \"deviceModel\": \"\(device.model ?? "undefined"))\",
            \"lat\": \(device.position?.lat ?? 0),
            \"lng\": \(device.position?.lng ?? 0),
            \"name\": \"\(device.name)\"
        }
        """
        
        super._execute(method: JcConnectionRequest.Method.POST, resourcePath: path(provider: device.network.provider!, lnsInstanceId: device.network.instance!), contentType: "application/json", request: Data(req.utf8))
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                completionHandler(error)
            case .finished:
                completionHandler(nil)
            }
        }, receiveValue: { r in
            // do nothing
            
        }).store(in: &self.cancellable)
    }
    
    public func deprovision(_ device: C8yDevice, completionHandler: @escaping (APIError?) -> Void) {
        
        return super._delete(resourcePath: path(provider: device.network.provider!, lnsInstanceId: device.network.instance!, devEUI: device.externalIds[C8Y_NETWORK_LORA_DEVEUI]!.externalId))
            .receive(on: RunLoop.main)
            .sink(receiveCompletion: { (completion) in
            switch completion {
            case .failure(let error):
                print(error)
                completionHandler(error)
            case .finished:
                completionHandler(nil)
            }
        }, receiveValue: { r in
            // do nothing
            
        }).store(in: &self.cancellable)
    }
    
    private func path(provider: String, lnsInstanceId: String, devEUI: String) -> String {
           
        return  path(provider: provider, lnsInstanceId: lnsInstanceId) + "/" + devEUI
    }
    
    private func path(provider: String, lnsInstanceId: String) -> String {
           
        return  C8Y_NETWORK_ENDPOINT.replacingOccurrences(of: "{TYPE}", with: provider).replacingOccurrences(of: "{LNS_INSTANCE_ID}", with: lnsInstanceId)
    }
}
