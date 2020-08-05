//
//  LoRaService.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 19/06/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public class C8yLoRaService: JcConnectionRequest<C8yCumulocityConnection> {
    
    public func post(_ device: C8yDevice, appEUI: String, appKey: String) throws -> AnyPublisher<JcRequestResponse<C8yManagedObject>, APIError> {
        
        let externalId: String = device.externalIds[
        var req: String = """
        {
            \"appEUI\": \"\(appEUI)\",
            \"appKey\": \"\(appKey)\",
            \"devEUI\": \"string\",
            \"deviceModel\": \"string\",
            \"lat\": \(device.position?.lat ?? 0),
            \"lng\": \(device.position?.lng ?? 0),
            \"name\": \"\(device.name)\"
        }
        """
        
        return try super._execute(method: JcConnectionRequest.Method.POST, resourcePath: C8Y_MANAGED_OBJECTS_API, contentType: "application/json", request: object).map({ (response) -> JcRequestResponse<C8yManagedObject> in
            let location: String = response.httpHeaders![JC_HEADER_LOCATION] as! String
            let id = String(location[location.index(location.lastIndex(of: "/")!, offsetBy: 1)...])
            var updatedObject = object
            updatedObject.updateId(id)
            
            return JcRequestResponse<C8yManagedObject>(response, content: updatedObject)
        }).eraseToAnyPublisher()
    }
}
