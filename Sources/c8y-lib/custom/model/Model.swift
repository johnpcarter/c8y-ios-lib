//
//  Model.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 02/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation
import Combine

import UIKit


public struct C8yModel: Hashable {
    
	public private(set) var name: String = ""
	public private(set) var description: String? = nil

	internal var _operationTemplateDelegate: C8yOperationTemplateDelegate? = nil
	
	public var id: String {
		return self.info.id
	}
	
	public var category: C8yDevice.Category {
		return self.info.category ?? .Unknown
	}
	
	public var link: String? {
		return self.info.link
	}
	
	public var preferredMetric: String? {
		
		if (self.info.preferredMetric != nil) {
			if (self.info.preferredSeries != nil) {
				return "\(self.info.preferredMetric!).\(self.info.preferredSeries!)"
			} else {
				return self.info.preferredMetric
			}
		} else {
			return nil
		}
	}
	
	public var businessDataFields: [String]? {
		return self.info.businessDataFields
	}
	
	public var businessDataEvents: [C8yModelInfo.BusinessEvent]? {
		return self.info.businessDataEvents
	}
	
	public var businessDataFragment: String? {
		return self.info.businessDataFragment
	}
	
	public var agent: String? {
		return self.info.agent
	}
		
	public var image: UIImage? {
		return self.info.image()
	}
	
	public var operationTemplates: [C8yOperation.OperationTemplate]? {
		return self.info.operations
	}
	
	private var info: C8yModelInfo
    
	init() {
		self.info = C8yModelInfo()
	}
	
	public init(_ opTemplate: C8yOperationTemplateDelegate? = nil) {
		self.info = C8yModelInfo()
		self._operationTemplateDelegate = opTemplate
	}
	
	init(_ object: C8yManagedObject) {
	
		self.name = object.name!
		self.description = object.notes
		
		self.info = object.properties["model"] as! C8yModelInfo
	}
	
	public init(_ id: String, name: String, category: C8yDevice.Category, link: String?, description: String? = nil, image: UIImage? = nil, businessDataFragment: String? = nil, businessDataFields: [String]? = nil, businessDataEvents: [C8yModelInfo.BusinessEvent]? = nil, datapoints: [C8yModelInfo.DataPoint]? = nil) {
        
        self.name = name
		self.description = description
		
		self.info = C8yModelInfo(id, category: category, link: link, base64Image: image?.pngData()?.base64EncodedString(), businessDataFragment: businessDataFragment, businessDataFields: businessDataFields, businessDataEvents: businessDataEvents, datapoints: datapoints)
    }
    
	public func dataPointTemplate(for key: String) -> C8yModelInfo.DataPoint? {
	
		var dp: C8yModelInfo.DataPoint? = nil
		
		// look up model from c8y model references
		
		for o in self.info.datapoints {
			if (o.fragment == key) {
				dp = o
				break
			}
			
		}
		
		return dp
	}
	
	public func operationTemplate(for type: String) -> C8yOperation.OperationTemplate {
	
		var op: C8yOperation.OperationTemplate? = nil
		
		// look up model from c8y model references
		
		if (self.operationTemplates != nil) {
			for o in self.operationTemplates! {
				if (o.type == type) {
					op = o
					break
				}
			}
		}
		
		if (op == nil && self._operationTemplateDelegate != nil) {
			// still nil , check if delete has it instead
			
			op = self._operationTemplateDelegate!.template(for: type)
		}
		
		return op ?? C8yOperation.OperationTemplate()
	}
	
    public static func == (lhs: C8yModel, rhs: C8yModel) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
           
        hasher.combine(self.id.hashValue)
    }
}

class C8yModelInfoAssetDecoder: C8yCustomAssetFactory {
   
	static func register() {
		C8yCustomAssetProcessor.registerCustomPropertyClass(property: "model", decoder: C8yModelInfoAssetDecoder())
	}
	
	override func make(key: C8yCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey>) throws -> C8yCustomAsset {
	   return try container.decode(C8yModelInfo.self, forKey: key)
	}
}

public struct C8yModelInfo: C8yCustomAsset {
   
	public private(set) var id: String
	public private(set) var agent: String?
	public private(set) var category: C8yDevice.Category?
	public private(set) var link: String?
	public private(set) var preferredMetric: String?
	public private(set) var preferredSeries: String?
	
	public private(set) var imageBase64: String?
	public private(set) var manufacturer: String?
	
	public private(set) var datapoints: [DataPoint] = []
	public private(set) var operations: [C8yOperation.OperationTemplate] = []

	public var businessDataFragment: String = "c8y_BusinessData"
	public var businessDataFields: [String]? = nil
	public var businessDataEvents: [BusinessEvent]? = nil
	
	public struct DataPoint: Codable {
		
		public var fragment: String
		public var series: String
		public var label: String
		public var unit: String?
		
		public var color: String? = nil // rgb e.g. #ffffff
		public var lineType: String? = nil
		public var renderType: String? = nil
		
		public private(set) var min: Double?
		public private(set) var max: Double?
		
		public private(set) var upper: Double?
		public private(set) var lower: Double?
		public private(set) var middle: Double?
		
		public private(set) var aggregationType: String?
		public private(set) var valueAsPercentage: Bool?
		
