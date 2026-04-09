/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The `FairPlayContentKeyManager` class configures the instance of `AVContentKeySession` to use for requesting content keys
 securely for playback or offline use.
 */

import AVFoundation

class FairPlayContentKeyManager: ContentKeyManaging {
  let contentKeySession: AVContentKeySession

  /**
   The instance of `ContentKeyDelegate` which conforms to `AVContentKeySessionDelegate` and is used to respond to content key requests from
   the `AVContentKeySession`
   */
  private let contentKeyDelegate: FairPlayContentKeyDelegate

  /// The DispatchQueue to use for delegate callbacks.
  private let contentKeyDelegateQueue: DispatchQueue

  // MARK: Initialization.

  init(licenseProvider: FairPlayLicenseProvider?) {
    contentKeySession = AVContentKeySession(keySystem: .fairPlayStreaming)
    contentKeyDelegate = FairPlayContentKeyDelegate()
    contentKeyDelegate.contentKeySession = contentKeySession
    contentKeyDelegate.licenseProvider = licenseProvider
    contentKeyDelegateQueue = DispatchQueue(label: "com.swag.contentKeyDelegateQueue-\(UUID().uuidString)")
    contentKeySession.setDelegate(contentKeyDelegate, queue: contentKeyDelegateQueue)
  }
  
  func renewContentKey() {
    contentKeyDelegate.renewLicense()
  }
}
