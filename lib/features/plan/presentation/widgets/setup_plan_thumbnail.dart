// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2870 — a level's plan, read-only, cut to the part of the grid it uses
// and drawn by the painter the app shows every plan with (the PNG export's
// cut, on screen). No gestures: on a phone the step page scrolls, and a
// zoomable canvas inside it would take the scroll.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/floor_plan.dart';
import 'floor_plan_painter.dart';

class SetupPlanThumbnail extends StatelessWidget {
  const SetupPlanThumbnail({
    super.key,
    required this.plan,
    required this.levelName,
  });

  /// The tallest the thumbnail grows.
  static const double maxHeight = 180;

  final FloorPlan plan;
  final String levelName;

  @override
  Widget build(BuildContext context) {
    final bounds = plan.usedBounds;
    if (bounds == null || bounds.w <= 0 || bounds.h <= 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Semantics(
      image: true,
      label: context.l10n.setupPlacesPlanLabel(levelName),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: maxHeight),
        child: AspectRatio(
          aspectRatio: bounds.w / bounds.h,
          child: CustomPaint(
            key: const ValueKey('setup-plan-thumbnail'),
            painter: _CutPlanPainter(
              plan: plan,
              colors: theme.colorScheme,
              brightness: theme.brightness,
            ),
          ),
        ),
      ),
    );
  }
}

/// [FloorPlanPainter], translated so the plan's used bounds fill the box.
class _CutPlanPainter extends CustomPainter {
  _CutPlanPainter({
    required this.plan,
    required this.colors,
    required this.brightness,
  });

  final FloorPlan plan;
  final ColorScheme colors;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = plan.usedBounds;
    if (bounds == null || bounds.w <= 0) return;
    final cell = size.width / bounds.w;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(-bounds.x * cell, -bounds.y * cell);
    FloorPlanPainter(
      plan: plan,
      cellSize: cell,
      colorScheme: colors,
      brightness: brightness,
    ).paint(
      canvas,
      Size((bounds.x + bounds.w) * cell, (bounds.y + bounds.h) * cell),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CutPlanPainter old) =>
      old.plan != plan || old.colors != colors || old.brightness != brightness;
}
