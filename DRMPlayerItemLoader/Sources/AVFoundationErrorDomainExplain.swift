//
//  AVFoundationErrorDomainExplain.swift
//  drm
//
//  Created by peter on 2020/2/10.
//  Copyright © 2020 SWAG. All rights reserved.
//

import Foundation

public struct AVFoundationErrorDomainExplain {
    public let error: Error
    public init(error: Error) {
        self.error = error
    }
    public var description: String {
        let error = self.error as NSError
        if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            return reason
            
        }
        if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            if underlyingError.domain == NSOSStatusErrorDomain {
                var message = ""
                switch underlyingError.code {
                case -42656:
                    message = "Lease duration has expired."
                case -42668:
                    message = "The CKC passed in for processing is not valid."
                case -42672:
                    message = "A certificate is not supplied when creating SPC."
                case -42673:
                    message = "assetId is not supplied when creating an SPC."
                case -42674:
                    message = "Version list is not supplied when creating an SPC."
                case -42675:
                    message = "The assetID supplied to SPC creation is not valid."
                case -42676:
                    message = "An error occurred during SPC creation."
                case -42679:
                    message = "The certificate supplied for SPC creation is not valid."
                case -42681:
                    message = "The version list supplied to SPC creation is not valid."
                case -42783:
                    message = "The certificate supplied for SPC is not valid and is possibly revoked."
                case -42799:
                    message = "The application must request a new persistent key from the server."
                case -42800:
                    message = "The persistent key has expired."
                default:
                    message = underlyingError.localizedDescription
                }                
                return message
            }
        }
        return error.localizedDescription
    }

}
