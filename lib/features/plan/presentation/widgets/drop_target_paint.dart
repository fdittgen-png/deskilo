// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../domain/floor_plan.dart';
import '../../domain/grid_geometry.dart';

/// #1216 — dim everything that is not a legal parent for the editor's
/// armed tool, and ring what is.
///
/// The rules were enforced all along and only ever spoken AFTER a
/// failed drag, as *"Must be fully inside an office."* in a snackbar.
/// The editor can answer before the gesture, so it does.
///
/// [targets] null means no tool is armed and nothing is dimmed. EMPTY
/// is a different answer and a meaningful one: a tool IS armed and
/// there is nowhere legal to put it, so the whole floor dims and the
/// reader learns that without spending a drag on it.
///
/// Painted over the plan and under the marquee, so the rectangle being
/// dragged stays the brightest thing on the canvas.
void paintDropTargets({
  required Canvas canvas,
  required Size size,
  required FloorPlan plan,
  required Set<String>? targets,
  required double cellSize,
  required ColorScheme colorScheme,
}) {
  if (targets == null) return;
  Rect toPx(GridRect r) => Rect.fromLTWH(
        r.x * cellSize,
        r.y * cellSize,
        r.w * cellSize,
        r.h * cellSize,
      );
  final legal = <Rect>[
    for (final office in plan.offices)
      if (targets.contains(office.id)) toPx(office.rect),
    for (final desk in plan.desks)
      if (targets.contains(desk.id)) toPx(desk.rect),
  ];
  // One even-odd path: the whole canvas minus the legal rectangles, so
  // the wash never darkens a target and never double-darkens an
  // overlap.
  final veil = Path()..addRect(Offset.zero & size);
  for (final rect in legal) {
    veil.addRect(rect);
  }
  veil.fillType = PathFillType.evenOdd;
  canvas.drawPath(
    veil,
    Paint()..color = colorScheme.surface.withValues(alpha: 0.62),
  );
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..color = colorScheme.primary;
  for (final rect in legal) {
    canvas.drawRect(rect.deflate(1), ring);
  }
}
