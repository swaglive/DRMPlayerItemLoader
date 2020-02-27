/*
 Copyright (C) 2017 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A simple class that holds information about an Asset.
 */
import AVFoundation

@objcMembers
@objc public class AssetItem: NSObject {
    /// The AVURLAsset corresponding to this Asset.
    public private(set) var asset: AVURLAsset
    /// The `NSKeyValueObservation` for the KVO on \AVURLAsset.isPlayable.
    private var urlAssetObserver: NSKeyValueObservation?

    init(urlAsset: AVURLAsset, playableHandler: ((AVURLAsset) -> ())?) {
        self.asset = urlAsset
        super.init()
        urlAssetObserver = urlAsset.observe(\AVURLAsset.isPlayable, options: [.new, .initial]) { [weak self](asset, _) in
            self?.asset = asset
            playableHandler?(asset)
        }
    }
    
    deinit {
        urlAssetObserver?.invalidate()
        print("[AssetItem deinit]")

    }
    
}
