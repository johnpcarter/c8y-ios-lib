//
//  Properties.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 14/12/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public protocol JcProperties {
	func allProperties(limit: Int) -> [String: Any]
}

extension JcProperties {
	
	public func allProperties(limit: Int = Int.max) -> [String: Any] {
		return props(obj: self, count: 0, limit: limit)		
	}
	
	private func props(obj: Any, count: Int, limit: Int) -> [String: Any] {
		
		let mirror = Mirror(reflecting: obj)
		var result: [String: Any] = [:]
		for (prop, val) in mirror.children {
			guard let prop = prop else { continue }
			if prop == "some" {
				return props(obj: val, count: count, limit: limit)
			} else if limit == count || val is String || val is Bool || val is Double || val is Date {
				result[prop] = val
			} else {
				let subResult = props(obj: val, count: count + 1, limit: limit)
				result[prop] = subResult.count == 0 ? val : subResult
			}
		}
		
		return result
	}
}
