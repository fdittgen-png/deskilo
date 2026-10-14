// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The floor plan's furniture layers (#2494): the offices, the desks and the
// seats, with the state colours, the whole-space reservation washes (#462,
// #670), the day segments (#903, #908), the day ring (#575) and the
// occupant avatar. Functions of the painter's inputs; none holds state.
import 'package:flutter/material.dart';

import '../../../../core/theme/office_colors.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../reservations/domain/seat_state_logic.dart';
import '../../domain/seat.dart';
import 'floor_plan_painter.dart';
import 'plan_paint_helpers.dart';
import 'seat_avatar_paint.dart';
import 'seat_identifier_paint.dart';

/// Every office: its fill and border, or the wash of a whole-office
/// reservation with its occupant in the label.
void paintFloorPlanOffices(Canvas canvas, FloorPlanPainter p) {
  final labelsOffices = p.plan.labelsOffices(byLevel: p.singleRoomByLevel);
  final officeBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = p.colorScheme.outline;
  for (final office in p.plan.offices) {
    final rect = gridRectToPx(office.rect, p.cellSize);
    canvas.drawRect(
      rect,
      Paint()
        ..color = OfficeColors.of(office.color, from: p.officePalette)
            .withValues(alpha: 0.55),
    );
    // Whole-office/level reservation (#462): the ROOM itself says so —
    // state-coloured wash, accent border, occupant in the label.
    final overlay = p.spaceOverlays?[office.id];
    if (overlay != null) {
      _paintReservedOffice(canvas, p, office.name, rect, overlay, labelsOffices);
    } else {
      canvas.drawRect(rect, officeBorder);
      if (labelsOffices) {
        drawLabel(canvas, office.name, rect, p.colorScheme.onSurface);
      }
    }
  }
}

void _paintReservedOffice(
  Canvas canvas,
  FloorPlanPainter p,
  String officeName,
  Rect rect,
  ({SeatState state, String label}) overlay,
  bool labelsOffices,
) {
  final accent = SeatStateColors.of(overlay.state, brightness: p.brightness);
  canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: 0.20));
  drawHatch(canvas, rect, accent);
  canvas.drawRect(
    rect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = accent.withValues(alpha: 0.9),
  );
  final officeLabel = !labelsOffices
      ? overlay.label
      : overlay.label.isEmpty
          ? officeName
          : '$officeName · ${overlay.label}';
  if (officeLabel.isNotEmpty) {
    drawLabel(canvas, officeLabel, rect, p.colorScheme.onSurface);
  }
  drawReservedChip(canvas, rect, overlay.label, accent,
      checkedIn: overlay.state == SeatState.occupied);
}

/// Every desk: soft rounded tonal surfaces — the furniture the room is built
/// from, not flat grey boxes. A hairline border and a whisper of a contact
/// shadow give the plan gentle depth. Configurable transparency (0040): the
/// fill (and its contact shadow) fades by deskOpacity, the border stays
/// opaque so a translucent desk stays locatable over a background photo.
void paintFloorPlanDesks(Canvas canvas, FloorPlanPainter p) {
  final deskAlpha = p.deskOpacity.clamp(0.0, 1.0);
  final deskPaint = Paint()
    ..color = p.colorScheme.surfaceContainerHigh.withValues(alpha: deskAlpha);
  final deskBorder = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = p.colorScheme.outlineVariant;
  final deskShadowAlpha =
      (p.brightness == Brightness.dark ? 0.28 : 0.10) * deskAlpha;
  for (final desk in p.plan.desks) {
    final rect = gridRectToPx(desk.rect, p.cellSize).deflate(1.5);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    drawSoftShadow(canvas, rrect, alpha: deskShadowAlpha);
    canvas.drawRRect(rrect, deskPaint);
    // Whole-desk reservation (#462): the table itself reads taken — wash +
    // accent border; the seats on it carry the avatars.
    final overlay = p.spaceOverlays?[desk.id];
    if (overlay != null) {
      _paintReservedDesk(canvas, p, desk.officeId, rect, rrect, overlay);
    } else {
      canvas.drawRRect(rrect, deskBorder);
    }
  }
}

