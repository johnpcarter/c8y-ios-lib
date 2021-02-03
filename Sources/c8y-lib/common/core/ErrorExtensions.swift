//
//  ErrorExtensions.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/01/2021.
//  Copyright © 2021 John Carter. All rights reserved.
//

import Foundation

extension LocalizedError where Self: CustomStringConvertible {

   public var errorDescription: String? {
	  return description
   }
}
