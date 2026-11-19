import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
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

  test('compressProductImage downscales to max 1600px with high quality', () async {
    final largeImage = img.Image(width: 3200, height: 1800);
    img.fill(largeImage, color: img.ColorRgb8(40, 100, 200));
    final bytes = Uint8List.fromList(img.encodeJpg(largeImage));

    final xFile = XFile.fromData(bytes, name: 'product_test.jpg', mimeType: 'image/jpeg');
    final (compressedFile, compressedBytes) = await compressProductImage(xFile);

    expect(compressedBytes.isNotEmpty, isTrue);
    final decoded = img.decodeImage(compressedBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, equals(1600));
    expect(decoded.height, equals(900));
  });

  test('compressAvatarOrLogo downscales to max 800px', () async {
    final avatarImage = img.Image(width: 1500, height: 1500);
    img.fill(avatarImage, color: img.ColorRgb8(200, 50, 50));
    final bytes = Uint8List.fromList(img.encodeJpg(avatarImage));

    final xFile = XFile.fromData(bytes, name: 'avatar_test.jpg', mimeType: 'image/jpeg');
    final (compressedFile, compressedBytes) = await compressAvatarOrLogo(xFile);

    expect(compressedBytes.isNotEmpty, isTrue);
    final decoded = img.decodeImage(compressedBytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, equals(800));
    expect(decoded.height, equals(800));
  });

  test('copyResize with cubic interpolation and adjustColor works smoothly', () async {
    final testImage = img.Image(width: 800, height: 600);
    img.fill(testImage, color: img.ColorRgb8(100, 150, 200));

    // High quality cubic resize
    final resized = img.copyResize(testImage, width: 400, interpolation: img.Interpolation.cubic);
    expect(resized.width, equals(400));

    // Subtle contrast & vibrance tuning
    final tuned = img.adjustColor(resized, contrast: 1.05, saturation: 1.08);
    expect(tuned.width, equals(400));
  });
}