void _paintReservedDesk(
  Canvas canvas,
  FloorPlanPainter p,
  String officeId,
  Rect rect,
  RRect rrect,
  ({SeatState state, String label}) overlay,
) {
  final accent = SeatStateColors.of(overlay.state, brightness: p.brightness);
  canvas
    ..drawRRect(rrect, Paint()..color = accent.withValues(alpha: 0.18))
    // #670 — the same hatch as a booked room, clipped to the desk's rounded
    // rect. A whole-TABLE booking is the case the field report named first:
    // six tinted seats look identical to six individual bookings without it.
    ..save()
    ..clipRRect(rrect);
  drawHatch(canvas, rect, accent);
  canvas
    ..restore()
    ..drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: 0.9),
    );
  // The chip only when the office above does not already carry one for the
  // same booking — a whole-office/level overlay covers its desks too, and
  // stacked identical chips are noise.
  if (p.spaceOverlays?[officeId] == null) {
    drawReservedChip(canvas, rect, overlay.label, accent,
        checkedIn: overlay.state == SeatState.occupied);
  }
}

/// Every seat, in the painter's live (state-coloured, avatars) or editor
/// (uniform, orientation arrow) mode.
void paintFloorPlanSeats(Canvas canvas, FloorPlanPainter p) {
  for (final seat in p.plan.seats) {
    _paintSeat(canvas, p, seat);
  }
}

/// One seat being painted: the painter's inputs, the seat, where it sits and
/// what colour it carries.
class _SeatDraw {
  _SeatDraw(this.p, this.seat)
      : rect = gridRectToPx(seat.footprint, p.cellSize).deflate(3),
        state = p.seatStates?[seat.id] {
    accent = _seatAccent(p, seat, state);
    // Radius scales with the tile so a seat always reads as a soft, rounded
    // pad — the signature "living plan" tile.
    radius = (rect.shortestSide * 0.24).clamp(4.0, 10.0);
  }

  final FloorPlanPainter p;
  final Seat seat;
  final Rect rect;
  final SeatState? state;
  late final Color accent;
  late final double radius;

  RRect get rrect => RRect.fromRectAndRadius(rect, Radius.circular(radius));

  List<SeatDaySegment> get segments =>
      p.seatDaySegments[seat.id] ?? const <SeatDaySegment>[];
}

void _paintSeat(Canvas canvas, FloorPlanPainter p, Seat seat) {
  final d = _SeatDraw(p, seat);
  drawSoftShadow(canvas, d.rrect,
      alpha: p.brightness == Brightness.dark ? 0.30 : 0.12);
  _paintSeatFill(canvas, d);
  canvas.drawRRect(
    d.rrect,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.state == SeatState.mine ? 2 : 1.3
      ..color = d.accent.withValues(alpha: 0.9),
  );
  _paintSeatRings(canvas, d);
  _paintSeatContent(canvas, d);
}

/// The seat's accent: the editor's primary, or the state's colour — eased
/// from the old state's while a change animates (#611).
Color _seatAccent(FloorPlanPainter p, Seat seat, SeatState? state) {
  var accent = state == null
      ? p.colorScheme.primary
      : SeatStateColors.of(state, brightness: p.brightness);
  final previous = p.previousSeatStates?[seat.id];
  if (state != null && previous != null && p.seatStateLerp < 1) {
    accent = Color.lerp(
          SeatStateColors.of(previous, brightness: p.brightness),
          accent,
          p.seatStateLerp,
        ) ??
        accent;
  }
  return accent;
}

