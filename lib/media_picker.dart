// You have generated a new plugin project without
// specifying the `--platforms` flag. A plugin project supports no platforms is generated.
// To add platforms, run `flutter create -t plugin --platforms <platforms> .` under the same
// directory. You can also find a detailed instruction on how to add platforms in the `pubspec.yaml` at https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'ui/asset_picker/screen_media_picker.dart';

class MediaPicker {
  ///Shows photo library / camera picker and lets usrs pick photos and videos
  ///[context] context
  ///[selectedAssets] if set, provided assets will be shows as selected at the beginning
  ///[assetType] by default, it is set to common (users can select both videos and photos)
  ///[maxAssets] determines maximum number of asset that can be selected
  ///[crossAxisCount] number of rows to be shown in asset picker
  static Future<List<AssetEntity>?> pickAssets(BuildContext context,
      {List<AssetEntity>? selectedAssets,
        RequestType assetType = RequestType.common,
        int maxAssets = 1,
        int crossAxisCount = 3}) {
    var completer = Completer<List<AssetEntity>?>();
    completer.complete(Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScreenMediaPicker(
          maxAssets: maxAssets,
          crossAxisCount: crossAxisCount,
          selectedAssets: selectedAssets,
          requestType: assetType,
        ),
        fullscreenDialog: true)));
    return completer.future;
  }
}

