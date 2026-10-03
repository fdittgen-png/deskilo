// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — illustrations are DRAWN, off-screen, from the safe model.
//
// Nothing here captures the screen or a widget: there is no
// RenderRepaintBoundary, no layer, no platform view. A PictureRecorder
// receives only what the SafeScene (or a text slide's safe strings)
// describes, the picture becomes an image with Picture.toImage, and the
// encoded PNG goes through stripPngMetadata. Redactions are painted
// LAST, opaque, onto the same canvas, so the encoded pixels under them
// are the fill colour — there is no hidden original underneath, no
// layer to remove. Every native image is disposed before returning.
// Colours come from the app theme's ColorScheme, light or dark.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'png_safety.dart';
import 'safe_scene.dart';
import 'storyboard.dart';

/// The fixed illustration sizes. Bounded: nothing larger is drawn.
enum IllustrationPreset {
  landscape(1280, 800),
  portrait(720, 1280),
  thumbnail(480, 300);

  const IllustrationPreset(this.width, this.height);
  final int width;
  final int height;
}

/// Draws scenes and text slides into metadata-free PNG bytes.
class IllustrationRenderer {
  const IllustrationRenderer(this.colors);

  final ColorScheme colors;

  /// A recreated scene, labelled with [provenance] in the corner.
  Future<Uint8List> renderScene(
    SafeScene scene, {
    required String provenance,
    List<NormalizedRect> redactions = const [],
    IllustrationPreset preset = IllustrationPreset.landscape,
  }) => _render(
    preset,
    (canvas, size) => paintScene(
      canvas,
      size,
      scene,
      provenance: provenance,
      redactions: redactions,
    ),
  );

  /// A slide of safe text: a title and a few lines.
  Future<Uint8List> renderTextSlide(
    String title,
    List<String> lines, {
    IllustrationPreset preset = IllustrationPreset.landscape,
  }) => _render(
    preset,
    (canvas, size) => paintTextSlide(canvas, size, title, lines),
  );

