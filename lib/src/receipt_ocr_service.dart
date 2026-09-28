import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_models.dart';
import 'receipt_parser.dart';

class _PositionedTextLine {
  const _PositionedTextLine({required this.bounds, required this.text});

  final Rect bounds;
  final String text;
}

class ReceiptOcrService {
  final ReceiptParser _parser = ReceiptParser();

  Future<ReceiptScanResult> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final positioned = <_PositionedTextLine>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          positioned.add(
            _PositionedTextLine(bounds: line.boundingBox, text: line.text),
          );
        }
      }
      positioned.sort((a, b) {
        final row = a.bounds.top.compareTo(b.bounds.top);
        return row.abs() < 8 ? a.bounds.left.compareTo(b.bounds.left) : row;
      });
      final lines = positioned.map((line) => line.text).toList();
      return _parser.parse(recognized.text, orderedLines: lines);
    } finally {
      await recognizer.close();
    }
  }
}
