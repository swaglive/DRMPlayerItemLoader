/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This extension on `ContentKeyDelegate` implements the `AVContentKeySessionDelegate` protocol methods related to persistable content keys.
 */

import AVFoundation
import Logging

extension ContentKeyDelegate {
    
    /*
     Provides the receiver with a new content key request that allows key persistence.
     Will be invoked by an AVContentKeyRequest as the result of a call to
     -respondByRequestingPersistableContentKeyRequest.
     */
    public func contentKeySession(_ session: AVContentKeySession, didProvide keyRequest: AVPersistableContentKeyRequest) {
        handlePersistableContentKeyRequest(keyRequest: keyRequest)
    }
    
    /*
     Provides the receiver with an updated persistable content key for a particular key request.
     If the content key session provides an updated persistable content key data, the previous
     key data is no longer valid and cannot be used to answer future loading requests.
     
     This scenario can occur when using the FPS "dual expiry" feature which allows you to define
     and customize two expiry windows for FPS persistent keys. The first window is the storage
     expiry window which starts as soon as the persistent key is created. The other window is a
     playback expiry window which starts when the persistent key is used to start the playback
     of the media content.
     
     Here's an example:
     
     When the user rents a movie to play offline you would create a persistent key with a CKC that
     opts in to use this feature. This persistent key is said to expire at the end of storage expiry
     window which is 30 days in this example. You would store this persistent key in your apps storage
     and use it to answer a key request later on. When the user comes back within these 30 days and
     asks you to start playback of the content, you will get a key request and would use this persistent
     key to answer the key request. At that point, you will get sent an updated persistent key which
     is set to expire at the end of playback experiment which is 24 hours in this example.
     public */
    public func contentKeySession(
        _ session: AVContentKeySession,
        didUpdatePersistableContentKey persistableContentKey: Data,
        forContentKeyIdentifier keyIdentifier: Any
    ) {
        var logMeta: Logger.Metadata = [
            "tag": "\(ContentKeyDelegate.tag)"
        ]
        logger.debug("Will update persistable key", metadata: logMeta)
        /*
         The key ID is the URI from the EXT-X-KEY tag in the playlist (e.g. "skd://key65") and the
         asset ID in this case is "key65".
         */
        guard
            let keyString = keyIdentifier as? String,
            let drmKey = DRMKeyID.from(key: keyString)
            else {
                return
        }
        logMeta["key"] = .dictionary(drmKey.debugForm)
        do {
            logger.debug("Will write persistable key", metadata: logMeta)
            deletePeristableContentKey(withContentKeyIdentifier: drmKey.id)
            try writePersistableContentKey(
                contentKey: persistableContentKey,
                withContentKeyIdentifier: drmKey.id
            )
        } catch {
            logMeta["error"] = "\(error)"
            logger.warning("Fail update persistable key", metadata: logMeta)
        }
    }
    
    // MARK: API.
    
    /// Handles responding to an `AVPersistableContentKeyRequest` by determining if a key is already available for use on disk.
    /// If no key is available on disk, a persistable key is requested from the server and securely written to disk for use in the future.
    /// In both cases, the resulting content key is used as a response for the `AVPersistableContentKeyRequest`.
    ///
    /// - Parameter keyRequest: The `AVPersistableContentKeyRequest` to respond to.
    
    
    func handlePersistableContentKeyRequest(
        keyRequest: AVPersistableContentKeyRequest
    ) {
        var logMeta = ContentKeyDelegate.logMeta
        logMeta["request"] = "\(keyRequest)"
        logger.debug("Will handle persistable key", metadata: logMeta)
        guard let drmKey = DRMKeyID.from(keyRequest: keyRequest) else {
            return
        }
        if persistableContentKeyExistsOnDisk(withContentKeyIdentifier: drmKey.id) {
            let urlToPersistableKey = urlForPersistableContentKey(withContentKeyIdentifier: drmKey.id)
            guard let contentKey = FileManager.default.contents(atPath: urlToPersistableKey.path) else {
                // Error Handling.
                pendingPersistableContentKeyIdentifiers.remove(drmKey.id)
                /*
                 Key requests should never be left dangling.
                 Attempt to create a new persistable key.
                 */
                makeContentKeyRequest(keyRequest: keyRequest, drmKey: drmKey)
                return
            }
            
            /*
             Create an AVContentKeyResponse from the persistent key data to use for requesting a key for
             decrypting content.
             */
            let keyResponse = AVContentKeyResponse(fairPlayStreamingKeyResponseData: contentKey)
            // Provide the content key response to make protected content available for processing.
            keyRequest.processContentKeyResponse(keyResponse)
            logger.debug("Persistable key handled", metadata: logMeta)
            return
        }
        makeContentKeyRequest(keyRequest: keyRequest, drmKey: drmKey)
    }
        
    private func makeContentKeyRequest(
        keyRequest: AVPersistableContentKeyRequest,
        drmKey: DRMKeyID
    ) {
        var logMeta: Logger.Metadata = [
            "tag": "\(ContentKeyDelegate.tag)",
            "key": .dictionary(drmKey.debugForm)
        ]
        logger.debug("Will make key request", metadata: logMeta)
        guard let licenseProvider = licenseProvider else {
            logger.warning("Missing license provider", metadata: logMeta)
            return
        }
        let applicationCertificate = licenseProvider.requestApplicationCertificate()
        keyRequest.makeStreamingContentKeyRequestData(
            forApp: applicationCertificate,
            contentIdentifier: drmKey.data,
            options: [AVContentKeyRequestProtocolVersionsKey: [1]],
            completionHandler: {[weak self](data, error) in
                if let error = error {
                    keyRequest.processContentKeyResponseError(error)
                    self?.pendingPersistableContentKeyIdentifiers.remove(drmKey.id)
                    return
                }
                guard let spcData = data else {
                    logger.warning("Missing spc data", metadata: logMeta)
                    return
                }
                self?.handlePersistableContentKey(
                    keyRequest: keyRequest,
                    spcData: spcData,
                    assetID: drmKey.id
                )
        })
        
    }
    
