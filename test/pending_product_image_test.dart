import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_project_structure/features/products/utils/pending_product_image.dart';

void main() {
  test(
    'repeated captures from the same camera file keep separate images',
    () async {
      final firstBytes = Uint8List.fromList([1, 2, 3]);
      final secondBytes = Uint8List.fromList([4, 5, 6]);
      final source = XFile.fromData(
        firstBytes,
        name: 'camera.jpg',
        mimeType: 'image/jpeg',
      );
      final images = <String>[];
      final files = <String, XFile>{};
      final bytesByKey = <String, Uint8List>{};

      final keys = registerPendingProductImages(
        images: images,
        files: files,
        bytesByKey: bytesByKey,
        captures: [(source, firstBytes), (source, secondBytes)],
      );

      final firstKey = keys[0];
      final secondKey = keys[1];
      expect(firstKey, isNot(secondKey));
      expect(images, [firstKey, secondKey]);
      expect(await files[firstKey]!.readAsBytes(), firstBytes);
      expect(await files[secondKey]!.readAsBytes(), secondBytes);
    },
  );
}
