//
//  CustomAsset.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 18/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

class JcCustomAssetDecoder<T> {
        
    func make(key: JcCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<JcCustomAssetProcessor.AssetObjectKey>) throws -> T {
       
        let exception = NSException(
            name: NSExceptionName(rawValue: "Not implemented!"),
            reason: "A concrete subclass did not provide its own implementation of make()",
            userInfo: nil
        )
        exception.raise()
        abort() // never called
    }
}

class JcCustomAsset: Codable {
    
}
