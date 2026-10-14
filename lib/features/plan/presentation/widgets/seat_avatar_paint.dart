// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The occupant avatar on a taken seat (#618, #908): the plan's "who is here"
// glance. Pure — a canvas and a description in, pixels out — lifted out of
// the floor-plan painter (#2494).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';

/// What the avatar on one seat says.
class SeatAvatar {
  const SeatAvatar({
    required this.name,
    required this.accent,
    required this.brightness,
    this.photo,
    this.checkedIn = false,
    this.online = false,
    this.shareCount = 0,
  });

  /// The occupant's display name; its initial is drawn without a [photo].
  final String name;

  /// The seat's state colour: the disc and the badges.
  final Color accent;
  final Brightness brightness;

  /// #618 — the member's own face, clipped to the marker circle.
  final ui.Image? photo;

  /// Someone physically checked in: a check badge, bottom-right.
  final bool checkedIn;

  /// Presence: a green dot, top-right.
  final bool online;

  /// #908 — the bookings the seat carries today; a count badge, top-left,
  /// when more than one.
  final int shareCount;

  /// Paints the avatar centred on [rect].
  void paint(Canvas canvas, Rect rect) {
    final r = (rect.shortestSide * 0.34).clamp(8.0, 16.0);
    final center = rect.center;
    if (photo != null) {
      _paintPhoto(canvas, center, r);
    } else {
      _paintInitial(canvas, center, r);
    }
    // Corner badges — a small radius keeps them legible on tiny seats.
    final badgeR = (r * 0.42).clamp(4.0, 7.0);
    final diag = r * 0.72; // offset toward the corner along the 45° diagonal
    if (online) _paintOnline(canvas, center + Offset(diag, -diag), badgeR);
    if (shareCount > 1) {
      _paintShareCount(canvas, center + Offset(-diag, -diag), badgeR);
    }
    if (checkedIn) _paintCheck(canvas, center + Offset(diag, diag), badgeR);
  }

  void _paintPhoto(Canvas canvas, Offset center, double r) {
    final image = photo!;
    // #618 — the member's own face on the seat: the photo clipped to the
    // marker circle; the accent ring keeps the state colour language the
    // initial disc had.
    final side = image.width < image.height ? image.width : image.height;
    final src = Rect.fromCenter(
      center: Offset(image.width / 2, image.height / 2),
      width: side.toDouble(),
      height: side.toDouble(),
    );
    final dst = Rect.fromCircle(center: center, radius: r);
    canvas
      ..save()
      ..clipPath(Path()..addOval(dst))
      ..drawImageRect(
        image,
        src,
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      )
      ..restore()
      ..drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = accent,
      );
  }

  void _paintInitial(Canvas canvas, Offset center, double r) {
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

  /// Online (top-right): a green dot with a white ring, the same presence
  /// language as the member directory.
  void _paintOnline(Canvas canvas, Offset at, double badgeR) {
    canvas
      ..drawCircle(at, badgeR + 1.4, Paint()..color = Colors.white)
      ..drawCircle(
        at,
        badgeR,
        Paint()..color = AppStatusColors.successOf(brightness),
      );
  }

  /// #908 — shared today (top-left): the number of bookings the seat
  /// carries. The avatar shows whoever holds it at the browsed moment; this
  /// says they are not the only one, and the day sheet names the rest.
  /// Placed opposite the presence dot so neither hides the other.
  void _paintShareCount(Canvas canvas, Offset at, double badgeR) {
    canvas
      ..drawCircle(at, badgeR + 1.4, Paint()..color = Colors.white)
      ..drawCircle(at, badgeR, Paint()..color = accent);
    final count = TextPainter(
      text: TextSpan(
        text: '$shareCount',
        style: TextStyle(
          color: Colors.white,
          fontSize: badgeR * 1.35,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    count.paint(canvas, at - Offset(count.width / 2, count.height / 2));
  }

  /// Checked in (bottom-right): a white-ringed accent disc with a check —
  /// "physically here", distinct from a mere reservation.
  void _paintCheck(Canvas canvas, Offset at, double badgeR) {
    canvas
      ..drawCircle(at, badgeR + 1.4, Paint()..color = Colors.white)
      ..drawCircle(at, badgeR, Paint()..color = accent);
    final check = Path()
      ..moveTo(at.dx - badgeR * 0.45, at.dy)
      ..lineTo(at.dx - badgeR * 0.1, at.dy + badgeR * 0.4)
      ..lineTo(at.dx + badgeR * 0.5, at.dy - badgeR * 0.4);
    canvas.drawPath(
      check,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = badgeR * 0.32
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }
}
