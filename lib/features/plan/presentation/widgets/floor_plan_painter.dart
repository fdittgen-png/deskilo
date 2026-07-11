// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

import '../../../../core/theme/office_colors.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../domain/floor_plan.dart';
import '../../domain/grid_geometry.dart';
import '../../domain/seat.dart';

/// Paints a level's grid, offices, desks and seats. Shared by the editor
/// canvas (#34/#35) and the live floor plan (Epic #4): passing [seatStates]
/// switches seats to live state colors + occupant labels.
class FloorPlanPainter extends CustomPainter {
  FloorPlanPainter({
    required this.plan,
    required this.cellSize,
    required this.colorScheme,
    this.brightness = Brightness.light,
    this.seatStates,
    this.seatLabels,
    this.highlightedSeatId,
    this.marquee,
    this.marqueeValid = true,
    this.selection,
    this.selectionResizable = false,
    this.selectionValid = true,
  });

  final FloorPlan plan;
  final double cellSize;
  final ColorScheme colorScheme;
  final Brightness brightness;

  /// Live mode: seat id → state. Null = editor mode (uniform styling).
  final Map<String, SeatState>? seatStates;

  /// Live mode: seat id → occupant display name (empty = no label).
  final Map<String, String>? seatLabels;

  /// Seat to ring with a thick tertiary outline (#182): the calendar's
  /// "Show on plan" jump points at the reserved seat. Null = no highlight.
  final String? highlightedSeatId;

  /// In-progress drag rectangle (grid cells) while drawing a new element.
  final GridRect? marquee;
  final bool marqueeValid;

  /// Editor selection (#101): highlighted rect, resize handles when the
  /// element kind allows resizing, error tint while a drag breaks rules.
  final GridRect? selection;
  final bool selectionResizable;
  final bool selectionValid;

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
      final state = seatStates?[seat.id];
      final accent = state == null
          ? colorScheme.primary
          : SeatStateColors.of(state, brightness: brightness);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = accent.withValues(alpha: state == null ? 0.25 : 0.45),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = accent,
      );
      if (seat.id == highlightedSeatId) {
        // #182: ring around the focused seat; tertiary so it stands out
        // against both the primary editor accent and the state colors.
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(5)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = colorScheme.tertiary,
        );
      }
      _orientationArrow(canvas, seat, rect, accent);
      // State never conveyed by color alone (spec §11): blocked seats get a
      // cross, occupied/reserved/mine get the occupant label or a dot.
      if (state == SeatState.blocked) {
        _label(canvas, '✕', rect, colorScheme.onSurface, center: true);
      } else {
        final label = seatLabels?[seat.id] ?? '';
        if (label.isNotEmpty) {
          _label(canvas, label, rect, colorScheme.onSurface, center: true);
        }
      }
    }

    final sel = selection;
    if (sel != null) {
      final rect = _toPx(sel);
      final color = selectionValid ? colorScheme.primary : colorScheme.error;
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
      if (selectionResizable) {
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

  void _label(
    Canvas canvas,
    String text,
    Rect rect,
    Color color, {
    bool center = false,
  }) {
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
    final offset = center
        ? rect.center - Offset(painter.width / 2, painter.height / 2 - 8)
        : rect.topLeft + const Offset(4, 3);
    painter.paint(canvas, offset);
  }

  void _orientationArrow(Canvas canvas, Seat seat, Rect rect, Color color) {
    final center = rect.center - const Offset(0, 4);
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
        ..color = color,
    );
    canvas.drawCircle(tip, 2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(FloorPlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.marquee != marquee ||
      oldDelegate.marqueeValid != marqueeValid ||
      oldDelegate.selection != selection ||
      oldDelegate.selectionResizable != selectionResizable ||
      oldDelegate.selectionValid != selectionValid ||
      oldDelegate.seatStates != seatStates ||
      oldDelegate.seatLabels != seatLabels ||
      oldDelegate.highlightedSeatId != highlightedSeatId ||
      oldDelegate.cellSize != cellSize;
}
