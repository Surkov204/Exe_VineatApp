import 'package:flutter/material.dart';

/// Displays the supplied ViNeat artwork without scaling its wide canvas
/// whitespace into the available space.
class VineatLogo extends StatelessWidget {
  const VineatLogo({
    super.key,
    required this.width,
    this.withBackground = false,
    this.symbolOnly = false,
  });

  final double width;
  final bool withBackground;
  final bool symbolOnly;

  static const _canvas = Size(1200, 1500);
  static const _lockup = Rect.fromLTWH(200, 435, 800, 635);
  static const _symbol = Rect.fromLTWH(400, 440, 415, 450);

  @override
  Widget build(BuildContext context) {
    final crop = symbolOnly ? _symbol : _lockup;
    final scale = width / crop.width;
    final imageWidth = _canvas.width * scale;
    final imageHeight = _canvas.height * scale;
    final centerOffset = Offset(
      (_canvas.width / 2 - crop.center.dx) * scale,
      (_canvas.height / 2 - crop.center.dy) * scale,
    );

    return Semantics(
      label: 'Logo ViNeat',
      image: true,
      child: SizedBox(
        width: width,
        height: crop.height * scale,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: imageWidth,
            maxWidth: imageWidth,
            minHeight: imageHeight,
            maxHeight: imageHeight,
            child: Transform.translate(
              offset: centerOffset,
              child: Image.asset(
                withBackground
                    ? 'assets/branding/vineat-white.png'
                    : 'assets/branding/vineat-transparent.png',
                width: imageWidth,
                height: imageHeight,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
