//
//  KeyID.swift
//  DRMPlayerItemLoader
//
//  Created by 立宣于 on 2023/1/12.
//

import AVFoundation
import Foundation
import Logging

class DRMKeyID {
    static let tag = "DRM Key"
    var id: String {
        stringValue
    }
    
    var debugForm: Logger.Metadata {
        [
            "id": "\(id)",
            "data": "\(data.count) bytes"
        ]
    }

    let stringValue: String
    let data: Data

    init(stringValue: String, data: Data) {
        self.stringValue = stringValue
        self.data = data
    }

    class func from(keyRequest: AVContentKeyRequest) -> DRMKeyID? {
        guard let key = keyRequest.identifier as? String else {
            logger.warning(
                "Init failed",
                metadata: [
                    "tag": "\(tag)",
                    "request": "\(keyRequest)",
                ]
            )
            return nil
        }
        return from(key: key)
    }
    
    class func from(keyRequest: AVPersistableContentKeyRequest) -> DRMKeyID? {
        guard let key = keyRequest.identifier as? String else {
            logger.warning(
                "Init failed",
                metadata: [
                    "tag": "\(tag)",
                    "request": "\(keyRequest)",
                ]
            )
            return nil
        }
        return from(key: key)
    }

    class func from(key: String) -> DRMKeyID? {
        guard key.hasPrefix("skd://") else {
            logger.warning(
                "Init failed",
                metadata: [
                    "tag": "\(tag)",
                    "reason": "Missing skd://",
                    "key": "\(key)",
                ]
            )
            return nil
        }
        let idString = String(key.dropFirst("skd://".count))
        guard let idData = idString.data(using: .utf8) else {
            logger.warning(
                "Init failed",
                metadata: [
                    "tag": "\(tag)",
                    "reason": "Cannot get data",
                    "id": "\(idString)",
                ]
            )            
            return nil
        }
        return DRMKeyID(stringValue: idString, data: idData)
    }
}
