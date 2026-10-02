import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';

class WidgetAssetImage extends StatefulWidget {
  final AssetEntity asset;
  final Size size;
  final VoidCallback? onTap;
  final MediaThumbnailCache thumbnailCache;

  const WidgetAssetImage({
    super.key,
    required this.asset,
    required this.size,
    required this.thumbnailCache,
    this.onTap,
  });

  @override
  WidgetAssetImageState createState() => WidgetAssetImageState();
}

class WidgetAssetImageState extends State<WidgetAssetImage> {
  /// Created once per asset so rebuilds (e.g. selection changes) don't refetch.
  Future<Uint8List?>? _thumbnail;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _thumbnail ??= _loadThumbnail();
  }

  @override
  void didUpdateWidget(WidgetAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id || oldWidget.size != widget.size) {
      _thumbnail = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    final asset = widget.asset;
    final cached = widget.thumbnailCache.getData(asset.id);
    if (cached != null) return cached;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final data = await asset.thumbnailDataWithSize(
      ThumbnailSize(
        (widget.size.width * pixelRatio).toInt(),
        (widget.size.height * pixelRatio).toInt(),
      ),
      quality: 80,
    );
    if (data != null) {
      widget.thumbnailCache.setCache(asset.id, data);
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: FutureBuilder<Uint8List?>(
        future: _thumbnail,
        initialData: widget.thumbnailCache.getData(widget.asset.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            MediaPickerUtils.debugPrint("Thumbnail error: ${snapshot.error}");
          }
          final data = snapshot.data;
          return AnimatedOpacity(
            opacity: data == null ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: data == null ? const SizedBox.expand() : _content(data),
          );
        },
      ),
    );
  }

  Widget _content(Uint8List data) {
    return Stack(
      children: [
        Positioned.fill(child: Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true)),
        Positioned(bottom: 2, left: 4, right: 4, child: _bottomInfo()),
      ],
    );
  }

  Widget _bottomInfo() {
    final asset = widget.asset;
    if (asset.type != AssetType.video || asset.duration <= 0) {
      return const SizedBox.shrink();
    }
    return Text(
      MediaPickerUtils.formatDuration(asset.duration),
      style: const TextStyle(color: Colors.white),
      textAlign: TextAlign.end,
    );
  }
}
