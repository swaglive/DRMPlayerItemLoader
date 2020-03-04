# DRMPlayerItemLoader

## Install
specify it in `Podfile`
```
pod 'DRMPlayerItemLoader', :git => 'https://github.com/swaglive/DRMPlayerItemLoader.git'
```

## Usage
1. Create FairPlayServer and confirm `FairPlayLicenseProvider`
```swift
    class FairPlayServer: FairPlayLicenseProvider {
    }
```

2. confirm `PlayerItemUpdateDelegate`

3.  provide `FairPlayServer`
```swift
    licenseProvider = FairPlayServer(identifier: identifier)
    
```

4. Create `PlayerItemLoader` with URL
```swift
    let loader = PlayerItemLoader(identifier: identifier, url: contentURL, assetOptions: ["AVURLAssetHTTPHeaderFieldsKey": self.defaultHeaders])
```

  persistent CKC if needs
```swift
    let loader = PlayerItemLoader(identifier: identifier, url: contentURL, assetOptions: ["AVURLAssetHTTPHeaderFieldsKey": self.defaultHeaders], contentKey: "skd://contentKey")
```

5. Start loading with delegate
```swift
    loader.load(with: self)
```

## References
- [Using AVFoundation to Play and Persist HTTP Live Streams](https://developer.apple.com/documentation/avfoundation/media_assets_playback_and_editing/using_avfoundation_to_play_and_persist_http_live_streams)

- [Kaltura PlayKit Samples](https://github.com/kaltura/playkit-ios-samples)
