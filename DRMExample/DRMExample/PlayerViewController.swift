//
//  PlayerViewController.swift
//  MacPlayer
//
//  Created by Noam Tamim on 21/06/2019.
//  Copyright © 2019 Noam Tamim. All rights reserved.
//
import UIKit
import AVKit
import DRMPlayerItemLoader

fileprivate let errorTag = "Error"
fileprivate let errorLogTag = "ErrorLog"
fileprivate let accessLogTag = "AccessLog"

class PlayerViewController: UIViewController {

    @objc lazy var playerLayer: AVPlayerLayer = {
          let layer = AVPlayerLayer()
          layer.videoGravity = .resizeAspect
          return layer
      }()
        
    @objc let player = AVPlayer()
    
    var drmHelper: PlayerItemLoader?
    let contentURL = "https://cdnapisec.kaltura.com/p/2222401/sp/2222401/playManifest/entryId/1_i18rihuv/flavorIds/1_nwoofqvr,1_3z75wwxi,1_exjt5le8,1_uvb3fyqs/deliveryProfileId/8642/protocol/https/format/applehttp/a.m3u8"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        player.allowsExternalPlayback = false
        playerLayer.frame = view.bounds
        playerLayer.player = player
        
        view.layer.addSublayer(playerLayer)
        print("[START]: \(Date())")

        ContentKeyManager.shared.licenseProvider = FairPlayServer.sharedInstance
    
        drmHelper = PlayerItemLoader(url: contentURL, contentKey: "skd://entry-1_i18rihuv")
//        drmHelper = PlayerItemLoader(url: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")
        drmHelper?.load(with: self)

        player.addObserver(self, forKeyPath: "timeControlStatus", options: [.old, .new], context: nil)
        player.addObserver(self, forKeyPath: "rate", options: [.old, .new], context: nil)


    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playerLayer.player?.pause()
        playerLayer.player?.replaceCurrentItem(with: nil)
        playerLayer.player = nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if object as AnyObject? === player {
            if keyPath == "timeControlStatus", player.timeControlStatus == .playing {
                print("[PLAYING]: \(Date())")
            }
            if keyPath == "rate" {
                if player.rate > 0 {
                    print("video started")
                }
            }
        }
    }
}


extension PlayerViewController: PlayerItemUpdateDelegate {
    func didAssetIsReady(with loader: PlayerItemLoader) {
        guard let item = loader.playerItem else { return }
        player.replaceCurrentItem(with: item)
        print("[didAssetIsReady]: \(Date())")
    }
    
    func didStatusChange(_ playerItem: AVPlayerItem, status: AVPlayerItem.Status) {
        print("> status: \(status.rawValue)")
        switch status {
        case .readyToPlay:
        // Player item is ready to play.
            player.play()
            print("[PLAY]: \(Date())")
            break
        case .failed:
        // Player item failed. See error.
            if let error = playerItem.error {
                print("[PlayerItem Error]:\(AVFoundationErrorDomainExplain(error: error).description)")
            }
        case .unknown:
            // Player item is not yet ready.
            print("Item state changed to unknown")
        @unknown default:
            fatalError()
        }

    }
    func didErrorLogEntry(_ playerItem: AVPlayerItem, errorLog: AVPlayerItemErrorLogEvent) {
        print(">> last error log:\(String(describing: errorLog.errorComment)) (Code: \(errorLog.errorStatusCode) @ \(errorLog.errorDomain)")

    }
    
    func didAccessLogEntry(_ playerItem: AVPlayerItem, accessLog: AVPlayerItemAccessLogEvent) {
        print(">> averageAudioBitrate:\(accessLog.averageAudioBitrate)")
        print(">> averageVideoBitrate:\(accessLog.averageVideoBitrate)")
        print(">> indicatedAverageBitrate:\(accessLog.indicatedAverageBitrate)")
        print(">> indicatedBitrate:\(accessLog.indicatedBitrate)")
        print(">> observedBitrate:\(accessLog.observedBitrate)")
        print(">> observedMaxBitrate:\(accessLog.observedMaxBitrate)")
        print(">> observedMinBitrate:\(accessLog.observedMinBitrate)")
        print(">> switchBitrate:\(accessLog.switchBitrate)")
        print(">> durationWatched:\(accessLog.durationWatched)")

    }
    
    func didDownloadProgress(_ progress: CGFloat) {
//        print("progress: \(progress)")
    }
}
