// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — illustrations are drawn off-screen from the safe model only.
//
// Invariant: a rendered illustration is a bounded, metadata-free PNG
// (IHDR/IDAT/IEND only) at the preset's size; a redaction is opaque in
// the ENCODED pixels (every decoded pixel inside it is the fill colour),
// not an overlay; a recording made with canaries at every capture
// boundary renders byte-identical pictures to the committed fixture, so
// no canary can be in the pixels; light and dark themes both render.
// Pixels are read back by decoding the PNG through the engine codec,
// with no golden baseline.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:deskilo/app/theme.dart';
import 'package:deskilo/features/task_recorder/domain/task_recording_codec.dart';
import 'package:deskilo/features/task_recorder/storyboard/illustration_renderer.dart';
import 'package:deskilo/features/task_recorder/storyboard/png_safety.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard.dart';
import 'package:deskilo/features/task_recorder/storyboard/storyboard_builder.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/recording_fixtures.dart';

AppLocalizations _l(String code) => lookupAppLocalizations(Locale(code));

Future<(int, int, ByteData)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final size = (image.width, image.height, data);
  image.dispose();
  codec.dispose();
  return size;
}

void main() {
  final light = DeskiloTheme.light(animations: false).colorScheme;
  final dark = DeskiloTheme.dark(animations: false).colorScheme;

  testWidgets('a scene renders to a bounded, metadata-free PNG', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final sb = buildStoryboard(
        decodeRecordingText(fixtureText(BookingJourney.planConfirmed.file))
            .recording!,
        _l('en'),
      );
      for (final f in sb.frames.where((f) => f.scene != null)) {
        for (final colors in [light, dark]) {
          final png = await IllustrationRenderer(colors).renderScene(
            f.scene!,
            provenance: _l('en').taskExportSceneProvenance,
          );
          expect(pngChunkTypes(png).toSet(), {'IHDR', 'IDAT', 'IEND'});
          expect(readPngHeader(png), (width: 1280, height: 800));
        }
      }
      final slide = await IllustrationRenderer(light).renderTextSlide('Title', [
        'one',
        'two',
      ], preset: IllustrationPreset.portrait);
      expect(readPngHeader(slide), (width: 720, height: 1280));
    });
  });

  testWidgets('a redaction is opaque in the encoded pixels', (tester) async {
    await tester.runAsync(() async {
      final sb = buildStoryboard(
        decodeRecordingText(fixtureText(BookingJourney.planConfirmed.file))
            .recording!,
        _l('en'),
      );
      final scene = sb.frames.firstWhere((f) => f.scene != null).scene!;
      const box = NormalizedRect(0, 0, 0.5, 0.25);
      final png = await IllustrationRenderer(light).renderScene(
        scene,
        provenance: 'x',
        redactions: const [box],
        preset: IllustrationPreset.thumbnail,
      );
      final (w, h, rgba) = await _decode(png);
      final fill = light.onSurface;
      int channel(double c) => (c * 255).round();
      var inside = 0;
      for (var y = 0; y < (h * 0.25).floor(); y++) {
        for (var x = 0; x < (w * 0.5).floor(); x++) {
          final o = (y * w + x) * 4;
          expect(
            [
              rgba.getUint8(o),
              rgba.getUint8(o + 1),
              rgba.getUint8(o + 2),
              rgba.getUint8(o + 3),
            ],
            [channel(fill.r), channel(fill.g), channel(fill.b), 255],
            reason: 'pixel $x,$y',
          );
          inside++;
        }
      }
      expect(inside, greaterThan(1000));
      // The unredacted picture differs there: something was covered.
      final plain = await IllustrationRenderer(light).renderScene(
        scene,
        provenance: 'x',
        preset: IllustrationPreset.thumbnail,
      );
      expect(plain, isNot(png));
    });
  });

  testWidgets('canaries at capture leave the pixels unchanged', (tester) async {
    await tester.runAsync(() async {
      for (final j in BookingJourney.values) {
        final recorded = await recordFixture(j);
        final live = buildStoryboard(recorded.recording, _l('fr'));
        final committed = buildStoryboard(
          decodeRecordingText(fixtureText(j.file)).recording!,
          _l('fr'),
        );
        final renderer = IllustrationRenderer(light);
        for (var i = 0; i < live.frames.length; i++) {
          final scene = live.frames[i].scene;
          if (scene == null) continue;
          final a = await renderer.renderScene(
            scene,
            provenance: 'p',
            preset: IllustrationPreset.thumbnail,
          );
          final b = await renderer.renderScene(
            committed.frames[i].scene!,
            provenance: 'p',
            preset: IllustrationPreset.thumbnail,
          );
          expect(a, b, reason: '${j.file} frame $i');
          final text = String.fromCharCodes(a).toLowerCase();
          for (final c in canaryFragments) {
            expect(text.contains(c.toLowerCase()), isFalse);
          }
        }
      }
    });
  });
}
