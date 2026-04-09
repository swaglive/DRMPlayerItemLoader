//
//  ClearKeyContentKeyManager.swift
//  DRMPlayerItemLoader
//
//  Created by 立宣于 on 2026/4/8.
//

import AVFoundation

class ClearKeyContentKeyManager: ContentKeyManaging {
  let contentKeySession: AVContentKeySession
  private let contentKeyDelegate: ClearKeyContentKeyDelegate

  init(contentKeyProvider: ClearKeyContentKeyProviding) {
    contentKeySession = AVContentKeySession(keySystem: .clearKey)
    contentKeyDelegate = ClearKeyContentKeyDelegate(contentKeyProvider: contentKeyProvider)
    contentKeySession.setDelegate(
      contentKeyDelegate,
      queue: DispatchQueue(label: "com.swag.contentKeyDelegateQueue-\(UUID().uuidString)")
    )
  }

  func renewContentKey() {}
}
