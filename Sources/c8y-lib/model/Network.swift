//
//  Network.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 11/12/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct C8yNetwork: JcEncodableContent, JcProperties, Equatable {
	
	public internal(set) var type: String = C8Y_NETWORK_NONE
	public internal(set) var provider: String? // e.g. objenious
	public internal(set) var instance: String? // connection id
	public internal(set) var provisioned: Bool = false
	public internal(set) var connectionError: Bool = false
	public internal(set) var networkRef: String? = nil
	
	public var properties: [String:String] = [:]
	
	public var lan: LAN?
	public var wan: WAN?
	public var dhcp: DHCP?
	
	enum CodingKeys : String, CodingKey {
		case type = "type"
		case provider = "provider"
		case instance = "instance"
		case provisioned = "provisioned"
		case connectionError = "connectionError"
		case networkRef = "networkRef"
		case lan = "c8y_LAN"
		case wan = "c8y_WAN"
		case dhcp = "c8y_DHCP"
		case properties = "properties"
	}
	
	public init(type: String? = nil, provider: String? = nil, instance: String? = nil, provisioned: Bool? = false) {
		
		if (type != nil) {
			self.type = type!
		}
		
		self.provider = provider
		self.instance = instance
		self.provisioned = provisioned ?? false
	}
	
	public init(from decoder: Decoder) throws {
			
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		if (container.contains(.type)) {
			self.type = try container.decode(String.self, forKey: .type)
		}
		
		if (container.contains(.provider)) {
			self.provider = try container.decode(String.self, forKey: .provider)
		}
		
		if (container.contains(.instance)) {
			self.instance = try container.decode(String.self, forKey: .instance)
		}
		
		if (container.contains(.provisioned)) {
			self.provisioned = try container.decode(Bool.self, forKey: .provisioned)
		}
		
		if (container.contains(.connectionError)) {
			self.connectionError = try container.decode(Bool.self, forKey: .connectionError)
		}
		
		if (container.contains(.lan)) {
			self.lan = try container.decode(LAN.self, forKey: .lan)
		}
		
		if (container.contains(.wan)) {
			self.wan = try container.decode(WAN.self, forKey: .wan)
		}
		
		if (container.contains(.dhcp)) {
			self.dhcp = try container.decode(DHCP.self, forKey: .dhcp)
		}
		
		if (container.contains(.properties)) {
			self.properties = try container.decode([String:String].self, forKey: .properties)
		}
	}
	
	public static func == (lhs: C8yNetwork, rhs: C8yNetwork) -> Bool {
		
		return lhs.type != rhs.type || lhs.wan != rhs.wan || lhs.dhcp != rhs.dhcp || lhs.provider != rhs.provider || lhs.instance != rhs.instance
	}

	public struct WAN: JcEncodableContent, JcProperties, Equatable {
		
		public var ip: String? = nil
		public var username: String? = nil
		public var password: String? = nil
		public var simStatus: Bool? = nil
		public var authType: String? = nil
		public var apn: String? = nil
	
		enum CodingKeys: CodingKey {
			case ip
			case username
			case password
			case simStatus
			case authType
			case apn
		}
		
		public static func == (lhs: WAN, rhs: WAN) -> Bool {
			
			return lhs.ip != rhs.ip || lhs.username != rhs.username || lhs.password != rhs.password || lhs.simStatus != rhs.simStatus || lhs.authType != rhs.authType || lhs.apn != rhs.apn
		}
		
		public init(ip: String) {
			self.ip = ip
		}
		
		public init(username: String?, password: String?) {
			
			self.username = username
			self.password = password
		}
		
		public init(from decoder: Decoder) throws {
			
			let container: KeyedDecodingContainer = try decoder.container(keyedBy: CodingKeys.self)
			
			if container.contains(.ip) {
				self.ip = try container.decode(String.self, forKey: .ip)
			}
			
			if (container.contains(.username)) {
				self.username = try container.decode(String.self, forKey: .username)
			}
			
			if (container.contains(.password)) {
				self.password = try container.decode(String.self, forKey: .password)
			}
			
			if (container.contains(.simStatus)) {
				self.simStatus = try container.decode(Bool.self, forKey: .simStatus)
			}
			
			if (container.contains(.authType)) {
				self.authType = try container.decode(String.self, forKey: .authType)
			}
			
			if (container.contains(.apn)) {
				self.apn = try container.decode(String.self, forKey: .apn)
			}
		}
	}

	public struct LAN: JcEncodableContent, JcProperties, Equatable {
		
		public var ip: String
		public var name: String?
		public var mac: String?
		public var enabled: Bool?

		public static func == (lhs: LAN, rhs: LAN) -> Bool {
		
			return lhs.ip != rhs.ip || lhs.name != rhs.name || lhs.enabled != rhs.enabled || lhs.mac != rhs.mac
		}
	}

	public struct DHCP: JcEncodableContent, JcProperties, Equatable {
		
		public var addressRange: AddressRange
		public var enabled: Bool
	
		public static func == (lhs: DHCP, rhs: DHCP) -> Bool {
	
			return lhs.addressRange != rhs.addressRange || lhs.enabled != rhs.enabled
		}
	}
	
	public struct AddressRange: JcEncodableContent, Equatable {
		
		public var start: String
		public var end: String
	
		public static func == (lhs: AddressRange, rhs: AddressRange) -> Bool {

			return lhs.start != rhs.start || lhs.end != rhs.end
		}
	}
}

