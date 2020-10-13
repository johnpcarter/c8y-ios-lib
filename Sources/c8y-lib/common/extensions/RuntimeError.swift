//
//  RuntimeError.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 04/05/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

struct RuntimeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    public var localizedDescription: String {
        return message
    }
}
