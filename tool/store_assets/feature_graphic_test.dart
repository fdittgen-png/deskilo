// Copyright (c) 2026 Florian DITTGEN
// SPDX-License-Identifier: 0BSD

// One-off generator for the Play Store feature graphic (1024x500). Lives
// under tool/ (not test/) so `flutter test` in CI never runs it; regenerate
// on demand with:
//
//   flutter test tool/store_assets/feature_graphic_test.dart
//
// Output: fastlane/metadata/android/en-US/images/featureGraphic.png
// Brand: #D32F2F background + the white desk-and-seat glyph from
// assets/icon (flutter_launcher_icons source), wordmark in Roboto Bold
// loaded from the Flutter SDK's material_fonts cache.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _width = 1024.0;
const _height = 500.0;

/// Draws the DesKilo glyph (desk bar + seat below) into a box of [w] width.
/// Proportions measured from assets/icon/icon_full.png: bar height 0.34w,
/// corner radius 0.12w, seat 0.39w square starting at 0.45w.
void _drawGlyph(Canvas canvas, Offset origin, double w, Paint paint) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx, origin.dy, w, 0.34 * w),
      Radius.circular(0.12 * w),
    ),
    paint,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(origin.dx + (w - 0.39 * w) / 2, origin.dy + 0.45 * w,
          0.39 * w, 0.39 * w),
      Radius.circular(0.10 * w),
    ),
    paint,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate the Play feature graphic', () async {
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    expect(flutterRoot, isNotNull,
        reason: 'run via `flutter test`, which sets FLUTTER_ROOT');
    final robotoBold = File(
        '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Bold.ttf');
    expect(robotoBold.existsSync(), isTrue,
        reason: 'Roboto-Bold.ttf missing from the SDK material_fonts cache');
    final loader = FontLoader('RobotoBold')
      ..addFont(Future.value(
          ByteData.sublistView(await robotoBold.readAsBytes())));
    await loader.load();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Background: subtle vertical gradient around the brand red.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _width, _height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDB3B36), Color(0xFFC22525)],
        ).createShader(const Rect.fromLTWH(0, 0, _width, _height)),
    );
    // Decorative oversized glyph bleeding off the right edge.
    _drawGlyph(canvas, const Offset(760, 30), 520,
        Paint()..color = const Color(0x12FFFFFF));

    // Foreground group: glyph + wordmark, centered as a unit.
    final wordmark = TextPainter(
      text: const TextSpan(
        text: 'DesKilo',
        style: TextStyle(
          fontFamily: 'RobotoBold',
          fontWeight: FontWeight.w700,
          fontSize: 128,
          color: Color(0xFFFFFFFF),
          letterSpacing: -1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const glyphW = 236.0;
    const glyphH = 0.84 * glyphW; // bar + gap + seat
    const gap = 56.0;
    final groupW = glyphW + gap + wordmark.width;
    final left = (_width - groupW) / 2;
    _drawGlyph(canvas, Offset(left, (_height - glyphH) / 2), glyphW,
        Paint()..color = const Color(0xFFFFFFFF));
    wordmark.paint(canvas,
        Offset(left + glyphW + gap, (_height - wordmark.height) / 2));

    final image = await recorder
        .endRecording()
        .toImage(_width.toInt(), _height.toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('fastlane/metadata/android/en-US/images/featureGraphic.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
    expect(out.lengthSync(), greaterThan(0));
  });
}
