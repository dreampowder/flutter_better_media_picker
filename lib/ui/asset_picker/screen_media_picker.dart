import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../model/model_media_picker_strings.dart';
import '../common/media_thumbnail_cache.dart';
import '../common/utils_asset_picker.dart';
import 'screen_album_picker.dart';
import 'widget_media_item.dart';

enum MediaDownloadState { downloading, complete, error }

class ScreenMediaPicker extends StatefulWidget {
  final List<AssetEntity>? selectedAssets;
  final int crossAxisCount;
  final int maxAssets;
  final RequestType requestType;
  final int pageSize;
  final MediaPickerStrings? localizedStrings;
  final void Function(MediaDownloadState state, Object? error)? onDownloadMediaStateChanged;
  final void Function(Object error)? onReceiveError;

  /// Replaces the built-in photo_manager permission request when set.
  /// Must resolve to `true` when the library can be read.
  final Future<bool> Function()? permissionHandler;

  const ScreenMediaPicker({
    this.crossAxisCount = 3,
    this.maxAssets = 5,
    this.selectedAssets,
    this.requestType = RequestType.common,
    this.pageSize = 50,
    this.localizedStrings,
    this.onDownloadMediaStateChanged,
    this.onReceiveError,
    this.permissionHandler,
    super.key,
  }) : assert(pageSize > 0),
       assert(maxAssets > 0);

  @override
  ScreenMediaPickerState createState() => ScreenMediaPickerState();
}

class ScreenMediaPickerState extends State<ScreenMediaPicker> {
  late final PagingController<int, AssetEntity> _pagingController = PagingController(
    getNextPageKey: MediaPickerUtils.nextPageKey,
    fetchPage: _fetchPage,
  );

  final List<AssetPathEntity> albums = [];
  AssetPathEntity? currentAlbum;

  late final List<AssetEntity> selectedAssets = [...?widget.selectedAssets];

  final MediaThumbnailCache _thumbnailCache = MediaThumbnailCache();

