# DRMPlayerItemLoader

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
