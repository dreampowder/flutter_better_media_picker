import 'dart:io';

import 'dart:typed_data';

class ModelSelectedAsset{
  final String id;
  final int width;
  final int height;
  final File file;
  final Uint8List thumbnail;

  ModelSelectedAsset({
        required this.id,
        required this.width,
        required this.height,
        required this.file,
        required this.thumbnail});
}