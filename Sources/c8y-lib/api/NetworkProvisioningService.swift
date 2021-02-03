//
//  NetworkProvisioningService.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/12/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine
import CoreLocation

public class C8yNetworkProvisioningService: JcConnectionRequest<C8yCumulocityConnection> {
	
	var networkType: C8yNetworkAgent
	
	public init(_ networkType: C8yNetworkAgent, conn: C8yCumulocityConnection) {
		
		self.networkType = networkType
		
		super.init(conn)
	}
	
	/**
	
	*/
	public func makeDevice(_ properties: [String:String], location: CLLocation? = nil) -> AnyPublisher<C8yDevice, Error> {
	
		//return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: self.formatPath(self.networkType.defineUrl!, properties: properties), contentType: "application/json", request: self.creationPayload(properties: properties, location: location), headers: properties).tryMap({ (response) -> C8yDevice in
		return super._get(resourcePath: self.formatPath(self.networkType.defineUrl!, properties: properties), headers: properties).tryMap({ (response) -> C8yDevice in
			
			let m = try JcRequestResponse<C8yManagedObject>(response, dateFormatter: C8yManagedObject.dateFormatter()).content ?? C8yManagedObject()
			var device = try C8yDevice(m)
			
			var ext: C8yExternalId? = nil
			
			if (response.httpHeaders?["externalid"] != nil) {
				if (response.httpHeaders?["externalidtype"] != nil) {
					ext = C8yExternalId(withExternalId: response.httpHeaders!["externalid"] as! String, ofType: response.httpHeaders!["externalidtype"] as! String)
				} else {
					ext = C8yExternalId(withExternalId: response.httpHeaders!["externalid"] as! String, ofType: "default")
				}
			}
			
			if (ext != nil) {
				device.setExternalIds([ext!])
			}
			
			return device
			
		}).mapError({e -> Error in
			return e
		}).eraseToAnyPublisher()
	}
	
	/**
	
	 - parameter object a `ManagedObject` created locally for which the id attribute will be null
	 - returns Publisher indicating success/failure and an updated `C8yManagedObject` including the  internal id attributed by cumulocity.
	 - throws Error if the object is missing required fields
	- seeAlso get(forExternalId:ofType:)
	 */
	public func provision(_ device: C8yDevice, location: CLLocation? = nil) throws -> AnyPublisher<C8yDevice, APIError> {
			
		return super._execute(method: JcConnectionRequest.Method.POST, resourcePath: self.formatPath(self.networkType.provisioningUrl, device: device), contentType: "application/json", request: self.provisioningPayload(device: device)).map({ (response) -> C8yDevice in
				
			let location: String? = response.httpHeaders![JC_HEADER_LOCATION] as? String
			let id = location == nil ? nil : String(location![location!.index(location!.lastIndex(of: "/")!, offsetBy: 1)...])
			
			var updatedDevice = device
			updatedDevice.network.networkRef = id
			updatedDevice.network.provisioned = true
			
			return updatedDevice
		}).eraseToAnyPublisher()
	}
	
	/**
	
	 - parameter object a `ManagedObject` created locally for which the id attribute will be null
	 - returns Publisher indicating success/failure and an updated `C8yManagedObject` including the  internal id attributed by cumulocity.
	 - throws Error if the object is missing required fields
	- seeAlso get(forExternalId:ofType:)
	 */
	public func deprovision(_ device: C8yDevice) throws -> AnyPublisher<C8yDevice, APIError> {

		var url = self.networkType.deprovisioningUrl
		
		if (url == nil) {
			url = self.networkType.provisioningUrl
		}
		
		return super._execute(method: JcConnectionRequest.Method.DELETE, resourcePath: self.formatPath(url!, device: device), contentType: "application/json", request: self.provisioningPayload(device: device)).map({ (response) -> C8yDevice in
				
			var updatedDevice = device
			updatedDevice.network.networkRef = nil
			updatedDevice.network.provisioned = false
			
			return updatedDevice
			
		}).eraseToAnyPublisher()
	}
	
	func formatPath(_ rawUrl: String, properties: [String:String]) -> String {
		
		var url = rawUrl
		
		properties.forEach { k, v in
			url = url.replacingOccurrences(of: "{\(k)}", with: v.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
		}
				
		return url
	}
	
	func formatPath(_ rawUrl: String, device: C8yDevice) -> String {
		
		var url = rawUrl
		
		networkType.properties.forEach({key, property in
						
			let v = property.lookupValue(source: device.wrappedManagedObject)
			
			if (v != nil) {
				url = url.replacingOccurrences(of: "{\(key)}", with: (v as! String).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
			}
		})
		
		return url
	}
	
	func creationPayload(properties: [String:String], location: CLLocation? = nil) -> Data {
		
		var p = "{"
		
		properties.forEach { k, v in
			if (p != "{") {
				p += ", "
			}
			
			p += "\"\(k)\": \"\(v)\""
		}
				
		if (location != nil) {
			
			if (p != "{") {
				p += ", "
			}
			
			p += "\"position\": { \"lat\": \(location!.coordinate.latitude), \"lng\": \(location!.coordinate.longitude) }"
		}
		
		p += "}"
		
		return Data(p.utf8)
	}
	
	func provisioningPayload(device: C8yDevice, location: CLLocation? = nil) -> Data {
			
		var p: String = ""
		
		networkType.properties.forEach({key, property in
			
			// only include properties in payload that do not have a namespace i.e. are not populated directly into device managed object
			// thus this is the only way that the agent can get them
			
			if (!key.contains(".")) {
				if let v = property.lookupValue(source: device.wrappedManagedObject, location: location) {
					
					if (p == "") {
						p = "{"
					}
					
					p += "\"\(key)\": "
					
					if (property.type == .string || property.type == .password) {
						p += "\"\(v)\","
					} else {
						p += "\(v),"
					}
				}
			}
		})
		
		if (p.endsWith(",")) {
			p = p.subString(to: p.count-1)
		}
		
		if (p != "") {
			p += "}"
		}
		
		return Data(p.utf8)
	}
}
