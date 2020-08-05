//
//  ManageObjectQuery.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

public struct C8yManagedObjectQuery {

    /**
     * Represents the operator to be applied to the value of the query i.e. equals, not equals etc.
     */
    public enum Operator: String {
        case eq
        case ne
        case lt
        case gt
        case le
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
     
        let key: String
        let op: Operator?
        let value: String
        
        public init(key: String, op: Operator?, value: String) {
        
            self.key = key
            self.op = op
            self.value = value
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
    
    /**
     * Adds a new query to the existing set
     */
    public mutating func add(_ query: Query) -> C8yManagedObjectQuery {
        queries.append(query)
        
        return self
    }

    /**
     * Adds a new query to the existing set based on the individual values
     * @param key left hand operator
     * @param operator the operator to be applied e.g. 'eq' 'ne' etc. or blank if key is a function
     * @param value right hand operator or value of function is operator is null
     */
    public mutating func add(key: String, op: Operator?, value: String) {

        queries.append(Query(key: key, op: op, value: value))
    }

    public func build() -> String {

        var b: String = ""
        
        for (q) in self.queries {
            
            if (b.isEmpty) {
                b.append(q.toString())
            } else {
                b.append(" and ")
                b.append(q.toString())
            }
        }
        
        return b.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
    }
}
