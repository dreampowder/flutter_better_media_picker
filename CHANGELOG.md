## 0.1.0

### Breaking
* `permissionHandler` is now `Future<bool> Function()?` and replaces the built-in permission request (it was previously ignored).
* `onDownloadMediaStateChanged` / `onReceiveError` are typed `void Function(MediaDownloadState, Object?)` / `void Function(Object)`.
* A failed iCloud download reports `MediaDownloadState.error` only and keeps the picker open; it no longer reports `complete` and returns the undownloaded assets.
* Converted from a placeholder plugin to a plain package; requires Dart 3.4 / Flutter 3.22.

### Fixed
* The newest page of every album was skipped (photo_manager pages start at 0).
* Android permission was requested for images only, regardless of `assetType`.
* iOS limited access was treated as denied.
* Library change notifications never refreshed the grid; the change callback leaked after closing.
* Double taps could pop the picker twice.
* Page and album loading errors left an endless spinner; `onReceiveError` now receives them.
* Video durations over an hour rendered as `1:5:03`.
* Thumbnail cache is bounded (LRU) instead of growing for the whole session.
* Album thumbnails could collide with asset thumbnails on Android.
* Native photo_manager logging was left enabled.

### Added
* `pageSize` and `localizedStrings` on `MediaPicker.pickAssets`.
* `MediaDownloadState` and `MediaPickerStrings` exported from `media_picker.dart`.
