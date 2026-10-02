import 'dart:collection';
import 'dart:typed_data';

/// Bounded LRU cache for thumbnail bytes, scoped to one picker session.
///
/// A `null` value records a lookup that produced no thumbnail, so it is not
/// retried while it stays cached.
class MediaThumbnailCache {
  MediaThumbnailCache({this.maxEntries = 300}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<String, Uint8List?> _cache = LinkedHashMap();

  void setCache(String key, Uint8List? data) {
    _cache.remove(key);
    _cache[key] = data;
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  Uint8List? getData(String key) {
    if (!_cache.containsKey(key)) {
      return null;
    }
    final data = _cache.remove(key);
    _cache[key] = data;
    return data;
  }

  bool hasKey(String key) => _cache.containsKey(key);

  void dispose() {
    _cache.clear();
  }
}
