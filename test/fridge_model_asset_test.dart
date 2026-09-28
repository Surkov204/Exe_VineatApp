import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled fridge GLB is self-contained and structurally intact',
    () async {
      final asset = await rootBundle.load(
        'assets/models/vineat-smart-fridge.glb',
      );
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      final data = ByteData.sublistView(bytes);

      expect(bytes.length, lessThan(256 * 1024));
      expect(
        data.getUint32(0, Endian.little),
        0x46546C67,
        reason: 'glTF magic',
      );
      expect(data.getUint32(4, Endian.little), 2, reason: 'GLB version');
      expect(
        data.getUint32(8, Endian.little),
        bytes.length,
        reason: 'declared file length',
      );

      const jsonChunkType = 0x4E4F534A;
      const binaryChunkType = 0x004E4942;
      Map<String, dynamic>? document;
      int? binaryLength;
      var offset = 12;
      while (offset < bytes.length) {
        expect(
          offset + 8,
          lessThanOrEqualTo(bytes.length),
          reason: 'complete chunk header',
        );
        final length = data.getUint32(offset, Endian.little);
        final type = data.getUint32(offset + 4, Endian.little);
        final end = offset + 8 + length;
        expect(length % 4, 0, reason: 'GLB chunk alignment');
        expect(
          end,
          lessThanOrEqualTo(bytes.length),
          reason: 'chunk stays inside asset',
        );

        if (type == jsonChunkType) {
          expect(document, isNull, reason: 'only one JSON chunk is permitted');
          document =
              jsonDecode(utf8.decode(bytes.sublist(offset + 8, end)).trim())
                  as Map<String, dynamic>;
        } else if (type == binaryChunkType) {
          expect(
            binaryLength,
            isNull,
            reason: 'only one binary chunk is permitted',
          );
          binaryLength = length;
        } else {
          fail('Unexpected GLB chunk type: 0x${type.toRadixString(16)}');
        }
        offset = end;
      }

      expect(offset, bytes.length);
      expect(document, isNotNull);
      final gltf = document!;
      expect((gltf['asset'] as Map<String, dynamic>)['version'], '2.0');

      final buffers = (gltf['buffers'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(buffers, hasLength(1));
      expect(
        buffers.single.containsKey('uri'),
        isFalse,
        reason: 'model must work offline',
      );
      expect(binaryLength, buffers.single['byteLength']);

      final bufferViews = (gltf['bufferViews'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(bufferViews, isNotEmpty);
      for (final view in bufferViews) {
        expect(view['buffer'] ?? 0, 0);
        final start = (view['byteOffset'] as int?) ?? 0;
        final length = view['byteLength'] as int;
        expect(start + length, lessThanOrEqualTo(binaryLength!));
      }

      final meshes = (gltf['meshes'] as List<dynamic>?) ?? const [];
      expect(meshes, isNotEmpty);
      expect(
        meshes.any(
          (mesh) => (mesh as Map<String, dynamic>)['primitives'] is List,
        ),
        isTrue,
        reason: 'the bundled model must contain renderable geometry',
      );
    },
  );
}
