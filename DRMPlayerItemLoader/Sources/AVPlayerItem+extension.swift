//
//  AVPlayerItem+extension.swift
//  DRMPlayerItemLoader
//
//  Created by peter on 2020/2/10.
//  Copyright © 2020 SWAG. All rights reserved.
//

import Foundation
import AVFoundation

extension AVPlayerItem {
    var lastErrorLog: AVPlayerItemErrorLogEvent? {
        errorLog()?.events.last
    }
    var lastAccessLog: AVPlayerItemAccessLogEvent? {
        accessLog()?.events.last
    }
}
