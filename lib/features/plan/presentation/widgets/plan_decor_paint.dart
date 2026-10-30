// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3074 — the vector glyphs of the plan's drawn symbols: the walls, doors
// and furniture of the real room. Each is a function of the footprint it is
// given and the colour scheme; a turned symbol is drawn in its own frame and
// rotated about the footprint's centre.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/plan_image.dart';

/// Paints [kind] into [footprint], turned [quarterTurns] clockwise. The
/// footprint is the symbol's visible rectangle: an odd turn swaps the frame
/// it is drawn in.
void paintPlanDecor(
  Canvas canvas,
  Rect footprint,
  PlanDecorKind kind,
  int quarterTurns,
  ColorScheme scheme,
) {
  final odd = quarterTurns.isOdd;
  final frame = Rect.fromCenter(
    center: Offset.zero,
    width: odd ? footprint.height : footprint.width,
    height: odd ? footprint.width : footprint.height,
  );
  canvas
    ..save()
    ..translate(footprint.center.dx, footprint.center.dy)
    ..rotate(quarterTurns * math.pi / 2);
  _glyph(canvas, frame, kind, scheme);
  canvas.restore();
}

void _glyph(Canvas canvas, Rect r, PlanDecorKind kind, ColorScheme scheme) {
  final ink = scheme.onSurfaceVariant;
  final fill = Paint()..color = ink.withValues(alpha: 0.85);
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = ink;
  final soft = Paint()..color = scheme.surfaceContainerHighest;
  RRect round(Rect b, double radius) =>
      RRect.fromRectAndRadius(b, Radius.circular(radius));
  switch (kind) {
    case PlanDecorKind.wall:
      canvas.drawRect(r, fill);
    case PlanDecorKind.window:
      canvas
        ..drawRect(r, soft)
        ..drawRect(r, line)
        ..drawLine(
          Offset(r.left, r.center.dy),
          Offset(r.right, r.center.dy),
          line,
        );
    case PlanDecorKind.door:
      // The leaf along the left edge, the swing as a quarter circle.
      final radius = math.min(r.width, r.height);
      final hinge = r.bottomLeft;
      canvas
        ..drawLine(hinge, Offset(hinge.dx, hinge.dy - radius), line)
        ..drawArc(
          Rect.fromCircle(center: hinge, radius: radius),
          -math.pi / 2,
          math.pi / 2,
          false,
          line..strokeWidth = 1,
        );
    case PlanDecorKind.pillar:
      final d = math.min(r.width, r.height);
      canvas
        ..drawCircle(r.center, d / 2, soft)
        ..drawCircle(r.center, d / 2, line)
        ..drawLine(r.center.translate(-d / 3, -d / 3),
            r.center.translate(d / 3, d / 3), line)
        ..drawLine(r.center.translate(d / 3, -d / 3),
            r.center.translate(-d / 3, d / 3), line);
    case PlanDecorKind.table:
      final top = r.deflate(math.min(r.width, r.height) * 0.18);
      canvas
        ..drawRRect(round(top, 4), soft)
        ..drawRRect(round(top, 4), line);
      // A chair stub at each end of the long side.
      final stub = math.min(r.width, r.height) * 0.16;
      for (var i = 1; i <= 2; i++) {
        final x = top.left + top.width * i / 3;
        canvas
          ..drawRect(Rect.fromLTWH(x - stub, r.top, stub * 2, stub), line)
          ..drawRect(Rect.fromLTWH(x - stub, r.bottom - stub, stub * 2, stub), line);
      }
    case PlanDecorKind.couch:
      final back = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.3);
      canvas
        ..drawRRect(round(r, 6), soft)
        ..drawRRect(round(r, 6), line)
        ..drawRRect(round(back, 4), fill);
    case PlanDecorKind.wc:
      final bowl = Rect.fromCenter(
        center: r.center.translate(0, r.height * 0.12),
        width: r.width * 0.55,
        height: r.height * 0.6,
      );
      final tank = Rect.fromLTWH(
          r.center.dx - r.width * 0.3, r.top, r.width * 0.6, r.height * 0.22);
      canvas
        ..drawOval(bowl, soft)
        ..drawOval(bowl, line)
        ..drawRRect(round(tank, 3), soft)
        ..drawRRect(round(tank, 3), line);
    case PlanDecorKind.kitchen:
      canvas
        ..drawRRect(round(r, 4), soft)
        ..drawRRect(round(r, 4), line);
      final hob = math.min(r.width / 6, r.height / 3);
      for (final dx in [-1.5, 1.5]) {
        for (final dy in [-1.0, 1.0]) {
          canvas.drawCircle(
            r.center.translate(dx * hob * 1.4, dy * hob * 0.9),
            hob * 0.55,
            line,
          );
        }
      }
  }
}
