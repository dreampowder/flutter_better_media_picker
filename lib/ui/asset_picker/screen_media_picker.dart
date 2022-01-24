import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:media_picker/model/model_media_picker_strings.dart';
import 'package:media_picker/ui/asset_picker/screen_album_picker.dart';
import 'package:media_picker/ui/asset_picker/widget_media_item.dart';
import 'package:media_picker/ui/common/media_thumbnail_cache.dart';
import 'package:media_picker/ui/common/utils_asset_picker.dart';
import 'package:photo_manager/photo_manager.dart';

enum MediaDownloadState{
  downlading, complete
}

class ScreenMediaPicker extends StatefulWidget {
  final List<AssetEntity>? selectedAssets;
  final int crossAxisCount;
  final int maxAssets;
  final RequestType requestType;
  final int pageSize;
  final MediaPickerStrings? localizedStrings;
  final Function(MediaDownloadState state)? onDownloadMediaStateChanged;
  final Function(dynamic error)? onReceiveError;
  const ScreenMediaPicker(
      {this.crossAxisCount = 3,
        this.maxAssets = 5,
        this.selectedAssets,
        this.requestType = RequestType.common,
        this.pageSize = 50,
        this.localizedStrings,
        this.onDownloadMediaStateChanged,
        this.onReceiveError,
        Key? key,
      }):super(key: key);

  @override
  _ScreenMediaPickerState createState() => _ScreenMediaPickerState();
}

class _ScreenMediaPickerState extends State<ScreenMediaPicker> {

  static const maxPageSize = 50;
  final Set<int> requestedPages = {}; //Paging controller has a bug that it might fetches each page for multiple times.
  final PagingController<int,AssetEntity> _pagingController = PagingController<int,AssetEntity>(firstPageKey: 0);

  final List<AssetPathEntity> albums = [];
  AssetPathEntity? currentAlbum;

  late List<AssetEntity> selectedAssets;

  final MediaThumbnailCache _thumbnailCache = MediaThumbnailCache();

  @override
  void dispose() {
    PhotoManager.stopChangeNotify();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    selectedAssets = widget.selectedAssets ?? [];
    _initPagingController();
    SchedulerBinding.instance?.addPostFrameCallback((timeStamp) => _initPhotoManager());
  }

  void _initPhotoManager(){
    PhotoManager.addChangeCallback((value) {
      if(currentAlbum == null){
        return;
      }
      changeAlbum(currentAlbum!, true);
    });
    PhotoManager.startChangeNotify();
    PhotoManager.getAssetPathList(hasAll: true,type: widget.requestType)
    .then((albums){
      setState(() {
        this.albums.clear();
        this.albums.addAll(albums);
        var albumIndex = albums.indexWhere((album) => album.isAll);
        if(albumIndex == -1){
          albumIndex = 0;
        }
        if(albums.isNotEmpty){
          currentAlbum = albums[albumIndex];
        }else{
          _pagingController.appendLastPage([]);
        }
      });
    });
  }

  void changeAlbum(AssetPathEntity album, bool forceRefresh){
    requestedPages.clear();
    _pagingController.refresh();
  }

  void _initPagingController(){
    _pagingController.addPageRequestListener((pageKey) {
      if(requestedPages.contains(pageKey)){
        MediaPickerUtils.debugPrint("Already Requested page:$pageKey for album: ${currentAlbum?.name}");
        return;
      }
      currentAlbum?.getAssetListPaged(pageKey, widget.pageSize).then((assets){
        if(assets.length < widget.pageSize){
          _pagingController.appendLastPage(assets);
        }else{
          _pagingController.nextPageKey = pageKey + 1;
          _pagingController.appendPage(assets, _pagingController.nextPageKey);
        }
      });
    });
  }

  void _showAlbumPicker(){
    Navigator.of(context).push(MaterialPageRoute(builder: (context)=>ScreenAlbumPicker(selectedAlbum: currentAlbum, thumbnailCache: _thumbnailCache, requestType: widget.requestType,), fullscreenDialog: true));
  }

