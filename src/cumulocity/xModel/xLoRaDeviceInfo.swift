//
//  LoRaDeviceInfo.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

//
//  LoRaNetworkInfo.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 17/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

let CY_LORA_DEVICE = "cylora-device"

let CY_LORA_DEVICE_APP_KEY = "appKey"
let CY_LORA_DEVICE_APP_EUI = "appEUI"

let CY_LORA_DEVICE_CODEC = "lora_codec_DeviceCodecRepresentation"
let CY_LORA_DEVICE_CODEC_NAME = "name"
let CY_LORA_DEVICE_CODEC_ID = "id"

class JcLoRaDeviceInfoAssetDecoder: JcCustomAssetDecoder<JcLoRaDeviceInfo> {
    
    static func register() {
        JcCustomAssetProcessor.registerCustomPropertyClass(property: CY_LORA_DEVICE, decoder: JcLoRaDeviceInfoAssetDecoder())
    }
    
    override func make(key: JcCustomAssetProcessor.AssetObjectKey, container: KeyedDecodingContainer<JcCustomAssetProcessor.AssetObjectKey>) throws -> JcLoRaDeviceInfo {
       try container.decode(JcLoRaDeviceInfo.self, forKey: key)
    }
}

class JcLoRaDeviceInfo: JcCustomAsset {
    
    let appKey: String
    let appEUI: String
    
    let codecName: String
    let codecId: String
    
    required init(from decoder: Decoder) throws {
    }
    
    override func encode(to encoder: Encoder) throws {
    }
}
    
