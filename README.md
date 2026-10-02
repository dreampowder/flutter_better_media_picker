# flutter_better_media_picker

A paged photo/video picker built on [photo_manager](https://pub.dev/packages/photo_manager):
album switching, single or multi-selection, and automatic download of iCloud originals before returning.

## Setup

Follow photo_manager's platform setup (Android permissions in `AndroidManifest.xml`,
`NSPhotoLibraryUsageDescription` in iOS/macOS `Info.plist`).

## Usage

```dart
import 'package:flutter_better_media_picker/media_picker.dart';

final List<AssetEntity>? assets = await MediaPicker.pickAssets(
  context,
  assetType: MediaPickerAssetType.image,
  maxAssets: 5,
);
final file = await assets?.first.file;
```

`pickAssets` returns `null` when the picker is dismissed.

| Parameter | Default | Notes |
| --- | --- | --- |
| `assetType` | `common` | `image`, `video`, `audio`, `all`, `common` (photos + videos). |
| `maxAssets` | `1` | `1` picks on tap; higher values show an "Add" button. |
| `selectedAssets` | – | Preselected assets. |
| `crossAxisCount` | `3` | Grid columns. |
| `pageSize` | `50` | Assets loaded per page. |
| `localizedStrings` | – | `MediaPickerStrings` overrides for built-in texts. |
| `onDownloadMediaStateChanged` | – | `downloading` → `complete` / `error` while iCloud originals download. On `error` the picker stays open. |
| `onReceiveError` | – | Permission, album and page loading errors. |
| `permissionHandler` | – | `Future<bool> Function()` replacing the built-in permission request, e.g. when using `permission_handler`. Return `true` when the library can be read. |

iOS limited library access is treated as granted.
