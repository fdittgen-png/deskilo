// SPDX-License-Identifier: MIT
import 'dart:ui' as ui;

import 'package:deskilo/features/workspace/domain/qr_png.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buildQrPng returns a decodable PNG of the requested size',
      (tester) async {
    // Image encoding futures only complete under real async.
    await tester.runAsync(() async {
      final bytes = await buildQrPng('GKWN73PZHL', size: 512);

      // PNG magic header.
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 512);
      expect(frame.image.height, 512);
    });
  });
}
