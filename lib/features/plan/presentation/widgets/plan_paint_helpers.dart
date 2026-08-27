// SPDX-License-Identifier: 0BSD
//
// The floor plan's decoration primitives, lifted out of the painter when
// it outgrew its length budget (#670). Every one of these is PURE — a
// canvas, a rect, some colours in; pixels out — with no dependency on
// the painter's state, which is why they can live here at all and why
// they are top-level functions rather than methods.
//
// Keeping them together makes the plan's visual vocabulary readable in
// one place: how a room is labelled, how an occupant is chipped, how a
// whole-space booking is hatched.
import 'package:flutter/material.dart';

void drawLabel(
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
void drawSoftShadow(Canvas canvas, RRect rrect, {required double alpha}) {
  canvas.drawRRect(
    rrect.shift(const Offset(0, 1.5)),
    Paint()
      ..color = const Color(0xFF000000).withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
  );
}

/// Occupant chip drawn on a taken seat: a filled disc in the state
/// colour with the occupant's initial — the plan's "who's here" glance.
/// Unmistakable "reserved" symbol on a whole-space (#464, asked
/// repeatedly in the field): a solid state-coloured chip with a lock
/// glyph and the occupant's first name, centered on the room/table.
/// Every user reads at a glance WHAT is reserved and BY WHOM.
/// #670 — diagonal hatching over a WHOLE-SPACE reservation.
///
/// A booked room already got a coloured wash and a border, but the
/// seats inside tint too — so a table whose six seats happen to be
/// individually booked looked exactly like a table booked as ONE
/// whole-table reservation. Field report: "reservations for a floor,
/// room or table are not identifiable as such".
///
/// Hatching says it without colour: nothing else on this canvas is
/// striped, so the pattern reads as "this SPACE is taken as a unit"
/// at a glance, and it survives dark mode, a background photo, and
/// colour-blindness — none of which a hue can promise.
void drawHatch(Canvas canvas, Rect rect, Color accent) {
  canvas.save();
  canvas.clipRect(rect);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = accent.withValues(alpha: 0.30);
  // 10px pitch at plan scale: dense enough to read as a texture,
  // sparse enough not to bury the room's own label or the seats.
  const pitch = 10.0;
  for (var x = rect.left - rect.height; x < rect.right; x += pitch) {
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(x + rect.height, rect.top),
      paint,
    );
  }
  canvas.restore();
}

void drawReservedChip(
  Canvas canvas,
  Rect rect,
  String name,
  Color accent, {
  required bool checkedIn,
}) {
  final icon = checkedIn ? Icons.how_to_reg : Icons.lock;
  final fontSize = (rect.shortestSide * 0.28).clamp(11.0, 15.0);
  final iconPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize + 2,
        fontFamily: icon.fontFamily,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final textPainter = TextPainter(
    text: TextSpan(
      text: name.trim(),
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: (rect.width - iconPainter.width - 26).clamp(0.0, double.infinity));
  const gap = 5.0;
  final w = iconPainter.width +
      (textPainter.width > 0 ? gap + textPainter.width : 0) +
      16;
  final h = iconPainter.height + 10;
  final center = rect.center;
  final chip = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: w, height: h),
    Radius.circular(h / 2),
  );
  canvas.drawRRect(
    chip.inflate(1.2),
    Paint()..color = Colors.white.withValues(alpha: 0.9),
  );
  canvas.drawRRect(chip, Paint()..color = accent);
  var x = center.dx - (w - 16) / 2;
  iconPainter.paint(
      canvas, Offset(x, center.dy - iconPainter.height / 2));
  x += iconPainter.width + gap;
  if (textPainter.width > 0) {
    textPainter.paint(
        canvas, Offset(x, center.dy - textPainter.height / 2));
  }
}
