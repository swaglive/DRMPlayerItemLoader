/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 `ContentKeyDelegate` is a class that implements the `AVContentKeySessionDelegate` protocol to respond to content key
 requests using FairPlay Streaming.
 */

import AVFoundation

@objcMembers
@objc public class ContentKeyDelegate: NSObject, AVContentKeySessionDelegate {
    weak var licenseProvider: FairPlayLicenseProvider?

    // MARK: Types
    
    enum ProgramError: Error {
        case missingApplicationCertificate
        case noCKCReturnedByKSM
    }
    
    // MARK: Properties
    
    /// The directory that is used to save persistable content keys.
    lazy var contentKeyDirectory: URL = {
        guard let documentPath =
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
                fatalError("Unable to determine library URL")
        }
        
        let documentURL = URL(fileURLWithPath: documentPath)
        
        let contentKeyDirectory = documentURL.appendingPathComponent(".keys", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: contentKeyDirectory.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: contentKeyDirectory,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
                print("content keys at path: \(contentKeyDirectory.path)")
            } catch {
                fatalError("Unable to create directory for content keys at path: \(contentKeyDirectory.path)")
            }
        }
        
        return contentKeyDirectory
    }()
    

    /// A set containing the currently pending content key identifiers associated with persistable content key requests that have not been completed.
    var pendingPersistableContentKeyIdentifiers = Set<String>()
    
    /// A dictionary mapping content key identifiers to their associated stream name.
    var contentKeyToStreamNameMap = [String: String]()
        
    func requestContentKeyFromKeySecurityModule(spcData: Data, assetID: String, callback: @escaping (Data?, Error?) -> Void) {
        guard let licenseProvider = licenseProvider else { return }
        // MARK: ADAPT - You must implement this method to request a CKC from your KSM.
        let url = licenseProvider.buildLicenseURL(identifier: assetID)
        licenseProvider.getLicense(spc: spcData, assetId: assetID, url: url, headers: [:], callback: callback)
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
        guard let contentKeyIdentifierURL = URL(string: contentKey), let assetIDString = contentKeyIdentifierURL.host else { return }
        
        pendingPersistableContentKeyIdentifiers.insert(assetIDString)
        contentKeyToStreamNameMap[assetIDString] = contentKey
        
        ContentKeyManager.shared.contentKeySession.processContentKeyRequest(withIdentifier: contentKey, initializationData: nil, options: nil)
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
    public func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVContentKeyRequest) {
        handleStreamingContentKeyRequest(keyRequest: keyRequest)
    }
    
    /*
     Provides the receiver with a new content key request representing a renewal of an existing content key.
     Will be invoked by an AVContentKeySession as the result of a call to -renewExpiringResponseDataForContentKeyRequest:.
     */
    public func contentKeySession(_ session: AVContentKeySession, didProvideRenewingContentKeyRequest keyRequest: AVContentKeyRequest) {
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
    public func contentKeySession(_ session: AVContentKeySession, shouldRetry keyRequest: AVContentKeyRequest,
                           reason retryReason: AVContentKeyRequest.RetryReason) -> Bool {
        
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
    public func contentKeySession(_ session: AVContentKeySession, contentKeyRequest keyRequest: AVContentKeyRequest, didFailWithError err: Error) {
        // Add your code here to handle errors.
        print("ERROR" + AVFoundationErrorDomainExplain(error: err).description)
    }
    
    // MARK: API
    
    private func handleStreamingContentKeyRequest(keyRequest: AVContentKeyRequest) {
        guard let contentKeyIdentifierString = keyRequest.identifier as? String,
            let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
            let assetIDString = contentKeyIdentifierURL.host
            else {
                print("Failed to retrieve the assetID from the keyRequest!")
                return
        }
        print("contentKeyIdentifierString: \(contentKeyIdentifierString)")
        print("contentKeyIdentifierURL: \(contentKeyIdentifierURL)")
        print("assetIDString: \(assetIDString)")
        
        print("shouldRequestPersistableContentKey: \(shouldRequestPersistableContentKey(withIdentifier: assetIDString))")
        print("persistableContentKeyExistsOnDisk: \(persistableContentKeyExistsOnDisk(withContentKeyIdentifier: assetIDString))")

        if shouldRequestPersistableContentKey(withIdentifier: assetIDString) ||
            persistableContentKeyExistsOnDisk(withContentKeyIdentifier: assetIDString) {
            
            // Request a Persistable Key Request.
            do {
                if #available(iOS 11.2, *) {
                    try keyRequest.respondByRequestingPersistableContentKeyRequestAndReturnError()
                } else {
                    keyRequest.respondByRequestingPersistableContentKeyRequest()
                }
            } catch {

                /*
                This case will occur when the client gets a key loading request from an AirPlay Session.
                You should answer the key request using an online key from your key server.
                */
                provideOnlinekey(from: keyRequest)
            }
            
            return
        }
        provideOnlinekey(from: keyRequest)

    }

    private func provideOnlinekey(from keyRequest: AVContentKeyRequest) {
        guard let licenseProvider = licenseProvider,
            let contentKeyIdentifierString = keyRequest.identifier as? String,
            let contentKeyIdentifierURL = URL(string: contentKeyIdentifierString),
            let assetIDString = contentKeyIdentifierURL.host,
            let assetIDData = assetIDString.data(using: .utf8)
            else {
                print("Failed to retrieve the assetID from the keyRequest!")
                return
        }

        let applicationCertificate = licenseProvider.requestApplicationCertificate()
        keyRequest.makeStreamingContentKeyRequestData(forApp: applicationCertificate,
                                                      contentIdentifier: assetIDData,
                                                      options: [AVContentKeyRequestProtocolVersionsKey: [1]],
                                                      completionHandler: {[weak self](data, error) in
                                                        
                                                        guard let spcData = data else { return }
                                                        
                                                        self?.requestContentKeyFromKeySecurityModule(spcData: spcData, assetID: assetIDString) { (data, error) in
                                                            if let ckcData = data {
                                                                let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: ckcData)
                                                                keyRequest.processContentKeyResponse(keyResponse)
                                                            }
                                                        }
        })
        
    }
}
