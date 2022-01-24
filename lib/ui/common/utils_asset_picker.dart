import 'package:flutter/foundation.dart';
class MediaPickerUtils{

  static void debugPrint(String message){
    if(kDebugMode){
      print("[MEDIA PICKER]: $message");
    }
  }
}