//
//  DRMHelper.swift
//  SWAG
//
//  Created by peter on 2020/1/30.
//  Copyright © 2020 Machipopo Corp. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation

@objc public protocol PlayerItemUpdateDelegate: NSObjectProtocol {
    @objc func didStatusChange(_ playerItem: AVPlayerItem, status: AVPlayerItem.Status)
    @objc func didAssetIsReady(with loader: PlayerItemLoader)
    @objc optional func didErrorLogEntry(_ playerItem: AVPlayerItem, errorLog: AVPlayerItemErrorLogEvent)
    @objc optional func didAccessLogEntry(_ playerItem: AVPlayerItem, accessLog: AVPlayerItemAccessLogEvent)
    @objc optional func didPlayToEndTime(_ playerItem: AVPlayerItem)
    @objc optional func didDownloadProgress(_ progress: CGFloat)
    @objc optional func playerItemWillRenewLicense(_ playerItem: AVPlayerItem)
    @objc var licenseProvider: FairPlayLicenseProvider? { get }
}

@objcMembers
@objc public class PlayerItemLoader: NSObject {
    private let urlString: String
    private let assetOptions: [String : Any]?
    private let contentKey: String?
    public let identifier: String?

    public private(set) var assetItem: AssetItem?
    public private(set) var playerItem: AVPlayerItem?

    private weak var delegate: PlayerItemUpdateDelegate?
        
    /// A Bool tracking if the AVPlayerItem.status has changed to .readyToPlay for the current AssetPlaybackManager.playerItem.
    private var readyForPlayback = false

    /// The `NSKeyValueObservation` for the KVO on \AVPlayerItem.status.
    private var playerItemObserver: NSKeyValueObservation?

    private var loadedObserver: NSKeyValueObservation?
    private var contentKeyManager: ContentKeyManager?

    private var renewTimer: Timer?
    public init(
        identifier: String?,
        url: String,
        assetOptions: [String : Any]? = nil,
        contentKey: String? = nil,
        renewInterval: TimeInterval = 540
    ) {
        self.identifier = identifier
        urlString = url
        self.assetOptions = assetOptions
        self.contentKey = contentKey

        super.init()
        setupRenewTimer(interval: 15)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        loadedObserver?.invalidate()
        playerItemObserver?.invalidate()
        renewTimer?.invalidate()
        print("[PlayerItemLoader deinit]")
    }
    
    public func load(with delegate: PlayerItemUpdateDelegate) {
        guard let url = URL(string: urlString) else { return }
        self.delegate = delegate
        contentKeyManager = ContentKeyManager(licenseProvider: delegate.licenseProvider)
        loadAsset(url: url)
    }
    
    private func loadAsset(url: URL) {
        readyForPlayback = false
        let asset = AVURLAsset(url: url, options: assetOptions)
        
        contentKeyManager?.contentKeySession.addContentKeyRecipient(asset)
        if let contentKey = contentKey {
            contentKeyManager?.contentKeyDelegate.requestPersistableContentKeys(for: contentKey)
        }

        let assetItem = AssetItem(urlAsset: asset, playableHandler: { [weak self] (asset) in
            self?.didAssetPlayable(asset)
        })
        self.assetItem = assetItem
    }
    
    private func didAssetPlayable(_ asset: AVURLAsset) {
        let item = AVPlayerItem(asset: asset)
        playerItem = item
        delegate?.didAssetIsReady(with: self)
        addObservers(for: item)
    }
    
    private func addObservers(for playerItem: AVPlayerItem) {
        playerItemObserver?.invalidate()
        loadedObserver?.invalidate()
        readyForPlayback = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.onErrorLogEntryNotification), name: .AVPlayerItemNewErrorLogEntry, object: playerItem)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onAccessLogEntryNotification), name: .AVPlayerItemNewAccessLogEntry, object: playerItem)
        NotificationCenter.default.addObserver(self, selector:#selector(self.didPlayToEndTime), name: .AVPlayerItemDidPlayToEndTime, object: playerItem)

        playerItemObserver = playerItem.observe(\AVPlayerItem.status, options: [.new, .initial]) { [weak self] (item, _) in
            self?.delegate?.didStatusChange(item, status: item.status)
        }
        
        loadedObserver = playerItem.observe(\AVPlayerItem.loadedTimeRanges, options: [.new]) { [weak self] (item, _) in
            self?.calcLoadedProgress(item)
        }
    }
    
    private func calcLoadedProgress(_ item: AVPlayerItem) {
        let duration = item.duration.seconds
        var loadedTimeRangeSeconds: Double = 0
        if let startSeconds = item.loadedTimeRanges.first?.timeRangeValue.start.seconds,
            let durationSeconds = item.loadedTimeRanges.first?.timeRangeValue.duration.seconds {
            loadedTimeRangeSeconds = durationSeconds + startSeconds
        }
        let progress: CGFloat = duration > 0 ? (CGFloat(loadedTimeRangeSeconds / duration)) : 0

        delegate?.didDownloadProgress?(progress)
    }
    
    private func setupRenewTimer(interval: TimeInterval) {
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(renewTimerFired(timer:)), userInfo: nil, repeats: true)
        renewTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    @objc func renewTimerFired(timer: Timer) {
        guard let item = playerItem else { return }
        delegate?.playerItemWillRenewLicense?(item)
        //TODO: renew drm Licence
    }

    @objc func onErrorLogEntryNotification(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,let lastEvent = item.lastErrorLog else { return }
        delegate?.didErrorLogEntry?(item, errorLog: lastEvent)
    }

    @objc func onAccessLogEntryNotification(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem,let lastEvent = item.lastAccessLog else { return }
        delegate?.didAccessLogEntry?(item, accessLog: lastEvent)
    }
    
    @objc func didPlayToEndTime(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }
        delegate?.didPlayToEndTime?(item)
    }
    
    public var loadedTimeRangeSeconds: CGFloat {
        guard let playerItem = playerItem,
            playerItem.loadedTimeRanges.count > 0,
            let timeRange = playerItem.loadedTimeRanges.first as? CMTimeRange
            else {
            return 0
        }
        
        return CGFloat( CMTimeGetSeconds(timeRange.duration) + CMTimeGetSeconds(timeRange.start) )
    }
    
    public var currentTimeSeconds: CGFloat {
        guard let playerItem = playerItem else {
            return 0
        }
        return CGFloat( CMTimeGetSeconds(playerItem.currentTime()) )
    }
    
    public var duration: CGFloat {
        guard let playerItem = playerItem else {
            return 0
        }
        return CGFloat( CMTimeGetSeconds(playerItem.duration) )
    }
    
    public var playProgress: CGFloat {
        guard duration > 0 else {
            return 0
        }
       return currentTimeSeconds / duration
    }

}
