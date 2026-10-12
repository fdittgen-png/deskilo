// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'floor_plan_painter.dart';

// #2386 — part 2 of FloorPlanPainter, split out of floor_plan_painter.dart so no
// file holds the whole class.
extension _FloorPlanPainterPart2 on FloorPlanPainter {


  void _occupantAvatar(
    Canvas canvas,
    Rect rect,
    String name,
    Color accent, {
    ui.Image? photo,
    bool checkedIn = false,
    bool online = false,
    int shareCount = 0,
  }) {
    final r = (rect.shortestSide * 0.34).clamp(8.0, 16.0);
    final center = rect.center;
    if (photo != null) {
      // #618 — the member's own face on the seat: the photo clipped to
      // the marker circle; the accent ring keeps the state colour
      // language the initial disc had.
      final side = photo.width < photo.height ? photo.width : photo.height;
      final src = Rect.fromCenter(
        center: Offset(photo.width / 2, photo.height / 2),
        width: side.toDouble(),
        height: side.toDouble(),
      );
      final dst = Rect.fromCircle(center: center, radius: r);
      canvas
        ..save()
        ..clipPath(Path()..addOval(dst))
        ..drawImageRect(
          photo,
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
    } else {
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

    // Corner badges — a small radius keeps them legible on tiny seats.
    final badgeR = (r * 0.42).clamp(4.0, 7.0);
    final diag = r * 0.72; // offset toward the corner along the 45° diagonal

    // Online (top-right): a green dot with a white ring, the same presence
    // language as the member directory.
    if (online) {
      final at = center + Offset(diag, -diag);
      canvas
        ..drawCircle(at, badgeR + 1.4, Paint()..color = Colors.white)
        ..drawCircle(
        at,
        badgeR,
        Paint()..color = AppStatusColors.successOf(brightness),
      );
    }

    // #908 — shared today (top-left): the number of bookings the seat
    // carries. The avatar shows whoever holds it at the browsed moment;
    // this says they are not the only one, and the day sheet names the
    // rest. Placed opposite the presence dot so neither hides the other.
    if (shareCount > 1) {
      final at = center + Offset(-diag, -diag);
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

    // Checked in (bottom-right): a white-ringed accent disc with a check —
    // "physically here", distinct from a mere reservation.
    if (checkedIn) {
      final at = center + Offset(diag, diag);
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

  void _orientationArrow(Canvas canvas, Seat seat, Rect rect, Color color) {
    final center = rect.center - const Offset(0, 4);
    const len = 6.0;
    final tip = switch (seat.orientation) {
      SeatOrientation.n => center - const Offset(0, len),
      SeatOrientation.s => center + const Offset(0, len),
      SeatOrientation.e => center + const Offset(len, 0),
      SeatOrientation.w => center - const Offset(len, 0),
    };
    canvas
      ..drawLine(
      center,
      tip,
      Paint()
        ..strokeWidth = 2
        ..color = color,
    )
      ..drawCircle(tip, 2, Paint()..color = color);
  }

  bool _shouldRepaintImpl(FloorPlanPainter oldDelegate) =>
      oldDelegate.plan != plan ||
      oldDelegate.singleRoomByLevel != singleRoomByLevel ||
      oldDelegate.background != background ||
      // Deep compares on the maps (perf audit): callers rebuild these
      // maps every frame/minute-tick, so identity `!=` was ALWAYS true
      // and every rebuild forced a full canvas repaint — including a
      // TextPainter.layout per seat label — even when nothing changed.
      !mapEquals(oldDelegate.images, images) ||
      !mapEquals(oldDelegate.seatPhotos, seatPhotos) ||
      oldDelegate.marquee != marquee ||
      !setEquals(oldDelegate.dropTargets, dropTargets) ||
      oldDelegate.marqueeValid != marqueeValid ||
      oldDelegate.selection != selection ||
      oldDelegate.selectionResizable != selectionResizable ||
      oldDelegate.selectionValid != selectionValid ||
      !mapEquals(oldDelegate.seatStates, seatStates) ||
      !mapEquals(oldDelegate.previousSeatStates, previousSeatStates) ||
      oldDelegate.seatStateLerp != seatStateLerp ||
      !mapEquals(oldDelegate.seatDayPhases, seatDayPhases) ||
      !_sameSegments(oldDelegate.seatDaySegments, this.seatDaySegments) ||
      !mapEquals(oldDelegate.seatLabels, seatLabels) ||
      !mapEquals(oldDelegate.spaceOverlays, spaceOverlays) ||
      oldDelegate.highlightedSeatId != highlightedSeatId ||
      oldDelegate.highlightedDeskId != highlightedDeskId ||
      oldDelegate.highlightedOfficeId != highlightedOfficeId ||
      oldDelegate.highlightLevel != highlightLevel ||
      oldDelegate.deskOpacity != deskOpacity ||
      !listEquals(oldDelegate.officePalette, officePalette) ||
      !setEquals(oldDelegate.onlineSeatIds, onlineSeatIds) ||
      oldDelegate.labelScale != labelScale || oldDelegate.identifierStyle != identifierStyle ||
      oldDelegate.cellSize != cellSize;

  // #2307 — a booking can change while the seat still reads "your seat".
  // Semantic actions must then use the new closure, independently of ink.
  bool _shouldRebuildSemanticsImpl(FloorPlanPainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.cellSize != cellSize ||
      oldDelegate.semanticsDirection != semanticsDirection ||
      !mapEquals(oldDelegate.semanticLabels, semanticLabels) ||
      oldDelegate.onSeatSemanticTap != onSeatSemanticTap;

  /// One semantics node per seat (#402). Without this, the app's core
  /// surface is a single unlabeled picture to TalkBack/VoiceOver — the
  /// hidden cost of choosing a canvas over widgets, paid here.
  SemanticsBuilderCallback? get _semanticsBuilderImpl {
    final labels = semanticLabels;
    if (labels == null) return null;
    return (Size size) => [
          for (final seat in plan.seats)
            CustomPainterSemantics(
              key: ValueKey('plan-seat-semantics-${seat.id}'),
              rect: _toPx(seat.footprint),
              properties: SemanticsProperties(
                label: labels[seat.id] ?? seat.name,
                textDirection: semanticsDirection,
                button: onSeatSemanticTap != null,
                // recorder-key-exempt: the seat's node is keyed above.
                onTap: onSeatSemanticTap == null
                    ? null
                    : () => onSeatSemanticTap!(seat),
              ),
            ),
        ];
  }
}
