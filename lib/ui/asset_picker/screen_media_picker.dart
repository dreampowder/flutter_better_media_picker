// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../model/model_media_picker_strings.dart';
import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';
import 'screen_album_picker.dart';
import 'widget_media_item.dart';

enum MediaDownloadState{
  downloading, complete, error
}

class ScreenMediaPicker extends StatefulWidget {
  final List<AssetEntity>? selectedAssets;
  final int crossAxisCount;
  final int maxAssets;
  final RequestType requestType;
  final int pageSize;
  final MediaPickerStrings? localizedStrings;
  final Function(MediaDownloadState state, dynamic error)? onDownloadMediaStateChanged;
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
  ScreenMediaPickerState createState() => ScreenMediaPickerState();
}

class ScreenMediaPickerState extends State<ScreenMediaPicker> {

  static const maxPageSize = 50;

  late final PagingController<int,AssetEntity> _pagingController = PagingController(
      getNextPageKey: (PagingState<int, AssetEntity> state){
        final  page = (state.keys?.last ?? 0) + 1;
        if (page > 1 && (state.pages?.last ?? []).isEmpty) {
          return null;
        }
        return page;
      },
      fetchPage: _fetchNextPage
  );

  final List<AssetPathEntity> albums = [];
  AssetPathEntity? currentAlbum;

  late List<AssetEntity> selectedAssets;

  final MediaThumbnailCache _thumbnailCache = MediaThumbnailCache();

  bool? didGivePermission;
  bool didStartChangeNotify = false;

  @override
  void dispose() {
    debugPrint("Dispose called");
    try{
      if (didStartChangeNotify) {
        PhotoManager.stopChangeNotify();
      }
    }catch(exception){
      debugPrint("Change Notify");
    }

    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    selectedAssets = widget.selectedAssets ?? [];
    // _initPagingController();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) => _initPhotoManager());
  }

  void _initPhotoManager() async{
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.hasAccess) {
      PhotoManager.addChangeCallback((value) {
        if(currentAlbum == null){
          return;
        }
        changeAlbum(currentAlbum!, true);
      });
      PhotoManager.startChangeNotify();
      didStartChangeNotify = true;

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
          }
        });
      });
      setState(() {
        didGivePermission = true;
      });
    } else {
      setState(() {
        didGivePermission = false;
      });
    }
  }

  void changeAlbum(AssetPathEntity album, bool forceRefresh){
    debugPrint("Change Album");
    if (currentAlbum == album) {
      debugPrint("SAME CHANGE ALBUM CALLED, IGNORING");
      return;
    }
    setState(() {
      currentAlbum = album;
    });
    _pagingController.refresh();
  }


  FutureOr<List<AssetEntity>> _fetchNextPage(int pageKey) {
    debugPrint("Getting Next Page: $pageKey -> $currentAlbum");
    var completer = Completer<List<AssetEntity>>();
    currentAlbum?.getAssetListPaged(page:pageKey,size: widget.pageSize).then((assets){
      debugPrint("GOT Assets: ${assets.length} -> ${_pagingController.hasNextPage}");
      completer.complete(assets);
    });
    return completer.future;
  }

  // void _initPagingController(){
  //   _pagingController.addPageRequestListener((pageKey) {
  //     if(requestedPages.contains(pageKey)){
  //       MediaPickerUtils.debugPrint("Already Requested page:$pageKey for album: ${currentAlbum?.name}");
  //       return;
  //     }
  //     requestedPages.add(pageKey);
  //     currentAlbum?.getAssetListPaged(page:pageKey,size: widget.pageSize).then((assets){
  //       if(assets.length < widget.pageSize){
  //         _pagingController.appendLastPage(assets);
  //       }else{
  //         _pagingController.nextPageKey = pageKey + 1;
  //         _pagingController.appendPage(assets, _pagingController.nextPageKey);
  //       }
  //     });
  //   });
  // }

  void _showAlbumPicker(){
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context)=>ScreenAlbumPicker(selectedAlbum: currentAlbum, thumbnailCache: _thumbnailCache, requestType: widget.requestType,), fullscreenDialog: true))
        .then((value){
          if(value is AssetPathEntity){
            changeAlbum(value, true);
          }
    });
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
      if((await assets[i].isLocallyAvailable()) == false){
        doesNeedsDownloading = true;
      }
    }
    if(!doesNeedsDownloading){
      Navigator.of(context).pop(assets);
    }else{
      MediaPickerUtils.debugPrint("There are medias that needs to be downloaded. Beginning Download");
      if(widget.onDownloadMediaStateChanged != null){
        widget.onDownloadMediaStateChanged!(MediaDownloadState.downloading,null);
      }
      Future.wait(assets.map((e) => downloadAssetIfNeeded(e)))
      .catchError((error){
        MediaPickerUtils.debugPrint("Got error whlie downloading: $error");
        if(widget.onDownloadMediaStateChanged != null){
          widget.onDownloadMediaStateChanged!(MediaDownloadState.error,error);
        }
        return Future.value([]);
      }).then((value){
        if(widget.onDownloadMediaStateChanged != null){
          widget.onDownloadMediaStateChanged!(MediaDownloadState.complete,null);
        }
        Navigator.of(context).pop(assets);
      });
    }
  }

  Future<void> downloadAssetIfNeeded(AssetEntity asset) async{
    var isLocallyAvailable =await asset.isLocallyAvailable();
    if(!isLocallyAvailable){
      MediaPickerUtils.debugPrint("Downloading asset: $asset");
      var completer = Completer();
      asset.loadFile(
        isOrigin: true,
      ).then((value){
        MediaPickerUtils.debugPrint("Download complete: $asset");
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

  Widget get _body =>
      didGivePermission == null ?  _loading() :
      didGivePermission! == false ? _noAccess() :
      Container(
    child: albums.isEmpty ? Container() : PagingListener(
        controller: _pagingController,
        builder: (context, state, fetchNextPage){
          debugPrint("State: ${state.isLoading}, ${state.hasNextPage}, ${state.status}");
          return PagedGridView(
              state: state,
              fetchNextPage: fetchNextPage,
              builderDelegate: PagedChildBuilderDelegate<AssetEntity>(
                itemBuilder: (context, item, index) => _assetThumbnail(item),
              ),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.crossAxisCount,
              )
          );
        }
    )
  );

  Widget _loading(){
    return const Center(child: CircularProgressIndicator(),);
  }

  Widget _noAccess(){
    return Center(
      child: Column(
        children: [
          Text(widget.localizedStrings?.noPermissionTitle ?? "Cannot access to library", style: Theme.of(context).textTheme.titleMedium,),
          const SizedBox(height: 8,),
          Text(widget.localizedStrings?.noPermissionDescription ?? "You must give permission in order to pick photos.\nPlease give permission from settings ",),
          const SizedBox(height: 8,),
          ElevatedButton(onPressed: () async{
            Navigator.of(context).pop();
            await PhotoManager.openSetting();
          }, child: Text(widget.localizedStrings?.openSettings ?? "Open Settings"))
        ],
      ),
    );
  }

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

