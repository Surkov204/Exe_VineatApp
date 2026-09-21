import 'dart:io';

import 'package:flutter/material.dart';

import 'inventory_store.dart';

const _assetRoot = 'design_reference/home/page_files/';

class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.name,
    required this.assetIndex,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String name;
  final int assetIndex;
  final double? width;
  final double? height;
  final BoxFit fit;

  String get _fallbackAsset =>
      '$_assetRoot${assetIndex == 0 ? 'search-image' : 'search-image($assetIndex)'}';

  @override
  Widget build(BuildContext context) {
    final customPath = customFoodImagePaths[name];
    if (customPath == null || customPath.isEmpty) {
      return Image.asset(
        _fallbackAsset,
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.file(
      File(customPath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) =>
          Image.asset(_fallbackAsset, width: width, height: height, fit: fit),
    );
  }
}
