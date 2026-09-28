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
    final uri = Uri.tryParse(customPath);
    if (uri?.scheme == 'https' || uri?.scheme == 'http') {
      return Image.network(
        customPath,
        width: width,
        height: height,
        fit: fit,
        frameBuilder: (context, child, frame, synchronous) =>
            frame == null && !synchronous
            ? Container(
                width: width,
                height: height,
                color: const Color(0xFFF1F3F5),
                alignment: Alignment.center,
                child: const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : child,
        errorBuilder: (_, _, _) =>
            Image.asset(_fallbackAsset, width: width, height: height, fit: fit),
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
