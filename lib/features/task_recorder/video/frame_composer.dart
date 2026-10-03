// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — every video frame is drawn, off-screen, from a timeline cue.
//
// A frame is the cue's heading band at the top, then either the frame's
// APPROVED recreated scene (drawn by the storyboard's own renderer, with
// its redactions) or a text slide of the cue's safe lines, and an empty
// band at the bottom where a player shows the optional caption track, so
// the burned-in text and the captions never cover each other. Nothing
// is captured from the screen; a frame cannot show anything the cue
// does not hold. The same pictures serve the preview and the encoder.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../storyboard/illustration_renderer.dart';
import 'video_timeline.dart';

/// Draws timeline cues into frames.
class FrameComposer {
  FrameComposer(this.colors, this.preset, {required this.provenance})
    : _renderer = IllustrationRenderer(colors);

  final ColorScheme colors;
  final VideoPreset preset;

  /// The label every recreated illustration carries.
  final String provenance;
  final IllustrationRenderer _renderer;

  Size get size => Size(preset.width.toDouble(), preset.height.toDouble());

  /// The cue as a picture. The caller disposes it.
  ui.Picture picture(TimelineCue cue) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    final s = size;
    canvas.drawRect(Offset.zero & s, Paint()..color = colors.surface);
    final band = s.height * (preset == VideoPreset.portrait ? 0.1 : 0.13);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s.width, band),
      Paint()..color = colors.primaryContainer,
    );
    _line(
      canvas,
      cue.heading,
      Rect.fromLTWH(s.width * 0.04, band * 0.18, s.width * 0.92, band * 0.7),
      colors.onPrimaryContainer,
    );
    // The body: above the bottom band a player's captions use.
    final bottom = s.height * 0.86;
    final body = Rect.fromLTWH(
      s.width * 0.04,
      band + s.height * 0.03,
      s.width * 0.92,
      bottom - band - s.height * 0.03,
    );
    final frame = cue.frame;
    final scene = frame?.scene;
    canvas.save();
    if (frame != null && frame.approved && scene != null) {
      final fit = _fit(body, 1280 / 800);
      canvas.translate(fit.left, fit.top);
      _renderer.paintScene(
        canvas,
        fit.size,
        scene,
        provenance: provenance,
        redactions: frame.redactions,
      );
    } else {
      canvas.translate(body.left, body.top);
      _renderer.paintTextSlide(
        canvas,
        body.size,
        cue.kind == CueKind.step ? frame?.title ?? cue.heading : cue.heading,
        cue.lines,
      );
    }
    canvas.restore();
    return recorder.endRecording();
  }

  /// [current] over [previous] at [alpha] (0..1), as RGBA bytes.
  Future<Uint8List> rgba(
    ui.Picture current, {
    ui.Picture? previous,
    double alpha = 1,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    if (previous != null && alpha < 1) {
      canvas
        ..drawPicture(previous)
        ..saveLayer(
          Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0, 1)),
        )
        ..drawPicture(current)
        ..restore();
    } else {
      canvas.drawPicture(current);
    }
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(preset.width, preset.height);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('frame not drawn');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  Rect _fit(Rect box, double aspect) {
    final w = box.width / box.height > aspect ? box.height * aspect : box.width;
    final h = w / aspect;
    return Rect.fromLTWH(
      box.left + (box.width - w) / 2,
      box.top + (box.height - h) / 2,
      w,
      h,
    );
  }

  void _line(Canvas canvas, String text, Rect box, Color color) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              maxLines: 2,
              ellipsis: '…',
              fontSize: box.height * 0.36,
              fontWeight: FontWeight.w700,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: box.width));
    canvas.drawParagraph(
      paragraph,
      Offset(box.left, box.top + (box.height - paragraph.height) / 2),
    );
    paragraph.dispose();
  }
}