    func handlePersistableContentKey(
        keyRequest: AVPersistableContentKeyRequest,
        spcData: Data,
        assetID: String
    ) {
        requestContentKeyFromKeySecurityModule(
            spcData: spcData,
            assetID: assetID
        ) { [weak self] (data, error) in
            var logMeta = ContentKeyDelegate.logMeta
            guard let ckcData = data else {
                if let error = error {
                    logMeta["error"] = "\(error)"
                }
                logger.warning("Missing ckc data", metadata: logMeta)
                return
            }
            self?.persistableContentKey(keyRequest: keyRequest, ckcData: ckcData, assetID: assetID)
        }
    }
    
    func persistableContentKey(
        keyRequest: AVPersistableContentKeyRequest,
        ckcData: Data,
        assetID: String
    ) {
        do {
            let persistentKey = try keyRequest.persistableContentKey(fromKeyVendorResponse: ckcData, options: nil)
            try writePersistableContentKey(
                contentKey: persistentKey,
                withContentKeyIdentifier: assetID
            )
            keyRequest.processContentKeyResponse(
                AVContentKeyResponse(fairPlayStreamingKeyResponseData: persistentKey)
            )

            let assetName = contentKeyToStreamNameMap.removeValue(forKey: assetID)!
            if !contentKeyToStreamNameMap.values.contains(assetName) {
                NotificationCenter.default.post(
                    name: .DidSaveAllPersistableContentKey,
                    object: nil,
                    userInfo: ["name": assetName]
                )
            }
            pendingPersistableContentKeyIdentifiers.remove(assetID)
        } catch {
            keyRequest.processContentKeyResponseError(error)
            pendingPersistableContentKeyIdentifiers.remove(assetID)
        }
    }
    func deleteAllPeristableContentKeys() {
        var logMeta: Logger.Metadata = [
            "tag": "\(ContentKeyDelegate.tag)"
        ]
        do {
            logger.debug("Will retrieve keys to delete", metadata: logMeta)
            let contents = try FileManager.default.contentsOfDirectory(
                at: contentKeyDirectory,
                includingPropertiesForKeys: nil,
                options: []
            )
            logMeta["count"] = "\(contents.count)"
            logger.debug("Will delete keys", metadata: logMeta)
            try contents.forEach{
                logMeta["keyFile"] = "\($0)"
                try FileManager.default.removeItem(at: $0)
            }
        } catch {
            logMeta["error"] = "\(error)"
            logger.warning("Delete keys failed", metadata: logMeta)
        }

    }
    
    /// Deletes a persistable key for a given content key identifier.
    ///
    /// - Parameter contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    func deletePeristableContentKey(withContentKeyIdentifier contentKeyIdentifier: String) {
        var logMeta = ContentKeyDelegate.logMeta
        logMeta["keyId"] = "\(contentKeyIdentifier)"
        logger.debug("Will delete persistable key", metadata: logMeta)
        guard persistableContentKeyExistsOnDisk(withContentKeyIdentifier: contentKeyIdentifier) else { return }
        let contentKeyURL = urlForPersistableContentKey(withContentKeyIdentifier: contentKeyIdentifier)
        do {
            try FileManager.default.removeItem(at: contentKeyURL)
            UserDefaults.standard.removeObject(forKey: "\(contentKeyIdentifier)-Key")
        } catch {
            logMeta["error"] = "\(error)"
            logger.warning("Cannot delete persistable key", metadata: logMeta)
        }
    }
    
    /// Returns whether or not a persistable content key exists on disk for a given content key identifier.
    ///
    /// - Parameter contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Returns: `true` if the key exists on disk, `false` otherwise.
    func persistableContentKeyExistsOnDisk(withContentKeyIdentifier contentKeyIdentifier: String) -> Bool {
        return FileManager.default.fileExists(
            atPath: urlForPersistableContentKey(withContentKeyIdentifier: contentKeyIdentifier).path
        )
    }
    
    // MARK: Private APIs
    
    /// Returns the `URL` for persisting or retrieving a persistable content key.
    ///
    /// - Parameter contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Returns: The fully resolved file URL.
    func urlForPersistableContentKey(withContentKeyIdentifier contentKeyIdentifier: String) -> URL {
        return contentKeyDirectory.appendingPathComponent("\(contentKeyIdentifier)-Key")
    }
    
    /// Writes out a persistable content key to disk.
    ///
    /// - Parameters:
    ///   - contentKey: The data representation of the persistable content key.
    ///   - contentKeyIdentifier: The host value of an `AVPersistableContentKeyRequest`. (i.e. "tweleve" in "skd://tweleve").
    /// - Throws: If an error occurs during the file write process.
    func writePersistableContentKey(
        contentKey: Data,
        withContentKeyIdentifier contentKeyIdentifier: String
    ) throws {
        try contentKey.write(
            to: urlForPersistableContentKey(withContentKeyIdentifier: contentKeyIdentifier),
            options: Data.WritingOptions.atomicWrite
        )
    }
    
}

extension Notification.Name {
    
    /**
     The notification that is posted when all the content keys for a given asset have been saved to disk.
     */
    static let DidSaveAllPersistableContentKey = Notification.Name("ContentKeyDelegateDidSaveAllPersistableContentKey")
}
