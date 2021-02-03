//
//  Property.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 21/12/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import CoreLocation

/**
defines properties required by a specific type of network provider.
*/
public struct C8yProperty: Codable {
	
	public internal(set) var name: String
	public internal(set) var label: String? = nil
	public internal(set) var description: String? = nil

	public internal(set) var source: String? = nil
	
	public internal(set) var required: Bool = true
	public internal(set) var type: PropertyType = .string
	
	public internal(set) var value: String? = nil
	public internal(set) var values: [String] = []
	
	public enum PropertyType: String, Codable {
		case string
		case password
		case ip
		case bool
		case number
	}
	
	enum CodingKeys : String, CodingKey {
		case name
		case label
		case description
		case source
		case required
		case type
		case value
		case values
	}
	
	public init(from decoder: Decoder) throws {
	
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.name = try container.decode(String.self, forKey: .name)
		
		if (container.contains(.label)) {
			self.label = try container.decode(String.self, forKey: .label)
		}
		
		if (container.contains(.description)) {
			self.description = try container.decode(String.self, forKey: .description)
		}
		
		if (container.contains(.source)) {
			self.source = try container.decode(String.self, forKey: .source)
		}
		
		if (container.contains(.required)) {
			self.required = try container.decode(Bool.self, forKey: .required)
		}
		
		if (container.contains(.type)) {
			self.type = PropertyType(rawValue: try container.decode(String.self, forKey: .type)) ?? .string
		}
		
		if (container.contains(.value)) {
			self.value = try container.decode(String.self, forKey: .value)
		}
		
		if (container.contains(.values)) {
			self.values = try container.decode([String].self, forKey: .values)
		}
	}
	
	func lookupValue(source: JcProperties, location: CLLocation? = nil) -> String? {
	
		var v: String? = nil
		let k: String = self.source != nil ?  self.source! : self.name
		
		if (location != nil && (k.starts(with: "location.") || k.starts(with: "position."))) {
			let endToken = k.lastToken(".")

			if (endToken == "lng" || endToken == "longitude") {
				v = String(location!.coordinate.longitude)
			} else if (endToken == "lat" || endToken == "latitude") {
				v = String(location!.coordinate.latitude)
			}
		} else {
			
			let t = k.self.split(separator: String.Element("."))
			
			var c: Any = source
			
			t.forEach( { e in
				
				if let d = c is JcProperties ? self.prop(c as! JcProperties, for: String(e)) : (c as! Dictionary<String,Any>)[String(e)] {
					
					if (d is String) {
						v = String(d as! String)
					} else if (d is Bool) {
						v = "\(d as! Bool)"
					} else if (d is Int) {
						v = String(d as! Int)
					} else if (d is Double) {
						v = String(d as! Double)
					} else if (d is Dictionary<String,Any>) {
						c = d
					}
				}
			})
		}
		
		return v
	}
	
	private func prop(_ props: JcProperties, for key: String) -> Any? {
	
		let dict = props.allProperties()
		
		return dict[String(key)]
	}
	
	/*
	func lookupValuex(device: JcProperties, provider: C8yNetworkProvider?, instance: C8yNetworkProviderInstance?) -> String? {
			
		var v: String? = nil
		
		if let key = self.source == nil ? self.name : !self.source!.contains(".") ? self.source : self.source!.starts(with: "device.") ? self.source?.lastToken(".") : nil {
						
			if (key == "name") {
				v = device.name
			} else if (key == "model") {
				v =  device.model
			} else if (key == "supplier") {
				v =  device.supplier
			} else if (key == "serialNumber") {
				v =  device .serialNumber
			} else {
				v = (device.wrappedManagedObject.properties[key] as? C8yStringCustomAsset)?.value
				
				if (v == nil) {
					// try in managed object itself
					
					v = device.wrappedManagedObject.allProperties()[key] as? String
				}
			}
		} else if (self.source! == "user.id") {
			v = "TODO"
		} else if (self.source!.startsWith("id.")) {
			v =  device.externalIds[self.source!.lastToken(".")]?.externalId
		} else if (self.source!.startsWith("position.") || self.source!.startsWith("pos.")) {
			v =  (device.wrappedManagedObject.properties[self.source!.lastToken(".")] as? C8yStringCustomAsset)?.value
		} else if (self.source!.starts(with: "network.type")) {
			v =  device.network.type
		} else if (self.source!.starts(with: "network.provider")) {
			v =  device.network.provider
		} else if (self.source!.starts(with: "network.instance")) {
			v =  device.network.instance
		} else if (self.source!.starts(with: "network.lan.ip")) {
			v =  device.network.lan?.ip
		}  else if (self.source!.starts(with: "network.lan.name")) {
			v =  device.network.lan?.name
		}  else if (self.source!.starts(with: "network.lan.enabled")) {
			v =  "\(device.network.lan?.enabled ?? true)"
		} else if (self.source!.starts(with: "network.wan.ip")) {
			v =  device.network.wan?.ip
		} else if (self.source!.starts(with: "network.")) {
			v = device.network.properties[self.source!.lastToken(".")]
			
			if (v == nil && instance != nil) {
				v = (instance!.properties[self.source!.lastToken(".")] as? C8yStringCustomAsset)?.value
			}
			
			if (v == nil && provider != nil) {
				v = (provider!.properties[self.source!.lastToken(".")] as? C8yStringCustomAsset)?.value
			}
		}
		
		if (v == nil) {
			v = value
		}
		
		return v
	}*/
}
