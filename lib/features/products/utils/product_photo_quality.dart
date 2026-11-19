enum ProductPhotoLighting { checking, tooDark, good, tooBright }

ProductPhotoLighting classifyProductPhotoLighting(double? averageLuma) {
  if (averageLuma == null) return ProductPhotoLighting.checking;
  if (averageLuma < 65) return ProductPhotoLighting.tooDark;
  if (averageLuma > 220) return ProductPhotoLighting.tooBright;
  return ProductPhotoLighting.good;
}
