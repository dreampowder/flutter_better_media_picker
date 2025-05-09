import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../model/model_media_picker_strings.dart';
import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';

class ScreenAlbumPicker extends StatefulWidget {

  final AssetPathEntity? selectedAlbum;
  final MediaThumbnailCache? thumbnailCache;
  final MediaPickerStrings? localizedStrings;
  final RequestType requestType;
  const ScreenAlbumPicker({Key? key, required this.selectedAlbum, required this.thumbnailCache, this.localizedStrings, this.requestType = RequestType.common}) : super(key: key);

  @override
  ScreenAlbumPickerState createState() => ScreenAlbumPickerState();
}

class ScreenAlbumPickerState extends State<ScreenAlbumPicker> {

  late final MediaThumbnailCache _thumbnailCache;
  final Completer<List<AssetPathEntity>> _completer = Completer();

  @override
  void initState() {
    super.initState();

    _thumbnailCache = widget.thumbnailCache ?? MediaThumbnailCache();
    initPhotoManager();
  }

  void initPhotoManager() async{
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.hasAccess) {
      PhotoManager.getAssetPathList(hasAll: true, type: widget.requestType).then((albums) async{

        List<AssetPathEntity> nonEmptyAlbums = [];
        for (var value in albums) {
          var count = await value.assetCountAsync;
          if (count > 0 || value.isAll) {
            nonEmptyAlbums.add(value);
          }
        }

        var allAssetsIndex = nonEmptyAlbums.indexWhere((e) => e.isAll);
        if (allAssetsIndex != -1) {
          var allAssets = nonEmptyAlbums[allAssetsIndex];
          nonEmptyAlbums.removeAt(allAssetsIndex);
          nonEmptyAlbums.insert(0, allAssets);
        }
        getAllAssetPathImages(nonEmptyAlbums);
        _completer.complete(nonEmptyAlbums);
      });
    }else{
      _completer.complete([]);
    }
  }

  Future<void> getAllAssetPathImages(List<AssetPathEntity> allAssetPaths){
    return Future.wait((allAssetPaths).map((path)=>getPathThumbnail(path).then((value){
      if (mounted) {
        setState((){});
      }
    })));
  }

  Future<void> getPathThumbnail(AssetPathEntity path){
    var completer = Completer();
    if(_thumbnailCache.hasKey(path.id)){
      completer.complete();
    }else{
      path.getAssetListRange(start: 0, end: 1).then((assets) {
        if(assets.isEmpty){
          _thumbnailCache.setCache(path.id, Uint8List(0));
          completer.complete();
        }else{
          var asset = assets.first;
          asset.thumbnailData.then((data) {
            _thumbnailCache.setCache(path.id, data);
            completer.complete();
          });
        }
      }).catchError((error){
        MediaPickerUtils.debugPrint("Error getting asset path album thumbnail: $error");
      });
    }
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar,
      body: _body,
    );
  }

  AppBar get _appBar => AppBar(
    title: Text(
      widget.localizedStrings?.albums ?? "Albums",
    ),
  );

  Widget get _body => FutureBuilder<List<AssetPathEntity>>(
    future: _completer.future,
    builder: (context, snapshot){
      if(snapshot.connectionState != ConnectionState.done){
        return const Center(
          child: CircularProgressIndicator(),
        );
      }else if(snapshot.hasError){
        return ErrorWidget(snapshot.error ?? "Error loading snapshot");
      }
      return ListView.builder(
        itemCount: snapshot.data?.length ?? 0,
        itemBuilder: (context, index){
          var path = snapshot.data![index];
          return ListTile(
            leading: getThumbnail(path),
            title: Text(path.name),
            trailing: (path.id != widget.selectedAlbum?.id)
                ? null
                : Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.secondary,
                ),
            onTap: () => Navigator.of(context).pop(path),
          );
        });
    },
  );

  Widget getThumbnail(AssetPathEntity path) {
    var thumbnailData = widget.thumbnailCache?.getData(path.id);
    if(thumbnailData == null || thumbnailData.isEmpty){
      return const SizedBox(
        width: 40,
        height: 40,
        child: Icon(Icons.photo),
      );
    }
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          thumbnailData,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
        ));
  }
}
