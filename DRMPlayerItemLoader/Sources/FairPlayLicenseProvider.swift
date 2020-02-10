//
//  FairPlayLicenseProvider.swift
//  DRMPlayerItemLoader
//
//  Created by peter on 2020/2/10.
//  Copyright © 2020 SWAG. All rights reserved.
//

import Foundation

@objc public protocol FairPlayLicenseProvider {
    @objc func getLicense(spc: Data, assetId: String, url: URL, headers: [String:String],
                          callback: @escaping (_ ckc: Data?, _ offlineDuration: TimeInterval, _ error: Error?) -> Void)
    @objc func requestApplicationCertificate() -> Data
    @objc func buildLicenseURL(identifier: String) -> String
}

