/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A simple class that holds information about an Asset.
 */
import AVFoundation
import Logging

@objcMembers
@objc public class AssetItem: NSObject {
    /// The AVURLAsset corresponding to this Asset.
    public private(set) var asset: AVURLAsset
    /// The `NSKeyValueObservation` for the KVO on \AVURLAsset.isPlayable.
    private var urlAssetObserver: NSKeyValueObservation?
    private let playableHandler: ((AVURLAsset) -> ())?
    private let initDate = Date()

    init(urlAsset: AVURLAsset, playableHandler: ((AVURLAsset) -> ())?) {
        self.asset = urlAsset
        self.playableHandler = playableHandler
        super.init()
        urlAssetObserver = urlAsset.observe(\AVURLAsset.isPlayable, options: [.new, .initial]) { [weak self] (asset, _) in
            DispatchQueue.main.async {
                self?.onAssetIsPlayableChange(asset: asset)
            }
        }
    }
    
    private func onAssetIsPlayableChange(asset: AVURLAsset) {
        let meta: Logger.Metadata = [
            "url": "\(asset.url)",
            "tag": "DRMAssetItem",
            "timeSinceStart": "\(Date().timeIntervalSince(initDate))"
        ]
        guard asset.isPlayable else {
            logger.debug("Asset become unplayable", metadata: meta)
            return
        }
        logger.debug("Asset become playable", metadata: meta)
        self.asset = asset
        playableHandler?(asset)
    }
    
    deinit {
        urlAssetObserver?.invalidate()
    }
    
}
