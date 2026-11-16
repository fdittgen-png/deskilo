// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — a report picture is stored at print size when it is added.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:deskilo/core/images/report_picture_bytes.dart';
import 'package:deskilo/core/images/report_picture_sizes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A picture made here: smooth colour, or noise that no encoder can shrink.
img.Image picture(int w, int h, {bool noise = false, bool hole = false}) {
  final p = img.Image(width: w, height: h, numChannels: 4);
  final rgba = p.data!.buffer.asUint8List();
  final random = math.Random(3984);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      rgba[i] = noise ? random.nextInt(256) : (x * 255 ~/ w);
      rgba[i + 1] = noise ? random.nextInt(256) : (y * 255 ~/ h);
      rgba[i + 2] = noise ? random.nextInt(256) : 128;
      // A transparent corner: a stamp's round edge.
      rgba[i + 3] = hole && x < w ~/ 4 && y < h ~/ 4 ? 0 : 255;
    }
  }
  return p;
}

Uint8List jpegOf(img.Image p) => img.encodeJpg(p, quality: 90);
Uint8List pngOf(img.Image p) => img.encodePng(p);

img.Image read(Uint8List bytes) => img.decodeImage(bytes)!;

void main() {
  testWidgets('a 4000 x 3000 picture without transparency is a JPEG of 2200 '
      'across and at most 500 KiB', (tester) async {
    await tester.runAsync(() async {
      final stored = await reportPictureForPrint(
        pngOf(picture(4000, 3000, noise: true)),
      );
      expect(stored.contentType, 'image/jpeg');
      expect(reportPictureTypeOf(stored.bytes), 'image/jpeg');
      expect(
        stored.bytes.lengthInBytes,
        lessThanOrEqualTo(reportPictureMaxBytes),
      );
      final out = read(stored.bytes);
      expect(math.max(out.width, out.height), lessThanOrEqualTo(2200));
      expect(out.width / out.height, closeTo(4 / 3, 0.01));
    });
  });

  testWidgets('a smooth 4000 x 3000 picture keeps 2200 across at quality 85', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final stored = await reportPictureForPrint(jpegOf(picture(4000, 3000)));
      final out = read(stored.bytes);
      expect(out.width, 2200);
      expect(out.height, 1650);
      expect(
        stored.bytes.lengthInBytes,
        lessThanOrEqualTo(reportPictureMaxBytes),
      );
    });
  });

  testWidgets(
    'a picture with transparency stays a PNG of at most 1200 across',
    (tester) async {
      await tester.runAsync(() async {
        final stored = await reportPictureForPrint(
          pngOf(picture(4000, 3000, hole: true)),
        );
        expect(stored.contentType, 'image/png');
        expect(reportPictureTypeOf(stored.bytes), 'image/png');
        final out = read(stored.bytes);
        expect(out.width, 1200);
        expect(out.height, 900);
        expect(out.getPixel(10, 10).a, 0, reason: 'the hole is still a hole');
        expect(
          stored.bytes.lengthInBytes,
          lessThanOrEqualTo(reportPictureMaxBytes),
        );
      });
    },
  );

  testWidgets('a JPEG within size and weight is stored byte for byte', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final original = jpegOf(picture(800, 600));
      expect(original.lengthInBytes, lessThanOrEqualTo(reportPictureMaxBytes));
      final stored = await reportPictureForPrint(original);
      expect(stored.bytes, original);
      expect(stored.contentType, 'image/jpeg');
    });
  });

  testWidgets('a small PNG with transparency is stored byte for byte', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final original = pngOf(picture(300, 200, hole: true));
      final stored = await reportPictureForPrint(original);
      expect(stored.bytes, original);
      expect(stored.contentType, 'image/png');
    });
  });

  testWidgets('a PNG without transparency is converted to a JPEG, whatever '
      'the size', (tester) async {
    await tester.runAsync(() async {
      final stored = await reportPictureForPrint(pngOf(picture(300, 200)));
      expect(stored.contentType, 'image/jpeg');
      expect(read(stored.bytes).width, 300, reason: 'never enlarged or cut');
    });
  });

  testWidgets('a WebP is converted to a JPEG or a PNG', (tester) async {
    await tester.runAsync(() async {
      // A 1 x 1 lossless WebP.
      final webp = base64Decode(
        'UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA==',
      );
      expect(reportPictureTypeOf(webp), 'image/webp');
      final stored = await reportPictureForPrint(webp);
      expect(stored.contentType, anyOf('image/jpeg', 'image/png'));
      expect(reportPictureTypeOf(stored.bytes), stored.contentType);
    });
  });

  testWidgets('bytes that are no picture are refused', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        reportPictureForPrint(Uint8List.fromList('not a picture'.codeUnits)),
        throwsA(isA<ReportPictureException>()),
      );
    });
  });
}