  /// Paints [scene] into a [size] box at the canvas origin. Redactions
  /// are painted last, opaque, so nothing under them reaches a raster.
  /// The video composer paints frames through this same method.
  void paintScene(
    Canvas canvas,
    Size size,
    SafeScene scene, {
    required String provenance,
    List<NormalizedRect> redactions = const [],
  }) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.surface);
    _paintScene(canvas, size, scene);
    _text(
      canvas,
      provenance,
      Offset(size.width * 0.02, size.height * 0.955),
      size.width * 0.96,
      size.height * 0.03,
      colors.onSurfaceVariant,
      align: TextAlign.right,
    );
    final cover = Paint()
      ..color = colors.onSurface
      ..isAntiAlias = false;
    for (final r in redactions) {
      canvas.drawRect(_rect(r, size), cover);
    }
    canvas.restore();
  }

  /// Paints a text slide into a [size] box at the canvas origin.
  void paintTextSlide(
    Canvas canvas,
    Size size,
    String title,
    List<String> lines,
  ) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = colors.surfaceContainerHighest,
    );
    final w = size.width * 0.84;
    var y = size.height * 0.2;
    y += _text(
      canvas,
      title,
      Offset(size.width * 0.08, y),
      w,
      size.height * 0.07,
      colors.onSurface,
      bold: true,
    );
    y += size.height * 0.04;
    for (final line in lines.take(6)) {
      y += _text(
        canvas,
        line,
        Offset(size.width * 0.08, y),
        w,
        size.height * 0.045,
        colors.onSurfaceVariant,
      );
      y += size.height * 0.02;
    }
    canvas.restore();
  }

  Future<Uint8List> _render(
    IllustrationPreset preset,
    void Function(Canvas, Size) paint,
  ) async {
    final size = Size(preset.width.toDouble(), preset.height.toDouble());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    paint(canvas, size);
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(preset.width, preset.height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const PngRejected('encode');
      return stripPngMetadata(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image?.dispose();
      picture.dispose();
    }
  }

  Rect _rect(NormalizedRect r, Size size) => Rect.fromLTWH(
    (r.left * size.width).floorToDouble(),
    (r.top * size.height).floorToDouble(),
    (r.width * size.width).ceilToDouble(),
    (r.height * size.height).ceilToDouble(),
  );

  void _paintScene(Canvas canvas, Size size, SafeScene scene) {
    if (scene.screen == SceneScreen.bookingSheet) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = colors.scrim.withValues(alpha: 0.32),
      );
    }
    for (final e in scene.elements) {
      final rect = _rect(e.rect, size);
      final radius = Radius.circular(
        math.min(rect.shortestSide * 0.18, size.shortestSide * 0.04),
      );
      final (fill, ink) = switch (e.kind) {
        SceneElementKind.appBar => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
        ),
        SceneElementKind.sheet => (colors.surface, colors.onSurface),
        SceneElementKind.button when e.selected => (
          colors.primary,
          colors.onPrimary,
        ),
        _ when e.selected => (
          colors.secondaryContainer,
          colors.onSecondaryContainer,
        ),
        _ => (colors.surfaceContainerHigh, colors.onSurface),
      };
      final shape = e.kind == SceneElementKind.appBar
          ? RRect.fromRectAndRadius(rect, Radius.zero)
          : RRect.fromRectAndRadius(rect, radius);
      canvas.drawRRect(shape, Paint()..color = fill);
      if (e.kind != SceneElementKind.appBar &&
          e.kind != SceneElementKind.sheet) {
        canvas.drawRRect(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = colors.outlineVariant,
        );
      }
      final boxed =
          e.kind == SceneElementKind.sheet || e.kind == SceneElementKind.card;
      final pad = boxed ? size.shortestSide * 0.03 : rect.height * 0.22;
      final textHeight = switch (e.kind) {
        SceneElementKind.sheet => size.height * 0.05,
        SceneElementKind.card => size.height * 0.05,
        _ => rect.height * 0.45,
      };
      final top =
          e.kind == SceneElementKind.sheet || e.kind == SceneElementKind.card
          ? rect.top + pad
          : rect.center.dy - textHeight * 0.6;
      if (e.value.isEmpty) {
        _text(
          canvas,
          e.label,
          Offset(rect.left + pad, top),
          rect.width - 2 * pad,
          textHeight,
          ink,
          bold: e.kind == SceneElementKind.appBar,
          align:
              e.kind == SceneElementKind.chip ||
                  e.kind == SceneElementKind.segment ||
                  e.kind == SceneElementKind.button ||
                  e.kind == SceneElementKind.desk
              ? TextAlign.center
              : TextAlign.left,
        );
      } else if (e.kind == SceneElementKind.card) {
        final used = _text(
          canvas,
          e.label,
          Offset(rect.left + pad, top),
          rect.width - 2 * pad,
          textHeight,
          ink,
          bold: true,
        );
        _text(
          canvas,
          e.value,
          Offset(rect.left + pad, top + used + pad),
          rect.width - 2 * pad,
          textHeight * 0.8,
          ink,
        );
      } else {
        _text(
          canvas,
          e.label,
          Offset(rect.left + pad, top),
          rect.width * 0.5 - pad,
          textHeight,
          ink,
        );
        _text(
          canvas,
          e.value,
          Offset(rect.left + rect.width * 0.5, top),
          rect.width * 0.5 - pad,
          textHeight,
          ink,
          align: TextAlign.right,
        );
      }
      if (e.highlighted) {
        // A steady outline, never a flash: the same in every frame.
        canvas.drawRRect(
          shape.inflate(size.shortestSide * 0.012),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.shortestSide * 0.012
            ..color = colors.tertiary,
        );
      }
    }
  }

  /// Draws [text] in one bounded line box; returns the height used.
  double _text(
    Canvas canvas,
    String text,
    Offset at,
    double width,
    double height,
    Color color, {
    bool bold = false,
    TextAlign align = TextAlign.left,
  }) {
    if (text.isEmpty || width <= 0) return 0;
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: align,
              maxLines: 3,
              ellipsis: '…',
              fontSize: height * 0.8,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          )
          ..pushStyle(ui.TextStyle(color: color))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: width));
    canvas.drawParagraph(paragraph, at);
    final used = paragraph.height;
    paragraph.dispose();
    return used;
  }
}