/// Calm tint fill: free stays airy, taken seats read a touch fuller. Over a
/// background photo the zone must still read as a status colour without
/// hiding the image — a modest bump, never opaque. A day that is not ONE
/// booking (#908) paints each booking's own stretch instead.
void _paintSeatFill(Canvas canvas, _SeatDraw d) {
  final p = d.p;
  final rect = d.rect;
  final rrect = d.rrect;
  final state = d.state;
  final accent = d.accent;
  final segments = d.segments;
  final overPhoto = p.background != null;
  final fillAlpha = switch (state) {
    null => overPhoto ? 0.24 : 0.16,
    SeatState.free => overPhoto ? 0.20 : 0.14,
    SeatState.blocked => overPhoto ? 0.24 : 0.10,
    _ => overPhoto ? 0.40 : 0.22,
  };
  // #908 — divided whenever the day is not ONE booking: partly free, or
  // shared between members. A flat fill over a shared day names one holder
  // for hours that belong to someone else.
  final split = segments.isNotEmpty && seatDayIsSplit(segments);
  if (!split) {
    canvas.drawRRect(
        rrect, Paint()..color = accent.withValues(alpha: fillAlpha));
    return;
  }
  // The day is the seat's width: each booking paints its own stretch over an
  // otherwise free-looking pad, and a hairline keeps two neighbouring
  // bookings from reading as one.
  final freeAccent =
      SeatStateColors.of(SeatState.free, brightness: p.brightness);
  canvas
    ..drawRRect(
        rrect,
        Paint()
          ..color = freeAccent.withValues(alpha: overPhoto ? 0.20 : 0.14))
    ..save()
    ..clipRRect(rrect);
  for (final segment in segments) {
    final left = rect.left + rect.width * segment.from;
    final right = rect.left + rect.width * segment.to;
    if (right - left < 0.5) continue;
    canvas
      ..drawRect(
        Rect.fromLTRB(left, rect.top, right, rect.bottom),
        Paint()
          ..color = SeatStateColors.of(segment.state, brightness: p.brightness)
              .withValues(alpha: overPhoto ? 0.40 : 0.22),
      )
      ..drawLine(
        Offset(left, rect.top),
        Offset(left, rect.bottom),
        Paint()
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.55),
      );
  }
  canvas.restore();
}

/// The day ring (#575) and the "Show on plan" highlight (#182).
void _paintSeatRings(Canvas canvas, _SeatDraw d) {
  final p = d.p;
  final seat = d.seat;
  final rect = d.rect;
  final radius = d.radius;
  final state = d.state;
  // #575 — the day ring, in the user's own colours: green for a booking
  // running NOW, half-transparent green for one still ahead today, grey for
  // a day already served. Distinct channel from the state fill, so the
  // palette's colourblind pairing stays intact.
  final phase = p.seatDayPhases[seat.id] ?? SeatDayPhase.none;
  if (phase != SeatDayPhase.none && state != null) {
    final ringColor = switch (phase) {
      SeatDayPhase.ongoing =>
        SeatStateColors.of(SeatState.free, brightness: p.brightness),
      SeatDayPhase.upcoming =>
        SeatStateColors.of(SeatState.free, brightness: p.brightness)
            .withValues(alpha: 0.5),
      _ => SeatStateColors.of(SeatState.blocked, brightness: p.brightness),
    };
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(2), Radius.circular(radius + 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = ringColor,
    );
  }
  if (seat.id == p.highlightedSeatId) {
    // #182: ring around the focused seat; tertiary so it stands out against
    // both the primary editor accent and the state colors.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(3), Radius.circular(radius + 3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = p.colorScheme.tertiary,
    );
  }
}

/// Live occupancy: the occupant becomes an avatar right on the seat — one
/// glance answers "who's here". In the editor: name + orientation so the
/// owner can place seats.
void _paintSeatContent(Canvas canvas, _SeatDraw d) {
  final p = d.p;
  final seat = d.seat;
  final rect = d.rect;
  final state = d.state;
  final accent = d.accent;
  final segments = d.segments;
  final label = p.seatLabels?[seat.id] ?? '';
  if (state != null && state != SeatState.blocked && label.isNotEmpty) {
    SeatAvatar(
      name: label,
      accent: accent,
      brightness: p.brightness,
      photo: p.seatPhotos[seat.id],
      checkedIn: state == SeatState.occupied,
      online: p.onlineSeatIds.contains(seat.id),
      // #908 — the seat changes hands today: say how many bookings it
      // carries instead of letting one avatar speak for the day.
      shareCount: segments.length > 1 ? segments.length : 0,
    ).paint(canvas, rect);
  } else if (state == null) {
    _orientationArrow(canvas, seat, rect, accent);
    if (label.isNotEmpty) {
      drawLabel(canvas, label, rect, p.colorScheme.onSurface, center: true);
    }
  }
  if (state != null) {
    drawSeatIdentifier(canvas, rect, seat.name, state,
        scale: p.labelScale, style: p.identifierStyle);
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
