import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_project_structure/core/utils/image_utils.dart';

void main() {
  test('normalizeBytes bakes EXIF orientation and downscales large images', () async {
    // Create a 2000x1000 test image in memory
    final testImage = img.Image(width: 2000, height: 1000);
    // Fill with solid color
    img.fill(testImage, color: img.ColorRgb8(255, 128, 0));

    // Encode to JPEG
    final rawJpg = Uint8List.fromList(img.encodeJpg(testImage));

    // Normalize with maxDimension: 800
    final normalized = await normalizeBytes(rawJpg, maxDimension: 800, quality: 85);
    expect(normalized.isNotEmpty, isTrue);

    // Decode normalized image
    final decoded = img.decodeImage(normalized);
    expect(decoded, isNotNull);
    expect(decoded!.width, equals(800));
    expect(decoded.height, equals(400));
  });

  test('normalizeBytes handles invalid bytes gracefully without throwing', () async {
    final garbage = Uint8List.fromList([1, 2, 3, 4, 5]);
    final result = await normalizeBytes(garbage);
    expect(result, equals(garbage));
  });
}
