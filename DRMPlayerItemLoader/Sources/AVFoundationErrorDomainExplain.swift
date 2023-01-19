//
//  AVFoundationErrorDomainExplain.swift
//  drm
//
//  Created by peter on 2020/2/10.
//  Copyright © 2020 SWAG. All rights reserved.
//

import Foundation

public struct AVFoundationErrorDomainExplain {
    public static func description(for error: NSError) -> String {
        if let reason = error.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            return reason
        }
        guard
            let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError,
            underlyingError.domain == NSOSStatusErrorDomain
            else {
            return error.localizedDescription
        }
        switch underlyingError.code {
        case -42656:
            return "Lease duration has expired."
        case -42668:
            return "The CKC passed in for processing is not valid."
        case -42672:
            return "A certificate is not supplied when creating SPC."
        case -42673:
            return "assetId is not supplied when creating an SPC."
        case -42674:
            return "Version list is not supplied when creating an SPC."
        case -42675:
            return "The assetID supplied to SPC creation is not valid."
        case -42676:
            return "An error occurred during SPC creation."
        case -42679:
            return "The certificate supplied for SPC creation is not valid."
        case -42681:
            return "The version list supplied to SPC creation is not valid."
        case -42783:
            return "The certificate supplied for SPC is not valid and is possibly revoked."
        case -42799:
            return "The application must request a new persistent key from the server."
        case -42800:
            return "The persistent key has expired."
        default:
            return underlyingError.localizedDescription
        }
    }
}
