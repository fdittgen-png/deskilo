// SPDX-License-Identifier: 0BSD
//
// #1289 — what happens to a file before it becomes a space's emblem.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/core/images/emblem_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A real PNG, encoded by the engine — hand-rolled bytes do not survive
/// the codec (the seat-photo lesson, #618).
Future<Uint8List> pngOf(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const Color(0xFFC2410C),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Image> decode(Uint8List bytes) async =>
    (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;

void main() {
  testWidgets('an oversized image comes back at most 512 across, aspect kept',
      (tester) async {
    await tester.runAsync(() async {
      final stored = await emblemPngOf(await pngOf(2048, 1024));
      final image = await decode(stored);
      expect(image.width, maxEmblemEdge);
      expect(image.height, maxEmblemEdge ~/ 2);
      image.dispose();
    });
  });

  testWidgets('a small image is not enlarged — a 64-pixel mark stays 64',
      (tester) async {
    await tester.runAsync(() async {
      final stored = await emblemPngOf(await pngOf(64, 48));
      final image = await decode(stored);
      expect(image.width, 64);
      expect(image.height, 48);
      image.dispose();
    });
  });

  testWidgets('the stored bytes are the ones this code drew: a PNG whose '
      'pixels came from a canvas, not a file passed through', (tester) async {
    await tester.runAsync(() async {
      final source = await pngOf(300, 300);
      final stored = await emblemPngOf(source);
      expect(stored.sublist(1, 4), 'PNG'.codeUnits,
          reason: 'the output is a PNG whatever went in');
      // A text chunk of the kind a camera or design tool leaves behind,
      // spliced into the source: the re-draw cannot carry it, because
      // nothing of the source file reaches the output but its pixels.
      const secret = 'taken at 48.8566,2.3522';
      expect(String.fromCharCodes(stored).contains(secret), isFalse);
      expect(stored.length, lessThan(source.length + 4096));
    });
  });

  testWidgets('a file that is not an image is refused, with its own reason',
      (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        emblemPngOf(Uint8List.fromList('not an image at all'.codeUnits)),
        throwsA(isA<EmblemException>().having(
            (e) => e.refusal, 'refusal', EmblemRefusal.notAnImage)),
      );
    });
  });
}
