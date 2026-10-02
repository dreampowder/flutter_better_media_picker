import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../model/model_media_picker_strings.dart';
import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';

/// Album list. Pushed by [ScreenMediaPicker] after library access is granted,
/// so it does not request permission itself.
class ScreenAlbumPicker extends StatefulWidget {
  final AssetPathEntity? selectedAlbum;
  final MediaThumbnailCache? thumbnailCache;
  final MediaPickerStrings? localizedStrings;
  final RequestType requestType;
  final void Function(Object error)? onReceiveError;

  const ScreenAlbumPicker({
    super.key,
    required this.selectedAlbum,
    required this.thumbnailCache,
    this.localizedStrings,
    this.requestType = RequestType.common,
    this.onReceiveError,
  });

  @override
  ScreenAlbumPickerState createState() => ScreenAlbumPickerState();
}

class ScreenAlbumPickerState extends State<ScreenAlbumPicker> {
  late final MediaThumbnailCache _thumbnailCache = widget.thumbnailCache ?? MediaThumbnailCache();
  late final Future<List<AssetPathEntity>> _albums = _loadAlbums();

  /// Album ids share the cache with asset ids; on Android both are numeric.
  static String _cacheKey(AssetPathEntity path) => "album:${path.id}";

  Future<List<AssetPathEntity>> _loadAlbums() async {
    try {
      final paths = await PhotoManager.getAssetPathList(hasAll: true, type: widget.requestType);
      final albums = <AssetPathEntity>[];
      for (final path in paths) {
        if (path.isAll || await path.assetCountAsync > 0) {
          albums.add(path);
        }
      }
      final allIndex = albums.indexWhere((e) => e.isAll);
      if (allIndex > 0) {
        albums.insert(0, albums.removeAt(allIndex));
      }
      for (final album in albums) {
        unawaited(_loadThumbnail(album));
      }
      return albums;
    } catch (error) {
      MediaPickerUtils.debugPrint("Error loading albums: $error");
      widget.onReceiveError?.call(error);
      rethrow;
    }
  }

  Future<void> _loadThumbnail(AssetPathEntity path) async {
    final key = _cacheKey(path);
    if (_thumbnailCache.hasKey(key)) return;
    Uint8List? data;
    try {
      final assets = await path.getAssetListRange(start: 0, end: 1);
      if (assets.isNotEmpty) {
        data = await assets.first.thumbnailData;
      }
    } catch (error) {
      MediaPickerUtils.debugPrint("Error getting album thumbnail: $error");
    }
    _thumbnailCache.setCache(key, data);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.localizedStrings?.albums ?? "Albums"),
      ),
      body: FutureBuilder<List<AssetPathEntity>>(
        future: _albums,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(widget.localizedStrings?.alertTitleError ?? "Couldn't load albums"),
            );
          }
          final albums = snapshot.data!;
          return ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final path = albums[index];
              return ListTile(
                leading: _thumbnail(path),
                title: Text(path.name),
                trailing: path.id != widget.selectedAlbum?.id
                    ? null
                    : Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary),
                onTap: () => Navigator.of(context).pop(path),
              );
            },
          );
        },
      ),
    );
  }

  Widget _thumbnail(AssetPathEntity path) {
    final data = _thumbnailCache.getData(_cacheKey(path));
    if (data == null || data.isEmpty) {
      return const SizedBox(width: 40, height: 40, child: Icon(Icons.photo));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(data, width: 40, height: 40, fit: BoxFit.cover),
    );
  }
}
