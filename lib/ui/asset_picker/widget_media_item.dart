import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../model/model_media_picker_strings.dart';
import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';
import 'screen_album_picker.dart';
import 'widget_media_item.dart';
import 'package:photo_manager/photo_manager.dart';

class WidgetAssetImage extends StatefulWidget {
  final AssetEntity asset;
  final Size size;
  final Function? onTap;
  final MediaThumbnailCache thumbnailCache;
  const WidgetAssetImage({
    Key? key,
    required this.asset,
    required this.size,
    required this.thumbnailCache,
    this.onTap,
  }):super(key: key);

  @override
  _WidgetAssetImageState createState() => _WidgetAssetImageState();
}

class _WidgetAssetImageState extends State<WidgetAssetImage> {
  @override
  void initState() {
    super.initState();
  }

  Future<Uint8List> getAssetThumbnail(AssetEntity asset) async {
    if (widget.thumbnailCache.getData(asset.id) != null) {
      return Future.value(widget.thumbnailCache.getData(asset.id));
    } else {
      var pixelRatio = MediaQuery.of(context).devicePixelRatio;

      return asset
          .thumbDataWithSize(
          (widget.size.width * pixelRatio).toInt(), (widget.size.height * pixelRatio).toInt(),
          quality: 80)
          .then((value) {
        widget.thumbnailCache.setCache(asset.id, value);
        return Future.value(value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap as void Function()?,
      child: _body(),
    );
  }

  Widget _body() {
    var data = widget.thumbnailCache.getData(widget.asset.id);
    if (data != null) {
      return _content(data);
    }
    return FutureBuilder<Uint8List>(
      future: getAssetThumbnail(widget.asset),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print("Snapshot error: ${snapshot.error}");
        }
        return AnimatedOpacity(
          opacity: snapshot.connectionState != ConnectionState.done ? 0.0 : 1.0,
          duration: Duration(milliseconds: 100),
          child: (!snapshot.hasError && snapshot.hasData)
              ? _content(snapshot.data!)
              : Container(),
        );
      },
    );
  }

  Widget _content(Uint8List data) {
    return Stack(
      children: [
        Positioned.fill(
            child: Image.memory(
              data,
              fit: BoxFit.cover,
            )),
        Positioned(bottom: 2, left: 4, right: 4, child: _bottomInfo())
      ],
    );
  }

  Widget _bottomInfo() {
    if (widget.asset.type == AssetType.video && widget.asset.duration > 0) {
      Duration duration = Duration(seconds: widget.asset.duration);
      String formattedDuration = "";
      if (duration.inHours > 0) {
        formattedDuration = "${duration.inHours}:";
      }
      formattedDuration =
      "$formattedDuration${duration.inMinutes.remainder(60).toString().padLeft(1, "0")}:${duration.inSeconds.remainder(60).toString().padLeft(2, "0")}";
      return Text(
        formattedDuration,
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.end,
      );
    }
    return Container();
  }
}