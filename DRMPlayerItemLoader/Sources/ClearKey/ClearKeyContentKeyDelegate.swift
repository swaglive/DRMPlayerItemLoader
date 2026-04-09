//
//  ClearKeyContentKeyDelegate.swift
//  DRMPlayerItemLoader
//
//  Created by 立宣于 on 2026/4/8.
//

import AVFoundation
import Logging

final class ClearKeyContentKeyDelegate: NSObject, Sendable, AVContentKeySessionDelegate {
  let contentKeyProvider: ClearKeyContentKeyProviding
  static let tag = "AESKeyDelegate"
  static let logMeta: Logger.Metadata = ["tag": "\(tag)"]

  init(contentKeyProvider: ClearKeyContentKeyProviding) {
    self.contentKeyProvider = contentKeyProvider
  }

  func contentKeySession(
    _ session: AVContentKeySession,
    didProvide keyRequest: AVContentKeyRequest,
  ) {
    var meta = ClearKeyContentKeyDelegate.logMeta
    guard
      let kid = keyRequest.identifier
    else {
      logger.warning("Cannot request Key, missing KID", metadata: meta)
      return
    }
    guard
      let urlString = kid as? String,
      let keyURL = URL(string: urlString)
    else {
      meta["kid"] = "\(kid)"
      logger.warning("Cannot request Key, unexpected KID", metadata: meta)
      return
    }
    Task { [weak self] in
      await self?.loadContentKey(from: keyURL, for: keyRequest)
    }
  }
  
  private func loadContentKey(from url: URL, for keyRequest: AVContentKeyRequest) async {
    do {
      let (key, iv) = try await contentKeyProvider.loadContentKey(from: url)
      keyRequest.processContentKeyResponse(
        .init(clearKeyData: key, initializationVector: iv)
      )
    } catch {
      keyRequest.processContentKeyResponseError(error)
      var meta = ClearKeyContentKeyDelegate.logMeta
      meta["error"] = "\(error)"
      logger.warning("Cannot fetch content key", metadata: meta)
    }
  }
}
