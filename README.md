# DRMPlayerItemLoader

## Install
specify it in `Podfile`
```
pod 'DRMPlayerItemLoader', :git => 'https://github.com/swaglive/DRMPlayerItemLoader.git'
```

## Usage
1. Create FairPlayServer
```swift
    class FairPlayServer: FairPlayLicenseProvider {
    }
```

2.  Assign to `ContentKeyManager`
```swift
    let fairplayServer = FairPlayServer()
    ContentKeyManager.shared.licenseProvider = fairplayServer
```

3. confirm `PlayerItemUpdateDelegate`

4. Create `PlayerItemLoader` with URL
```swift
    let loader = PlayerItemLoader(url: contentURL)
```

  persistent CKC if needs
```swift
    let loader = PlayerItemLoader(url: contentURL, contentKey: "skd://contentKey")
```

5. Start loading with delegate
```swift
    loader.load(with: self)
```

## References
- [Using AVFoundation to Play and Persist HTTP Live Streams](https://developer.apple.com/documentation/avfoundation/media_assets_playback_and_editing/using_avfoundation_to_play_and_persist_http_live_streams)

- [Kaltura PlayKit Samples](https://github.com/kaltura/playkit-ios-samples)
