/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 `ContentKeyDelegate` is a class that implements the `AVContentKeySessionDelegate` protocol to respond to content key
 requests using FairPlay Streaming.
 */

import AVFoundation
import Logging

@objcMembers
@objc public class ContentKeyDelegate: NSObject, AVContentKeySessionDelegate {
    static let tag = "DRM Key Delegate"
    static let logMeta: Logger.Metadata = ["tag": "\(tag)"]
    weak var licenseProvider: FairPlayLicenseProvider?
    weak var contentKeySession: AVContentKeySession?

    // MARK: Types

    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
    }

    // MARK: Properties

    /// `previousRequest` is the previous license request, and stored it in order to renew next license.
    private var previousRequest: AVContentKeyRequest?

    /// The directory that is used to save persistable content keys.
    lazy var contentKeyDirectory: URL = {
        guard let docDir = NSSearchPathForDirectoriesInDomains(
            .documentDirectory, .userDomainMask, true
        ).first else {
            fatalError("Unable to determine library URL")
        }

        let keyDir = URL(fileURLWithPath: docDir)
            .appendingPathComponent(".keys", isDirectory: true)
        if FileManager.default.fileExists(atPath: keyDir.path, isDirectory: nil) {
            return keyDir
        }
        do {
            try FileManager.default.createDirectory(
                at: keyDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return keyDir
        } catch {
            fatalError("Unable to create directory for content keys at path: \(keyDir.path)")
        }

    }()

    /// A set containing the currently pending content key identifiers associated with persistable content key requests that have not been completed.
    var pendingPersistableContentKeyIdentifiers = Set<String>()

    /// A dictionary mapping content key identifiers to their associated stream name.
    var contentKeyToStreamNameMap = [String: String]()

    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String, callback: @escaping (Data?, Error?) -> Void) {
        guard let licenseProvider = licenseProvider else {
            logger.warning(
                "Missing license provider",
                metadata: ContentKeyDelegate.logMeta
            )
            assertionFailure("Missing license provider")
            return
        }
        licenseProvider.getLicense(
            spc: spcData,
            assetId: assetID,
            headers: [:],
            callback: callback
        )
    }

    /// Preloads all the content keys associated with an Asset for persisting on disk.
    ///
    /// It is recommended you use AVContentKeySession to initiate the key loading process
    /// for online keys too. Key loading time can be a significant portion of your playback
    /// startup time because applications normally load keys when they receive an on-demand
    /// key request. You can improve the playback startup experience for your users if you
    /// load keys even before the user has picked something to play. AVContentKeySession allows
    /// you to initiate a key loading process and then use the key request you get to load the
    /// keys independent of the playback session. This is called key preloading. After loading
    /// the keys you can request playback, so during playback you don't have to load any keys,
    /// and the playback decryption can start immediately.
    ///
    /// In this sample use the Streams.plist to specify your own content key identifiers to use
    /// for loading content keys for your media. See the README document for more information.
    ///
    /// - Parameter asset: The `Asset` to preload keys for.
    func requestPersistableContentKeys(for contentKey: String) {
        logger.debug("Request persistable keys", metadata: ContentKeyDelegate.logMeta)
        guard let drmKey = DRMKeyID.from(key: contentKey) else {
            return
        }
        pendingPersistableContentKeyIdentifiers.insert(drmKey.id)
        contentKeyToStreamNameMap[drmKey.id] = contentKey
        contentKeySession?.processContentKeyRequest(
            withIdentifier: contentKey,
            initializationData: nil,
            options: nil
        )
    }

    /// Returns whether or not a content key should be persistable on disk.
    ///
    /// - Parameter identifier: The asset ID associated with the content key request.
    /// - Returns: `true` if the content key request should be persistable, `false` otherwise.
    func shouldRequestPersistableContentKey(withIdentifier identifier: String) -> Bool {
        return pendingPersistableContentKeyIdentifiers.contains(identifier)
    }

    // MARK: AVContentKeySessionDelegate Methods

    /*
     The following delegate callback gets called when the client initiates a key request or AVFoundation
     determines that the content is encrypted based on the playlist the client provided when it requests playback.
     */
    public func contentKeySession(
        _ session: AVContentKeySession,
        didProvide keyRequest: AVContentKeyRequest
    ) {
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }

    /*
     Provides the receiver with a new content key request representing a renewal of an existing content key.
     Will be invoked by an AVContentKeySession as the result of a call to -renewExpiringResponseDataForContentKeyRequest:.
     */
    public func contentKeySession(
        _ session: AVContentKeySession,
        didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest
    ) {
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }

    /*
     Provides the receiver a content key request that should be retried because a previous content key request failed.
     Will be invoked by an AVContentKeySession when a content key request should be retried. The reason for failure of
     previous content key request is specified. The receiver can decide if it wants to request AVContentKeySession to
     retry this key request based on the reason. If the receiver returns YES, AVContentKeySession would restart the
     key request process. If the receiver returns NO or if it does not implement this delegate method, the content key
     request would fail and AVContentKeySession would let the receiver know through
     -contentKeySession:contentKeyRequest:didFailWithError:.
     */
    public func contentKeySession(
        _ session: AVContentKeySession,
        shouldRetry keyRequest: AVContentKeyRequest,
        reason retryReason: AVContentKeyRequest.RetryReason
    ) -> Bool {
        var shouldRetry = false

        switch retryReason {
        /*
         Indicates that the content key request should be retried because the key response was not set soon enough either
         due the initial request/response was taking too long, or a lease was expiring in the meantime.
         */
        case AVContentKeyRequest.RetryReason.timedOut:
            shouldRetry = true

        /*
         Indicates that the content key request should be retried because a key response with expired lease was set on the
         previous content key request.
         */
        case AVContentKeyRequest.RetryReason.receivedResponseWithExpiredLease:
            shouldRetry = true

        /*
         Indicates that the content key request should be retried because an obsolete key response was set on the previous
         content key request.
         */
        case AVContentKeyRequest.RetryReason.receivedObsoleteContentKey:
            shouldRetry = true

        default:
            break
        }

        return shouldRetry
    }

    // Informs the receiver a content key request has failed.
    public func contentKeySession(
        _ session: AVContentKeySession,
        contentKeyRequest keyRequest: AVContentKeyRequest,
        didFailWithError err: Error
    ) {
        logger.warning(
            "Key request failed",
            metadata: [
                "tag": "\(ContentKeyDelegate.tag)",
                "request": "\(keyRequest)",
                "error": "\(AVFoundationErrorDomainExplain.description(for: err as NSError))",
            ]
        )
    }

    // MARK: API

    private func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        logger.debug(
            "Handle key request",
            metadata: ContentKeyDelegate.logMeta
        )
        guard let drmKey = DRMKeyID.from(keyRequest: keyRequest) else {
            return
        }
        let isKeyExistsOnDisk = persistableContentKeyExistsOnDisk(withContentKeyIdentifier: drmKey.id)
        let shouldRequestKey = shouldRequestPersistableContentKey(withIdentifier: drmKey.id)
        var meta: Logger.Metadata = [
            "tag": "\(ContentKeyDelegate.tag)",
            "key": .dictionary(drmKey.debugForm),
            "isKeyExistsOnDisk": "\(isKeyExistsOnDisk)",
            "shouldRequestKey": "\(shouldRequestKey)",
        ]

        if shouldRequestKey || isKeyExistsOnDisk {
            logger.debug("Request persistable key", metadata: meta)
            // Request a Persistable Key Request.
            do {
                if #available(iOS 11.2, *) {
                    try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
                } else {
                    keyRequest.respondByRequestingPersistableContentKeyRequest()
                }
            } catch {
                meta["error"] = "\(error)"
                logger.debug("Request persistable key failed", metadata: meta)
                /*
                 This case will occur when the client gets a key loading request from an AirPlay Session.
                 You should answer the key request using an online key from your key server.
                 */
                provideOnlinekey(from: keyRequest, with: drmKey)
            }

            return
        }
        logger.debug("Skip request persistable key", metadata: meta)
        provideOnlinekey(from: keyRequest, with: drmKey)
    }

    private func provideOnlinekey(
        from keyRequest: AVContentKeyRequest,
        with key: DRMKeyID
    ) {
        var logMeta = ContentKeyDelegate.logMeta
        logMeta["key"] = .dictionary(key.debugForm)
        logger.debug("Will provide online key", metadata: logMeta)
        guard let licenseProvider = licenseProvider else {
            logger.warning(
                "Cannot provide online key",
                metadata: ["reason": "Missing license provider"]
            )
            assertionFailure("Missing license provider")
            return
        }

        let applicationCertificate = licenseProvider.requestApplicationCertificate()
        let startDate = Date()
        logger.debug("Key request start", metadata: logMeta)
        keyRequest.makeStreamingContentKeyRequestData(
            forApp: applicationCertificate,
            contentIdentifier: key.data,
            options: [AVContentKeyRequestProtocolVersionsKey: [1]],
            completionHandler: { [weak self] data, error in
                logMeta["duration"] = "\(Date().timeIntervalSince(startDate))"
                guard let spcData = data else {
                    logMeta["reason"] = "no spc data"
                    if let error = error {
                        logMeta["error"] = "\(error)"
                    }
                    logger.warning("Key request failed", metadata: logMeta)
                    return
                }
                logger.debug("Key request succeeded", metadata: logMeta)
                self?.previousRequest = keyRequest
                self?.requestContentKeyFromKeySecurityModule(
                    spcData: spcData,
                    assetID: key.id
                ) { data, error in
                    guard let ckcData = data else {
                        if let error = error {
                            logMeta["error"] = "\(error)"
                        }
                        logger.warning("Cannot get ckc data", metadata: logMeta)
                        return
                    }
                    keyRequest.processContentKeyResponse(
                        AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                    )
                }
            }
        )
    }

    func renewLicense() {
        guard let request = previousRequest,
              request.status != .cancelled,
              request.status != .failed else { return }
        logger.debug("Will renew license", metadata: ContentKeyDelegate.logMeta)
        contentKeySession?.renewExpiringResponseData(for: request)
    }
}
