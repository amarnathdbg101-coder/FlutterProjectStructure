import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

int _pendingProductImageSequence = 0;

List<String> registerPendingProductImages({
  required List<String> images,
  required Map<String, XFile> files,
  required Map<String, Uint8List> bytesByKey,
  required Iterable<(XFile, Uint8List?)> captures,
  int maxImages = 10,
}) {
  final keys = <String>[];
  for (final (sourceFile, bytes) in captures) {
    if (images.length >= maxImages) break;
    keys.add(
      registerPendingProductImage(
        images: images,
        files: files,
        bytesByKey: bytesByKey,
        sourceFile: sourceFile,
        bytes: bytes,
      ),
    );
  }
  return keys;
}

String registerPendingProductImage({
  required List<String> images,
  required Map<String, XFile> files,
  required Map<String, Uint8List> bytesByKey,
  required XFile sourceFile,
  required Uint8List? bytes,
}) {
  final sequence = _pendingProductImageSequence++;
  final imageId = '${DateTime.now().microsecondsSinceEpoch}_$sequence';
  final key = 'pending_product_image_$imageId';

  images.add(key);
  if (bytes != null && bytes.isNotEmpty) {
    files[key] = XFile.fromData(
      bytes,
      name: 'product_$imageId.jpg',
      mimeType: 'image/jpeg',
    );
    bytesByKey[key] = bytes;
  } else {
    files[key] = sourceFile;
  }

  return key;
}
