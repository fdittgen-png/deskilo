// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../core/theme/office_colors.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/grid_geometry.dart';
import '../../../plan/domain/seat.dart';

/// Paints a level's grid, offices, desks and seats. Shared by the editor
/// canvas (#34/#35) and later the live floor plan (Epic #4).
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({
    required this.plan,
    required this.cellSize,
    required this.colorScheme,
    this.marquee,
    this.marqueeValid = true,
  });

  final FloorPlan plan;
  final double cellSize;
  final ColorScheme colorScheme;

  /// In-progress drag rectangle (grid cells) while drawing a new element.
  final GridRect? marquee;
  final bool marqueeValid;

  Rect _toPx(GridRect r) => Rect.fromLTWH(
        r.x * cellSize,
        r.y * cellSize,
        r.w * cellSize,
        r.h * cellSize,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final officeBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colorScheme.outline;
    for (final office in plan.offices) {
      final rect = _toPx(office.rect);
      canvas.drawRect(
        rect,
        Paint()..color = OfficeColors.of(office.color).withValues(alpha: 0.55),
      );
      canvas.drawRect(rect, officeBorder);
      _label(canvas, office.name, rect, colorScheme.onSurface);
    }

    final deskPaint = Paint()..color = colorScheme.surfaceContainerHighest;
    final deskBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colorScheme.onSurfaceVariant;
    for (final desk in plan.desks) {
      final rect = _toPx(desk.rect).deflate(1);
      canvas.drawRect(rect, deskPaint);
      canvas.drawRect(rect, deskBorder);
    }

    for (final seat in plan.seats) {
      final rect = _toPx(seat.footprint).deflate(2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = colorScheme.primary.withValues(alpha: 0.25),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = colorScheme.primary,
      );
      _orientationArrow(canvas, seat, rect);
    }

    final m = marquee;
    if (m != null) {
      final rect = _toPx(m);
      final color = marqueeValid ? colorScheme.primary : colorScheme.error;
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.2));
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  void _label(Canvas canvas, String text, Rect rect, Color color) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 6);
    painter.paint(canvas, rect.topLeft + const Offset(4, 3));
  }

  void _orientationArrow(Canvas canvas, Seat seat, Rect rect) {
    final center = rect.center;
    const len = 6.0;
    final tip = switch (seat.orientation) {
      SeatOrientation.n => center - const Offset(0, len),
      SeatOrientation.s => center + const Offset(0, len),
      SeatOrientation.e => center + const Offset(len, 0),
      SeatOrientation.w => center - const Offset(len, 0),
    };
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..strokeWidth = 2
        ..color = colorScheme.primary,
    );
    canvas.drawCircle(tip, 2, Paint()..color = colorScheme.primary);
  }

  @override
  bool shouldRepaint(FloorPlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.marquee != marquee ||
      oldDelegate.marqueeValid != marqueeValid ||
      oldDelegate.cellSize != cellSize;
}
