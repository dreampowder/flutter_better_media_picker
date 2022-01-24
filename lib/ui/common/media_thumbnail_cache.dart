import 'dart:typed_data';

///Singleton Object for handling thumbnail caches
class MediaThumbnailCache {

  final Map<String, Uint8List?> _cache = {};


  MediaThumbnailCache();

  void setCache(String assetId, Uint8List? data) {
    _cache[assetId] = data;
  }

  Uint8List? getData(String assetId) {
    return _cache[assetId];
  }

  bool hasKey(String assetId){
    return _cache.containsKey(assetId);
  }

  void dispose() {
    _cache.clear();
  }
}
