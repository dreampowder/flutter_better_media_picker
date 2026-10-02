import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'model/model_media_picker_strings.dart';
import 'ui/asset_picker/screen_media_picker.dart';

export 'package:photo_manager/photo_manager.dart';

export 'model/model_media_picker_strings.dart';
export 'ui/asset_picker/screen_media_picker.dart' show MediaDownloadState;

enum MediaPickerAssetType { image, video, audio, all, common }

extension _MediaPickerAssetTypeHelper on MediaPickerAssetType {
  RequestType toRequest() {
    switch (this) {
      case MediaPickerAssetType.image:
        return RequestType.image;
      case MediaPickerAssetType.video:
        return RequestType.video;
      case MediaPickerAssetType.audio:
        return RequestType.audio;
      case MediaPickerAssetType.all:
        return RequestType.all;
      case MediaPickerAssetType.common:
        return RequestType.common;
    }
  }
}

class MediaPicker {
  /// Shows the media library picker and lets users pick photos and videos.
  ///
  /// Returns the picked assets, or `null` if the picker was dismissed.
  ///
  /// - [selectedAssets]: shown as already selected when the picker opens.
  /// - [assetType]: defaults to [MediaPickerAssetType.common] (photos and videos).
  /// - [maxAssets]: maximum selectable assets; `1` picks on tap without an "Add" button.
  /// - [crossAxisCount]: number of grid columns.
  /// - [pageSize]: assets loaded per page.
  /// - [localizedStrings]: overrides the built-in English texts.
  /// - [onDownloadMediaStateChanged]: reports downloading of non-local (e.g. iCloud)
  ///   originals before returning. On [MediaDownloadState.error] the picker stays open.
  /// - [onReceiveError]: reports permission, album and page loading errors.
  /// - [permissionHandler]: replaces the built-in photo_manager permission request.
  ///   Must resolve to `true` when the library can be read.
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    List<AssetEntity>? selectedAssets,
    MediaPickerAssetType assetType = MediaPickerAssetType.common,
    int maxAssets = 1,
    int crossAxisCount = 3,
    int pageSize = 50,
    MediaPickerStrings? localizedStrings,
    void Function(MediaDownloadState state, Object? error)? onDownloadMediaStateChanged,
    void Function(Object error)? onReceiveError,
    Future<bool> Function()? permissionHandler,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<List<AssetEntity>>(
        builder: (_) => ScreenMediaPicker(
          maxAssets: maxAssets,
          crossAxisCount: crossAxisCount,
          pageSize: pageSize,
          selectedAssets: selectedAssets,
          requestType: assetType.toRequest(),
          localizedStrings: localizedStrings,
          onDownloadMediaStateChanged: onDownloadMediaStateChanged,
          onReceiveError: onReceiveError,
          permissionHandler: permissionHandler,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}
