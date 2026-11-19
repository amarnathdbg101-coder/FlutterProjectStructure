import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_project_structure/features/products/utils/product_photo_quality.dart';

void main() {
  test('classifies dim, balanced, and overexposed product lighting', () {
    expect(classifyProductPhotoLighting(null), ProductPhotoLighting.checking);
    expect(classifyProductPhotoLighting(64), ProductPhotoLighting.tooDark);
    expect(classifyProductPhotoLighting(65), ProductPhotoLighting.good);
    expect(classifyProductPhotoLighting(220), ProductPhotoLighting.good);
    expect(classifyProductPhotoLighting(221), ProductPhotoLighting.tooBright);
  });
}