  void _onSelectMedia(AssetEntity asset) async{
    if (widget.maxAssets == 1) {
      closeWithSelectedAssets([asset]);
    } else {
      if (selectedAssets.indexWhere((e) => e.id == asset.id) == -1) {
        if (selectedAssets.length < widget.maxAssets) {
          selectedAssets.add(asset);
        }
      } else {
        selectedAssets.removeWhere((e) => e.id == asset.id);
      }
      setState(() {});
    }
  }

  void closeWithSelectedAssets(List<AssetEntity> assets) async{
    bool doesNeedsDownloading = false;
    for(int i = 0;i<assets.length; i++){
      if((await assets[i].isLocallyAvailable) == false){
        doesNeedsDownloading = true;
      }
    }
    if(!doesNeedsDownloading){
      Navigator.of(context).pop(assets);
    }else{
      MediaPickerUtils.debugPrint("There are medias that needs to be downloaded. Beginning Download");
      if(widget.onDownloadMediaStateChanged != null){
        widget.onDownloadMediaStateChanged!(MediaDownloadState.downlading);
      }
      Future.wait(assets.map((e) => downloadAssetIfNeeded(e)))
      .catchError((error){
        MediaPickerUtils.debugPrint("Got error whlie downloading: $error");
        if(widget.onReceiveError != null){
          widget.onReceiveError!(error);
        }
      }).then((value){
        if(widget.onDownloadMediaStateChanged != null){
          widget.onDownloadMediaStateChanged!(MediaDownloadState.complete);
        }
        Navigator.of(context).pop(assets);
      });
    }
  }

  Future<void> downloadAssetIfNeeded(AssetEntity asset) async{

    var isLocallyAvailable = await asset.isLocallyAvailable;
    if(!isLocallyAvailable){
      MediaPickerUtils.debugPrint("Downloading asset: ${asset}");
      var completer = Completer();
      asset.loadFile(
        isOrigin: true,
      ).then((value){
        MediaPickerUtils.debugPrint("Download complete: ${asset}");
        completer.complete();
      }).catchError((error){
        completer.completeError(error);
      });
      return completer.future;
    }else{
      return Future.value();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar,
      body: _body,
    );
  }

  AppBar get _appBar=>AppBar(
    title: (albums.isEmpty) ? Container() :
    GestureDetector(
        onTap: _showAlbumPicker,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_arrow_up),
            Text(currentAlbum?.name ?? ""),
          ],
        )
    ),
    actions: widget.maxAssets == 1 ? null : [
      TextButton(
        onPressed: () => closeWithSelectedAssets(selectedAssets),
        child: Text(
          widget.localizedStrings?.add ?? "Add",
          style: TextStyle(color: Theme.of(context).colorScheme.secondary),
        ),
      )
    ],
  );

  Widget get _body =>Container(
    child: albums.isEmpty ? Container() : PagedGridView<int,AssetEntity>(
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<AssetEntity>(
          itemBuilder: (context, item, index) => _assetThumbnail(item),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
        )
    ),
  );

  Widget _assetThumbnail(AssetEntity asset) {
    var width = MediaQuery.of(context).size.width / widget.crossAxisCount;
    return Padding(
      padding: const EdgeInsets.all(0.5),
      child: GridTile(
          child: Stack(
            children: [
              Positioned.fill(
                  child: WidgetAssetImage(
                    size: Size(width, width),
                    asset: asset,
                    onTap: () => _onSelectMedia(asset),
                    thumbnailCache: _thumbnailCache,
                  )),
              Positioned(
                top: 4,
                left: 8,
                child: _getCount(asset),
              )
            ],
          )),
    );
  }

  Widget _getCount(AssetEntity asset) {
    var index = selectedAssets.indexWhere((e) => e.id == asset.id);
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: index == -1 ? 0.0 : 1.0,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5)),
          child: Text(index == -1 ? "" : (index + 1).toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w400,),
          ),
        ),
      ),
    );
  }
}