		public init(_ key: String, series: String, label: String, unit: String? = nil, showAsPercentage: Bool = false, min: Double? = nil, max: Double? = nil, lower: Double? = nil, upper: Double? = nil, middle: Double? = nil) {
			
			self.fragment = key
			self.series = series
			self.label = label
			self.unit = unit
			self.valueAsPercentage = showAsPercentage
			
			self.min = min
			self.max = max
			self.lower = lower
			self.upper = upper
			self.middle = middle
		}
	}
	
	public struct BusinessEvent: Codable {
		
		public private(set) var type: String
		public private(set) var label: String
		public private(set) var destructive: Bool = false
		public private(set) var values: C8yCustomAsset? = nil
		
		enum CodingKeys: CodingKey {
			case type
			case label
			case destructive
			case values
		}
		
		public init(_ name: String, label: String, values: [String:String]? = nil, destructive: Bool = false) {
			self.type = name
			self.label = label
			self.destructive = destructive
			
			if (values != nil) {
			
				self.values = C8yDictionaryCustomAsset(values!)
			}
		}
		
		public init(from decoder: Decoder) throws {
			
			let container = try decoder.container(keyedBy: CodingKeys.self)
			
			self.type = try container.decode(String.self, forKey: .type)
			self.label = try container.decode(String.self, forKey: .label)
			self.destructive = try container.decodeIfPresent(Bool.self, forKey: .destructive) ?? false
			
			if (container.contains(.values)) {
				do { self.values = C8yStringCustomAsset(try container.decode(String.self, forKey: .values))
				} catch {
					do { self.values = C8yDoubleCustomAsset(try container.decode(Double.self, forKey: .values))
					} catch {
						do { self.values = C8yBoolCustomAsset(try container.decode(Bool.self, forKey: .values))
						} catch {
							// h'mm it's not a simple type, maybe it's a complex structure so we need to try and flatten it

							let nestedContainer: KeyedDecodingContainer<C8yCustomAssetProcessor.AssetObjectKey> = try container.nestedContainer(keyedBy: C8yCustomAssetProcessor.AssetObjectKey.self, forKey: .values)
								
							do { self.values = try C8yDictionaryCustomAsset(nestedContainer, forKey: C8yCustomAssetProcessor.AssetObjectKey(stringValue: "values")!)
							} catch {
								// ignore
							}
						}
					}
				}
			}

		}
		
		public func encode(to encoder: Encoder) throws {
			fatalError("Not implemented")
		}
	}
	
	enum CodingKeys: CodingKey {
		case id
		case category
		case agent
		case link
		case preferredMetric
		case preferredSeries
		case imageBase64
		case manufacturer
		case operations
		case datapoints
		case businessDataFields
		case businessDataEvents
		case businessDataFragment
	}
	
	public init(from decoder: Decoder) throws {
		
		let container = try decoder.container(keyedBy: CodingKeys.self)
		
		self.id = try container.decode(String.self, forKey: .id)
		self.category = C8yDevice.Category(rawValue: try container.decode(String.self, forKey: .category))

		if (container.contains(.agent)) {
			self.agent = try container.decode(String.self, forKey: .agent)
		}
		
		if (container.contains(.link)) {
			self.link = try container.decode(String.self, forKey: .link)
		}
		
		if (container.contains(.imageBase64)) {
			self.imageBase64 = try container.decode(String.self, forKey: .imageBase64)
		}
		
		if (container.contains(.manufacturer)) {
			self.manufacturer = try container.decode(String.self, forKey: .manufacturer)
		}
		
		if (container.contains(.preferredMetric)) {
			self.preferredMetric = try container.decode(String.self, forKey: .preferredMetric)
		}
		
		if (container.contains(.preferredSeries)) {
			self.preferredSeries = try container.decode(String.self, forKey: .preferredSeries)
		}
		
		if (container.contains(.datapoints)) {
			self.datapoints = try container.decode([DataPoint].self, forKey: .datapoints)
		}
		
		if (container.contains(.operations)) {
			self.operations = try container.decode([C8yOperation.OperationTemplate].self, forKey: .operations)
		}
		
		if (container.contains(.businessDataFields)) {
			self.businessDataFields = try container.decode([String].self, forKey: .businessDataFields)
		}
		
		if (container.contains(.businessDataEvents)) {
			self.businessDataEvents = try container.decode([BusinessEvent].self, forKey: .businessDataEvents)
		}
		
		if (container.contains(.businessDataFragment)) {
			self.businessDataFragment = try container.decode(String.self, forKey: .businessDataFragment)
		}
	}
	
	init(_ id: String, category: C8yDevice.Category, link: String?, base64Image: String?, businessDataFragment: String? = nil, businessDataFields: [String]? = nil, businessDataEvents: [BusinessEvent]? = nil, datapoints: [C8yModelInfo.DataPoint]? = nil) {
		
		self.id = id
		self.category = category
		self.link = link
		self.imageBase64 = base64Image
		
		if (businessDataFragment != nil) {
			self.businessDataFragment = businessDataFragment!
		}
		
		if (businessDataFields != nil) {
			self.businessDataFields = businessDataFields!
		}

		if (datapoints != nil) {
			self.datapoints = datapoints!
		}
		
		self.businessDataEvents = businessDataEvents
	}
	
	init() {
		self.id = ""
		self.category = .Unknown
	}
	
	public func image() -> UIImage? {
		if ( self.imageBase64 != nil) {
			return Data(base64Encoded: self.imageBase64!)?.uiImage
		} else {
			return nil
		}
	}
}

extension Data {
	var uiImage: UIImage? { UIImage(data: self) }
}
