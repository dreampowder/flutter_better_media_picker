import 'dart:typed_data';

import 'package:flutter_better_media_picker/ui/common/media_thumbnail_cache.dart';
import 'package:flutter_better_media_picker/ui/common/utils_asset_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void main() {
  group('nextPageKey', () {
    test('first page is 0 (photo_manager pages are 0-based)', () {
      expect(MediaPickerUtils.nextPageKey(PagingState<int, int>()), 0);
    });

    test('continues after a short page; photo_manager may drop missing assets', () {
      final state = PagingState<int, int>(pages: [
        [1, 2, 3],
        [4],
      ], keys: [0, 1]);
      expect(MediaPickerUtils.nextPageKey(state), 2);
    });

    test('stops after an empty page', () {
      final state = PagingState<int, int>(pages: [
        [1, 2],
        [],
      ], keys: [0, 1]);
      expect(MediaPickerUtils.nextPageKey(state), isNull);
    });
  });

  group('formatDuration', () {
    test('under an hour is m:ss', () {
      expect(MediaPickerUtils.formatDuration(5), '0:05');
      expect(MediaPickerUtils.formatDuration(59 * 60 + 59), '59:59');
    });

    test('from an hour pads minutes', () {
      expect(MediaPickerUtils.formatDuration(3600), '1:00:00');
      expect(MediaPickerUtils.formatDuration(3600 + 5 * 60 + 3), '1:05:03');
    });
  });

  group('MediaThumbnailCache', () {
    final a = Uint8List.fromList([1]);
    final b = Uint8List.fromList([2]);
    final c = Uint8List.fromList([3]);

    test('evicts least recently used past capacity', () {
      final cache = MediaThumbnailCache(maxEntries: 2)
        ..setCache('a', a)
        ..setCache('b', b);
      cache.getData('a');
      cache.setCache('c', c);
      expect(cache.hasKey('b'), isFalse);
      expect(cache.getData('a'), a);
      expect(cache.getData('c'), c);
    });

    test('keeps null entries as known misses', () {
      final cache = MediaThumbnailCache()..setCache('a', null);
      expect(cache.hasKey('a'), isTrue);
      expect(cache.getData('a'), isNull);
    });
  });
}
