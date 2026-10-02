import 'package:flutter/foundation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class MediaPickerUtils {
  static void debugPrint(String message) {
    if (kDebugMode) {
      print("[MEDIA PICKER]: $message");
    }
  }

  /// Next page key for photo_manager's 0-based `getAssetListPaged`.
  ///
  /// Stops only on an empty page: photo_manager may return fewer items than
  /// requested while more pages exist (missing assets are filtered out).
  static int? nextPageKey(PagingState<int, Object?> state) {
    final keys = state.keys;
    if (keys == null || keys.isEmpty) {
      return 0;
    }
    if (state.pages!.last.isEmpty) {
      return null;
    }
    return keys.last + 1;
  }

  /// Formats a duration in seconds as `m:ss`, or `h:mm:ss` from one hour.
  static String formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    if (duration.inHours > 0) {
      final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
      return "${duration.inHours}:$minutes:$seconds";
    }
    return "${duration.inMinutes}:$seconds";
  }
}