  bool? didGivePermission;
  bool _didStartChangeNotify = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _initPhotoManager());
  }

  @override
  void dispose() {
    if (_didStartChangeNotify) {
      PhotoManager.removeChangeCallback(_onLibraryChanged);
      PhotoManager.stopChangeNotify();
    }
    _pagingController.dispose();
    _thumbnailCache.dispose();
    super.dispose();
  }

  void _reportError(Object error) {
    MediaPickerUtils.debugPrint("Error: $error");
    widget.onReceiveError?.call(error);
  }

  Future<bool> _requestAccess() async {
    final handler = widget.permissionHandler;
    if (handler != null) {
      return handler();
    }
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: PermissionRequestOption(
        androidPermission: AndroidPermission(type: widget.requestType, mediaLocation: false),
      ),
    );
    return state.hasAccess;
  }

  Future<void> _initPhotoManager() async {
    bool hasAccess;
    try {
      hasAccess = await _requestAccess();
    } catch (error) {
      _reportError(error);
      hasAccess = false;
    }
    if (!mounted) return;
    if (!hasAccess) {
      setState(() => didGivePermission = false);
      return;
    }
    setState(() => didGivePermission = true);

    PhotoManager.addChangeCallback(_onLibraryChanged);
    PhotoManager.startChangeNotify();
    _didStartChangeNotify = true;

    final List<AssetPathEntity> paths;
    try {
      paths = await PhotoManager.getAssetPathList(hasAll: true, type: widget.requestType);
    } catch (error) {
      _reportError(error);
      return;
    }
    if (!mounted) return;
    setState(() {
      albums
        ..clear()
        ..addAll(paths);
      if (paths.isNotEmpty) {
        final allIndex = paths.indexWhere((album) => album.isAll);
        currentAlbum = paths[allIndex == -1 ? 0 : allIndex];
      }
    });
  }

  void _onLibraryChanged(MethodCall _) {
    if (!mounted || currentAlbum == null) return;
    _pagingController.refresh();
  }

  void changeAlbum(AssetPathEntity album) {
    if (currentAlbum == album) return;
    setState(() => currentAlbum = album);
    _pagingController.refresh();
  }

  Future<List<AssetEntity>> _fetchPage(int page) async {
    final album = currentAlbum;
    if (album == null) return [];
    try {
      return await album.getAssetListPaged(page: page, size: widget.pageSize);
    } catch (error) {
      _reportError(error);
      rethrow;
    }
  }

  Future<void> _showAlbumPicker() async {
    final album = await Navigator.of(context).push(
      MaterialPageRoute<AssetPathEntity>(
        builder: (_) => ScreenAlbumPicker(
          selectedAlbum: currentAlbum,
          thumbnailCache: _thumbnailCache,
          localizedStrings: widget.localizedStrings,
          requestType: widget.requestType,
          onReceiveError: widget.onReceiveError,
        ),
        fullscreenDialog: true,
      ),
    );
    if (album != null && mounted) {
      changeAlbum(album);
    }
  }

  void _onSelectMedia(AssetEntity asset) {
    if (widget.maxAssets == 1) {
      closeWithSelectedAssets([asset]);
      return;
    }
    setState(() {
      final index = selectedAssets.indexWhere((e) => e.id == asset.id);
      if (index != -1) {
        selectedAssets.removeAt(index);
      } else if (selectedAssets.length < widget.maxAssets) {
        selectedAssets.add(asset);
      }
    });
  }

  /// Downloads any non-local (e.g. iCloud) originals, then pops with [assets].
  /// On download failure the picker stays open so the user can retry.
  Future<void> closeWithSelectedAssets(List<AssetEntity> assets) async {
    if (_isClosing) return;
    _isClosing = true;
    final onDownload = widget.onDownloadMediaStateChanged;
    var didStartDownload = false;
    try {
      final missing = <AssetEntity>[];
      for (final asset in assets) {
        if (!await asset.isLocallyAvailable(isOrigin: true)) {
          missing.add(asset);
        }
      }
      if (missing.isNotEmpty) {
        MediaPickerUtils.debugPrint("Downloading ${missing.length} asset(s)");
        didStartDownload = true;
        onDownload?.call(MediaDownloadState.downloading, null);
        await Future.wait(missing.map(_download));
        onDownload?.call(MediaDownloadState.complete, null);
      }
      if (!mounted) return;
      Navigator.of(context).pop(assets);
    } catch (error) {
      MediaPickerUtils.debugPrint("Download failed: $error");
      if (didStartDownload) {
        onDownload?.call(MediaDownloadState.error, error);
      } else {
        _reportError(error);
      }
      _isClosing = false;
    }
  }

  Future<void> _download(AssetEntity asset) async {
    final file = await asset.loadFile(isOrigin: true);
    if (file == null) {
      throw StateError("Could not load original file for asset ${asset.id}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar,
      body: _body,
    );
  }

  AppBar get _appBar => AppBar(
    title: albums.isEmpty
        ? null
        : GestureDetector(
            onTap: _showAlbumPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.keyboard_arrow_up),
                Flexible(child: Text(currentAlbum?.name ?? "", overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
    actions: widget.maxAssets == 1
        ? null
        : [
            TextButton(
              onPressed: () => closeWithSelectedAssets(List.of(selectedAssets)),
              child: Text(
                widget.localizedStrings?.add ?? "Add",
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ],
  );

  Widget get _body {
    if (didGivePermission == null) return _loading();
    if (didGivePermission == false) return _noAccess();
    if (albums.isEmpty) return const SizedBox.shrink();
    return PagingListener(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => PagedGridView<int, AssetEntity>(
        state: state,
        fetchNextPage: fetchNextPage,
        builderDelegate: PagedChildBuilderDelegate<AssetEntity>(
          itemBuilder: (context, item, index) => _assetThumbnail(item),
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.crossAxisCount,
        ),
      ),
    );
  }

  Widget _loading() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _noAccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.localizedStrings?.noPermissionTitle ?? "Cannot access to library",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.localizedStrings?.noPermissionDescription ??
                  "You must give permission in order to pick photos.\nPlease give permission from settings",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                PhotoManager.openSetting();
              },
              child: Text(widget.localizedStrings?.openSettings ?? "Open Settings"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assetThumbnail(AssetEntity asset) {
    final width = MediaQuery.sizeOf(context).width / widget.crossAxisCount;
    return Padding(
      key: ValueKey(asset.id),
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
              ),
            ),
            Positioned(
              top: 4,
              left: 8,
              child: _getCount(asset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getCount(AssetEntity asset) {
    final index = selectedAssets.indexWhere((e) => e.id == asset.id);
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
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Text(
            index == -1 ? "" : (index + 1).toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }
}
