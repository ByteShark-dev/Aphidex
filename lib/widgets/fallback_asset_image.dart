import 'package:flutter/material.dart';

class FallbackAssetImage extends StatelessWidget {
  final String assetName;
  final String fallbackAssetName;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final BorderRadius? borderRadius;
  final int? cacheWidth;
  final int? cacheHeight;

  const FallbackAssetImage.asset({
    super.key,
    required this.assetName,
    required this.fallbackAssetName,
    this.width,
    this.height,
    this.fit,
    this.borderRadius,
    this.cacheWidth,
    this.cacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    Widget buildImage(String asset) {
      final image = Image.asset(
        asset,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
      );
      if (borderRadius == null) {
        return image;
      }
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    return Image.asset(
      assetName,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) =>
          buildImage(fallbackAssetName),
    );
  }
}
