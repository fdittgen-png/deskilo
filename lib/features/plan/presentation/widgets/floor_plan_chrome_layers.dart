// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The floor plan's layers that are not furniture (#2494): the backdrop (the
// photo, the illustrations, the grid), the highlight rings of a "Show on
// plan" jump, the editor's selection and marquee. Each is a function of the
// painter's inputs; none holds state.
import 'package:flutter/material.dart';

import '../../domain/grid_geometry.dart';
import 'drop_target_paint.dart';
import 'floor_plan_painter.dart';
import 'plan_paint_helpers.dart';

/// Background photo (0036), illustration images (0037) and the grid.
void paintFloorPlanBackdrop(Canvas canvas, Size size, FloorPlanPainter p) {
  _paintBackgroundPhoto(canvas, size, p);
  _paintIllustrations(canvas, p);
  final gridPaint = Paint()
    ..color = p.colorScheme.outlineVariant.withValues(alpha: 0.35)
    ..strokeWidth = 0.5;
  for (var x = 0.0; x <= size.width; x += p.cellSize) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
  }
  for (var y = 0.0; y <= size.height; y += p.cellSize) {
    canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
  }
}

void _paintBackgroundPhoto(Canvas canvas, Size size, FloorPlanPainter p) {
  final bg = p.background;
  if (bg == null) return;
  // Contain-fit the photo within the plan bounds, centred, dimmed so the
  // seat/desk graphics on top stay readable.
  final src = Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble());
  final scale = (size.width / bg.width).clamp(0.0, size.height / bg.height);
  final w = bg.width * scale;
  final h = bg.height * scale;
  final dst =
      Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  canvas.drawImageRect(
    bg,
    src,
    dst,
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

void _paintIllustrations(Canvas canvas, FloorPlanPainter p) {
  for (final image in p.plan.images) {
    final img = p.images[image.id];
    if (img == null) continue;
    final dst = gridRectToPx(image.rect, p.cellSize);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }
}

/// #576 — the space highlight rings, on top of everything painted.
void paintFloorPlanHighlights(Canvas canvas, Size size, FloorPlanPainter p) {
  Paint spaceRing() => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = p.colorScheme.tertiary;
  final plan = p.plan;
  if (p.highlightedDeskId != null) {
    final desk =
        plan.desks.where((d) => d.id == p.highlightedDeskId).firstOrNull;
    if (desk != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            gridRectToPx(desk.rect, p.cellSize).inflate(3),
            const Radius.circular(8)),
        spaceRing(),
      );
    }
  }
  if (p.highlightedOfficeId != null) {
    final office =
        plan.offices.where((o) => o.id == p.highlightedOfficeId).firstOrNull;
    if (office != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            gridRectToPx(office.rect, p.cellSize).inflate(3),
            const Radius.circular(10)),
        spaceRing(),
      );
    }
  }
  if (p.highlightLevel) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(2), const Radius.circular(12)),
      spaceRing(),
    );
  }
}

/// The editor's selection (#101) with its resize handles, the legal-drop
/// wash (#1216) and the in-progress marquee.
void paintFloorPlanEditorMarks(Canvas canvas, Size size, FloorPlanPainter p) {
  final sel = p.selection;
  if (sel != null) _paintSelection(canvas, p, sel);
  // #1216 — the editor's only mark on this canvas: where the armed tool may
  // legally place its next element.
  paintDropTargets(
    canvas: canvas,
    size: size,
    plan: p.plan,
    targets: p.dropTargets,
    cellSize: p.cellSize,
    colorScheme: p.colorScheme,
  );
  final m = p.marquee;
  if (m == null) return;
  final rect = gridRectToPx(m, p.cellSize);
  final color = p.marqueeValid ? p.colorScheme.primary : p.colorScheme.error;
  canvas
    ..drawRect(rect, Paint()..color = color.withValues(alpha: 0.2))
    ..drawRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
}

void _paintSelection(Canvas canvas, FloorPlanPainter p, GridRect sel) {
  final rect = gridRectToPx(sel, p.cellSize);
  final color = p.selectionValid ? p.colorScheme.primary : p.colorScheme.error;
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color,
  );
  if (!p.selectionResizable) return;
  final handlePaint = Paint()..color = color;
  for (final point in [
    rect.topLeft,
    rect.topCenter,
    rect.topRight,
    rect.centerLeft,
    rect.centerRight,
    rect.bottomLeft,
    rect.bottomCenter,
    rect.bottomRight,
  ]) {
    canvas.drawRect(
      Rect.fromCenter(center: point, width: 8, height: 8),
      handlePaint,
    );
  }
}
