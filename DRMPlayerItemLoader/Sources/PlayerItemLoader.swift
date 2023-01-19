//
//  DRMHelper.swift
//  SWAG
//
//  Created by peter on 2020/1/30.
//  Copyright © 2020 Machipopo Corp. All rights reserved.
//

import AVFoundation
import AVKit
import Foundation
import Logging

let logger = Logger(label: Bundle.main.bundleIdentifier ?? "drmPlayer")

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
    public let assetURL: URL
    private let assetOptions: [String: Any]?
    private let contentKey: String?
    public let identifier: String?

    public private(set) var assetItem: AssetItem?
    public private(set) var playerItem: AVPlayerItem?

    private weak var delegate: PlayerItemUpdateDelegate?

    private var keyValueObservations: [NSKeyValueObservation] = []
    private var notificationRegistrations: [NSObjectProtocol] = []
    /// The `NSKeyValueObservation` for the KVO on \AVPlayerItem.status.
    private var contentKeyManager: ContentKeyManager?

    /// Ther `renewTimer` is an optional timer for renew drm license. It can be invoke by
    private var renewTimer: Timer?
    public init(
        identifier: String?,
        assetURL: URL,
        assetOptions: [String: Any]? = nil,
        contentKey: String? = nil
    ) {
        self.identifier = identifier
        self.assetURL = assetURL
        self.assetOptions = assetOptions
        self.contentKey = contentKey

        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        keyValueObservations.forEach { $0.invalidate() }
        renewTimer?.invalidate()
    }

    public func stopRenewing() {
        renewTimer?.invalidate()
        renewTimer = nil
    }

    public func load(
        with delegate: PlayerItemUpdateDelegate,
        renewInterval: TimeInterval = 0
    ) {
        self.delegate = delegate
        contentKeyManager = ContentKeyManager(licenseProvider: delegate.licenseProvider)
        loadAsset()
        scheduleRenewProcess(interval: renewInterval)
    }

    private func scheduleRenewProcess(interval: TimeInterval) {
        stopRenewing()
        guard interval > 0 else {
            return
        }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.renewLicense()
        }
        renewTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func loadAsset() {
        let asset = AVURLAsset(url: assetURL, options: assetOptions)
        contentKeyManager?.contentKeySession.addContentKeyRecipient(asset)
        if let contentKey = contentKey {
            contentKeyManager?.contentKeyDelegate.requestPersistableContentKeys(for: contentKey)
        }
        let assetItem = AssetItem(urlAsset: asset, playableHandler: { [weak self] asset in
            self?.onAssetBecomingPlayable(asset)
        })
        self.assetItem = assetItem
    }

    private func onAssetBecomingPlayable(_ asset: AVURLAsset) {
        let item = AVPlayerItem(asset: asset)
        playerItem = item
        delegate?.didAssetIsReady(with: self)
        addObservers(for: item)
    }

    private func addObservers(for playerItem: AVPlayerItem) {
        notificationRegistrations = [
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewErrorLogEntry,
                object: playerItem,
                queue: .main) { [weak self] notif in
                    self?.onErrorLogEntryNotification(notification: notif)
                },
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewErrorLogEntry,
                object: playerItem,
                queue: .main) { [weak self] notif in
                    self?.onErrorLogEntryNotification(notification: notif)
                },
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewAccessLogEntry,
                object: playerItem,
                queue: .main) { [weak self] notif in
                    self?.onAccessLogEntryNotification(notification: notif)
                },
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
                queue: .main) { [weak self] notif in
                    self?.didPlayToEndTime(notification: notif)
                },
        ]

        keyValueObservations.forEach { $0.invalidate() }
        keyValueObservations = [
            playerItem.observe(\AVPlayerItem.status, options: [.new, .initial]) { [weak self] item, _ in
                self?.delegate?.didStatusChange(item, status: item.status)
            },
            playerItem.observe(\AVPlayerItem.loadedTimeRanges, options: [.new]) { [weak self] item, _ in
                self?.calcLoadedProgress(item)
            },
        ]
    }

    private func calcLoadedProgress(_ item: AVPlayerItem) {
        let duration = item.duration.seconds
        var loadedTimeRangeSeconds: Double = 0
        if let startSeconds = item.loadedTimeRanges.first?.timeRangeValue.start.seconds,
           let durationSeconds = item.loadedTimeRanges.first?.timeRangeValue.duration.seconds {
            loadedTimeRangeSeconds = durationSeconds + startSeconds
        }
        let progress: CGFloat = duration > 0 ? CGFloat(loadedTimeRangeSeconds / duration) : 0

        delegate?.didDownloadProgress?(progress)
    }

    private func renewLicense() {
        guard let item = playerItem else { return }
        delegate?.playerItemWillRenewLicense?(item)
        contentKeyManager?.contentKeyDelegate.renewLicense()
    }

    private func onErrorLogEntryNotification(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, let lastEvent = item.lastErrorLog else { return }
        delegate?.didErrorLogEntry?(item, errorLog: lastEvent)
    }

    private func onAccessLogEntryNotification(notification: Notification) {
        guard let item = notification.object as? AVPlayerItem, let lastEvent = item.lastAccessLog else { return }
        delegate?.didAccessLogEntry?(item, accessLog: lastEvent)
    }

    private func didPlayToEndTime(notification: Notification) {
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

        return CGFloat(CMTimeGetSeconds(timeRange.duration) + CMTimeGetSeconds(timeRange.start))
    }

    public var currentTimeSeconds: CGFloat {
        guard let playerItem = playerItem else {
            return 0
        }
        return CGFloat(CMTimeGetSeconds(playerItem.currentTime()))
    }

    public var duration: CGFloat {
        guard let playerItem = playerItem else {
            return 0
        }
        return CGFloat(CMTimeGetSeconds(playerItem.duration))
    }

    public var playProgress: CGFloat {
        guard duration > 0 else {
            return 0
        }
        return currentTimeSeconds / duration
    }
}
