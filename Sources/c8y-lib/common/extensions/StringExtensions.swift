//
//  StringExtensions.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 09/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public extension String {
	
	var isNumber: Bool {
		return Double(self) != nil
	}
	
	func spacify() -> String {

		return self.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression, range: nil)
	}
	
	func index(of input: String, options: String.CompareOptions = .literal) -> Int {
		
		let i = self.range(of: input, options: options)
		
		if (i != nil) {
			return self.distance(from: self.startIndex, to: i!.lowerBound)
		} else {
			return -1
		}
	}
	
	func convertIndexToInt(_ i: String.Index?) -> Int {
	
		if (i != nil) {
			return self.distance(from: self.startIndex, to: i!)
		} else {
			return -1
		}
	}
	
	func lastIndex(of input: String) -> Int {
		return index(of: input, options: .backwards)
	}
	
    func startsWith(_ string: String) -> Bool {
        
        return lowercased().hasPrefix(string.lowercased())
    }
    
    func endsWith(_ string: String) -> Bool {
        
        return lowercased().hasSuffix(string.lowercased())
    }
    
    func trim() -> String
    {
        return self.trimmingCharacters(in: .whitespaces)
    }
    
    func keyeOfKeyValuePair(_ separator: String) -> String {
        
         let parts = self.split(separator: String.Element(separator))
        
        if (parts.count > 1) {
            return String(parts[0]).trim()
        } else {
            return self.trim()
        }
    }
	
	func lastToken(_ separator: String) -> String {
	
		let parts = self.split(separator: String.Element(separator))
		
		if (parts.count > 1) {
			return String(parts[parts.count-1]).trim()
		} else {
			return self.trim()
		}
	}
	
    func valueOfKeyValuePair(_ separator: String) -> String {
        
         let parts = self.split(separator: String.Element(separator))
        
        if (parts.count > 1) {
            return String(parts[1]).trim()
        } else {
            return self.trim()
        }
    }
    
    func subString(from: Int) -> String {
        
        return String(self[String.Index(utf16Offset: from, in: self)...])
    }
    
    func subString(to: Int) -> String {
           
        return String(self[..<String.Index(utf16Offset: to, in: self)])
    }
    
    func subString(from: Int, to: Int) -> String {
              
        return String(self[String.Index(utf16Offset: from, in: self)..<String.Index(utf16Offset: to, in: self)])
    }
    
    func rightJustified(width: Int, truncate: Bool = false) -> String {
        guard width > count else {
            return truncate ? String(suffix(width)) : self
        }
        return String(repeating: " ", count: width - count) + self
    }

    func leftJustified(width: Int, truncate: Bool = false) -> String {
        guard width > count else {
            return truncate ? String(prefix(width)) : self
        }
        return self + String(repeating: " ", count: width - count)
    }
    
    static func make(array: [String]) -> String? {
        
        var out: String? = nil
        
        for v in array {
            
            if (out == nil) {
                out = v
            } else {
                out! += "," + v
            }
        }
        
        return out
    }
	
	
}
