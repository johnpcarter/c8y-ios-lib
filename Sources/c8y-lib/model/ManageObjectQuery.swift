//
//  ManageObjectQuery.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**

Collection of queries to be used with `C8yManagedObjectsService#get(forQuery:pageNum:)`

Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/inventory/) for more information

*/
public struct C8yManagedObjectQuery {

	/**
	If true (default) all queries must match, otherwise only partial matches are allowed
	*/
	public var matchAll: Bool = true
	
    /**
	Represents the operator to be applied to the value of the query i.e. equals, not equals etc.
	
	Refer to the [c8y API documentation](https://cumulocity.com/guides/reference/inventory/) for more information
	
	*/
    public enum Operator: String {
		/**
		equal
		*/
        case eq
		/**
		not equal
		*/
        case ne
		/**
		less than (numeric only)
		*/
        case lt
		/**
		greater than (numeric only)
		*/
        case gt
		/**
		less than or equals (numeric only)
		*/
        case le
		/**
		greater than or equals (numeric only)
		*/
        case ge
    }

    /**
     * Represents an individual query to be applied, consisting of a key (left hand), an operator
     * and a value (right hand).
     * If the operator is blank, then the key is assumed to be a function e.g.
     * ```
     * val q = Query("bygroupid", null, "12345")
     * Log.i("example", "${q.toString()}")
     * ```
     *
     * would output
     *      example - bygroupd(12345)
     *
     */
    public struct Query {
     
		/**
		Identifies the c8y attribute to queried
		*/
		public let key: String
		
		/**
		identifies the type of query to be performed, e.g. equals, not equals, less than etc. etc.
		*/
		public let op: Operator?
		
		/**
		Identifies the value to be looked up, can included wildcards and also regular expressions
		Refer to cumulocity documentation for more info
		*/
		public let value: String
        
		/**
		By default (true) this condition must be included in search query, if set to false
		will be conditional in relation to other search criteria (or)
		*/
		public var exclusive: Bool = true
		
        public init(key: String, op: Operator?, value: String) {
        
            self.key = key
            self.op = op
			
			
			if (value.starts(with: "*") || value.endsWith("*")) {
				// assume they want case insensitivity too
				
				var b: String = ""
				
				value.forEach { c in
					if (c.isLetter) {
						b += "[\(String(c.uppercased()))|\(String(c.lowercased()))]"
					} else {
						b += String(c)
					}
				}
				
				self.value = b
			} else {
				self.value = value
			}
        }
		
        func toString() -> String {

            if (self.op != nil) {
                return String(format: "%@ %@ '%@'", key, op!.rawValue, value)
            } else { // if no operator, assume key is function
                return String(format: "%@(%@)", key, value)
            }
        }
    }

    private var queries: [Query] = []

	public init() {
		
	}
	
	public init(queryString: String) {
			
		let i: Int = queryString.convertIndexToInt(queryString.firstIndex(of: "="))
		
		if (i != -1) {
			
			_ = self.add(Query(key: queryString.subString(to: i), op: .eq, value: queryString.subString(from: i)))
		}
	}
    
    /**
     Adds a new query to the existing set
     */
    public mutating func add(_ query: Query) -> C8yManagedObjectQuery {
        queries.append(query)
        
        return self
    }

	/**
	Adds a new query to the existing set based on the individual values
	e.g
		.add("type", .eq "sandwich")
	or
		.add("has", nil, "c8y_IsDevice")
	
	@param key left hand operator
	@param operator the operator to be applied e.g. 'eq' 'ne' etc. or blank if key is a function
	@param value right hand operator or value of function if operator is null
	*/
    public mutating func add(key: String, op: Operator?, value: String) {

        queries.append(Query(key: key, op: op, value: value))
    }

    public func build() -> String {

		var b: String = ""
		var lastq: Query? = nil
		
        for (q) in self.queries {
            
            if (b.isEmpty) {
                b.append(q.toString())
            } else {
				if (!q.exclusive) {
					// need to add parenthesis around this and last query
					
					if (lastq != nil && lastq!.exclusive) {
						let i = b.lastIndex(of: "and")
						b = b.subString(to: i+4) + "(" + b.subString(from: i+3)
					}
					
					b.append(" or ")
				} else {
					
					if (lastq != nil && !lastq!.exclusive) {
						b.append(") ")
					}
					
					b.append(self.matchAll ? " and " : " or ")
				}
				
                b.append(q.toString())
            }
			
			lastq = q
        }
		
		if (!lastq!.exclusive && self.queries.count > 1) {
			b.append(")")
		}
		
        return b.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
}
