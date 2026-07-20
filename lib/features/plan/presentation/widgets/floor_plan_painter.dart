// SPDX-License-Identifier: MIT
import 'dart:ui' as ui;

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
    this.background,
    this.images = const {},
    this.seatStates,
    this.seatLabels,
    this.highlightedSeatId,
    this.deskOpacity = 1,
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

  /// Optional background image (0036): a photo/blueprint of the real
  /// space, painted behind the grid at reduced opacity so seats stay
  /// legible on top. Null = schematic only.
  final ui.Image? background;

  /// Illustration images (0037): image id → decoded bitmap, drawn at the
  /// element's grid rect above the background and below the schematic.
  final Map<String, ui.Image> images;

  /// Live mode: seat id → state. Null = editor mode (uniform styling).
  final Map<String, SeatState>? seatStates;

  /// Live mode: seat id → occupant display name (empty = no label).
  final Map<String, String>? seatLabels;

  /// Seat to ring with a thick tertiary outline (#182): the calendar's
  /// "Show on plan" jump points at the reserved seat. Null = no highlight.
  final String? highlightedSeatId;

  /// Desk fill opacity 0..1 (0040): 1 = solid (default); lower makes desks
  /// translucent so a background photo shows through. The desk border stays
  /// opaque so the table is still locatable over the image.
  final double deskOpacity;

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
    final bg = background;
    if (bg != null) {
      // Contain-fit the photo within the plan bounds, centred, dimmed so
      // the seat/desk graphics on top stay readable.
      final src = Rect.fromLTWH(
          0, 0, bg.width.toDouble(), bg.height.toDouble());
      final scale =
          (size.width / bg.width).clamp(0.0, size.height / bg.height);
      final w = bg.width * scale;
      final h = bg.height * scale;
      final dst = Rect.fromLTWH(
          (size.width - w) / 2, (size.height - h) / 2, w, h);
      canvas.drawImageRect(
        bg,
        src,
        dst,
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }
    for (final image in plan.images) {
      final img = images[image.id];
      if (img == null) continue;
      final dst = _toPx(image.rect);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

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

    // Desks: soft rounded tonal surfaces — the furniture the room is
    // built from, not flat grey boxes. A hairline border and a whisper
    // of a contact shadow give the plan gentle depth.
    // Configurable desk transparency (0040): fade the fill (and its contact
    // shadow) by deskOpacity, but keep the border opaque so a translucent
    // desk stays locatable over a background photo.
    final deskAlpha = deskOpacity.clamp(0.0, 1.0);
    final deskPaint = Paint()
      ..color = colorScheme.surfaceContainerHigh.withValues(alpha: deskAlpha);
    final deskBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorScheme.outlineVariant;
    final deskShadowAlpha =
        (brightness == Brightness.dark ? 0.28 : 0.10) * deskAlpha;
    for (final desk in plan.desks) {
      final rect = _toPx(desk.rect).deflate(1.5);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
      _softShadow(canvas, rrect, alpha: deskShadowAlpha);
      canvas.drawRRect(rrect, deskPaint);
      canvas.drawRRect(rrect, deskBorder);
    }

    for (final seat in plan.seats) {
      final rect = _toPx(seat.footprint).deflate(3);
      final state = seatStates?[seat.id];
      final accent = state == null
          ? colorScheme.primary
          : SeatStateColors.of(state, brightness: brightness);
      // Radius scales with the tile so a seat always reads as a soft,
      // rounded pad — the signature "living plan" tile.
      final radius = (rect.shortestSide * 0.24).clamp(4.0, 10.0);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

      _softShadow(canvas, rrect,
          alpha: brightness == Brightness.dark ? 0.30 : 0.12);
      // Calm tint fill: free stays airy, taken seats read a touch fuller.
      // Over a background photo the zone must still read as a status
      // colour without hiding the image — a modest bump, never opaque.
      final overPhoto = background != null;
      final fillAlpha = switch (state) {
        null => overPhoto ? 0.24 : 0.16,
        SeatState.free => overPhoto ? 0.20 : 0.14,
        SeatState.blocked => overPhoto ? 0.24 : 0.10,
        _ => overPhoto ? 0.40 : 0.22,
      };
      canvas.drawRRect(rrect, Paint()..color = accent.withValues(alpha: fillAlpha));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = state == SeatState.mine ? 2 : 1.3
          ..color = accent.withValues(alpha: 0.9),
      );
      if (seat.id == highlightedSeatId) {
        // #182: ring around the focused seat; tertiary so it stands out
        // against both the primary editor accent and the state colors.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.inflate(3), Radius.circular(radius + 3)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = colorScheme.tertiary,
        );
      }

      // State never conveyed by colour alone (spec §11).
      if (state == SeatState.blocked) {
        _label(canvas, '✕', rect, accent, center: true);
        continue;
      }
      final label = seatLabels?[seat.id] ?? '';
      if (state != null && label.isNotEmpty) {
        // Live occupancy: the occupant becomes an avatar right on the
        // seat — one glance answers "who's here". This is the plan's
        // signature move.
        _occupantAvatar(canvas, rect, label, accent);
      } else if (state == null) {
        // Editor mode: name + orientation so the owner can place seats.
        _orientationArrow(canvas, seat, rect, accent);
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

  /// A soft blurred contact shadow under [rrect] — the depth cue that
  /// makes seats and desks read as gently lifted, not stamped flat.
  void _softShadow(Canvas canvas, RRect rrect, {required double alpha}) {
    canvas.drawRRect(
      rrect.shift(const Offset(0, 1.5)),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  /// Occupant chip drawn on a taken seat: a filled disc in the state
  /// colour with the occupant's initial — the plan's "who's here" glance.
  void _occupantAvatar(Canvas canvas, Rect rect, String name, Color accent) {
    final r = (rect.shortestSide * 0.34).clamp(8.0, 16.0);
    final center = rect.center;
    canvas.drawCircle(center, r, Paint()..color = accent);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    final painter = TextPainter(
      text: TextSpan(
        text: initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 1.05,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
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
      oldDelegate.background != background ||
      oldDelegate.images != images ||
      oldDelegate.marquee != marquee ||
      oldDelegate.marqueeValid != marqueeValid ||
      oldDelegate.selection != selection ||
      oldDelegate.selectionResizable != selectionResizable ||
      oldDelegate.selectionValid != selectionValid ||
      oldDelegate.seatStates != seatStates ||
      oldDelegate.seatLabels != seatLabels ||
      oldDelegate.highlightedSeatId != highlightedSeatId ||
      oldDelegate.deskOpacity != deskOpacity ||
      oldDelegate.cellSize != cellSize;
}
