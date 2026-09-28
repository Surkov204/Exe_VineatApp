import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_models.dart';
import 'receipt_parser.dart';

class ReceiptOcrService {
  final ReceiptParser _parser = ReceiptParser();

  Future<ReceiptScanResult> scan(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final positioned = <(Rect, String)>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          positioned.add((line.boundingBox, line.text));
        }
      }
      positioned.sort((a, b) {
        final row = a.$1.top.compareTo(b.$1.top);
        return row.abs() < 8 ? a.$1.left.compareTo(b.$1.left) : row;
      });
      final lines = positioned.map((e) => e.$2).toList();
      return _parser.parse(recognized.text, orderedLines: lines);
    } finally {
      await recognizer.close();
    }
  }
}
