// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'floor_plan_painter.dart';

// #2386 — part 1 of FloorPlanPainter, split out of floor_plan_painter.dart so no
// file holds the whole class.
extension _FloorPlanPainterPart1 on FloorPlanPainter {

  Rect _toPx(GridRect r) => Rect.fromLTWH(
        r.x * cellSize,
        r.y * cellSize,
        r.w * cellSize,
        r.h * cellSize,
      );

  void _paintImpl(Canvas canvas, Size size) {
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
        Paint()
          ..color = OfficeColors.of(office.color, from: officePalette)
              .withValues(alpha: 0.55),
      );
      // Whole-office/level reservation (#462): the ROOM itself says so
      // — state-coloured wash, accent border, occupant in the label.
      final overlay = spaceOverlays?[office.id];
      if (overlay != null) {
        final accent =
            SeatStateColors.of(overlay.state, brightness: brightness);
        canvas.drawRect(
            rect, Paint()..color = accent.withValues(alpha: 0.20));
        drawHatch(canvas, rect, accent);
        canvas.drawRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = accent.withValues(alpha: 0.9),
        );
        final officeLabel = !_labelsOffices
            ? overlay.label
            : overlay.label.isEmpty
                ? office.name
                : '${office.name} · ${overlay.label}';
        if (officeLabel.isNotEmpty) {
          drawLabel(canvas, officeLabel, rect, colorScheme.onSurface);
        }
        drawReservedChip(canvas, rect, overlay.label, accent,             checkedIn: overlay.state == SeatState.occupied);
      } else {
        canvas.drawRect(rect, officeBorder);
        if (_labelsOffices) {
          drawLabel(canvas, office.name, rect, colorScheme.onSurface);
        }
      }
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
      drawSoftShadow(canvas, rrect, alpha: deskShadowAlpha);
      canvas.drawRRect(rrect, deskPaint);
      // Whole-desk reservation (#462): the table itself reads taken —
      // wash + accent border; the seats on it carry the avatars.
      final overlay = spaceOverlays?[desk.id];
      if (overlay != null) {
        final accent =
            SeatStateColors.of(overlay.state, brightness: brightness);
        canvas
          ..drawRRect(
            rrect, Paint()..color = accent.withValues(alpha: 0.18))
        // #670 — the same hatch as a booked room, clipped to the desk's
        // rounded rect. A whole-TABLE booking is the case the field
        // report named first: six tinted seats look identical to six
        // individual bookings without it.
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
        // The chip only when the office above does not already carry
        // one for the same booking — a whole-office/level overlay
        // covers its desks too, and stacked identical chips are noise.
        if (spaceOverlays?[desk.officeId] == null) {
          drawReservedChip(canvas, rect, overlay.label, accent,               checkedIn: overlay.state == SeatState.occupied);
        }
      } else {
        canvas.drawRRect(rrect, deskBorder);
      }
    }

    for (final seat in plan.seats) {
      final rect = _toPx(seat.footprint).deflate(3);
      final state = seatStates?[seat.id];
      var accent = state == null
          ? colorScheme.primary
          : SeatStateColors.of(state, brightness: brightness);
      // #611 — a state change eases the accent from the old colour.
      final previous = previousSeatStates?[seat.id];
      if (state != null && previous != null && seatStateLerp < 1) {
        accent = Color.lerp(
              SeatStateColors.of(previous, brightness: brightness),
              accent,
              seatStateLerp,
            ) ??
            accent;
      }
      // Radius scales with the tile so a seat always reads as a soft,
      // rounded pad — the signature "living plan" tile.
      final radius = (rect.shortestSide * 0.24).clamp(4.0, 10.0);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

      drawSoftShadow(canvas, rrect,
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
      final segments = this.seatDaySegments[seat.id] ?? const <SeatDaySegment>[];
      // #908 — divided whenever the day is not ONE booking: partly free,
      // or shared between members. A flat fill over a shared day names
      // one holder for hours that belong to someone else.
      final split = segments.isNotEmpty && seatDayIsSplit(segments);
      if (split) {
        // The day is the seat's width: each booking paints its own
        // stretch over an otherwise free-looking pad, and a hairline
        // keeps two neighbouring bookings from reading as one.
        final freeAccent =
            SeatStateColors.of(SeatState.free, brightness: brightness);
        canvas
          ..drawRRect(rrect,
            Paint()..color = freeAccent.withValues(alpha: overPhoto ? 0.20 : 0.14))
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
              ..color = SeatStateColors.of(segment.state, brightness: brightness)
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
      } else {
        canvas.drawRRect(
            rrect, Paint()..color = accent.withValues(alpha: fillAlpha));
      }
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = state == SeatState.mine ? 2 : 1.3
          ..color = accent.withValues(alpha: 0.9),
      );
      // #575 — the day ring, in the user's own colours: green for a
      // booking running NOW, half-transparent green for one still ahead
      // today, grey for a day already served. Distinct channel from the
      // state fill, so the palette's colourblind pairing stays intact.
      final phase = seatDayPhases[seat.id] ?? SeatDayPhase.none;
      if (phase != SeatDayPhase.none && state != null) {
        final ringColor = switch (phase) {
          SeatDayPhase.ongoing => SeatStateColors.of(SeatState.free,
              brightness: brightness),
          SeatDayPhase.upcoming => SeatStateColors.of(SeatState.free,
                  brightness: brightness)
              .withValues(alpha: 0.5),
          _ => SeatStateColors.of(SeatState.blocked,
              brightness: brightness),
        };
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.inflate(2), Radius.circular(radius + 2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = ringColor,
        );
      }
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

      final label = seatLabels?[seat.id] ?? '';
      if (state != null && state != SeatState.blocked && label.isNotEmpty) {
        // Live occupancy: the occupant becomes an avatar right on the
        // seat — one glance answers "who's here". This is the plan's
        // signature move. A check badge marks someone physically checked
        // in; a green dot marks them online (presence).
        _occupantAvatar(
          canvas,
          rect,
          label,
          accent,
          photo: seatPhotos[seat.id],
          checkedIn: state == SeatState.occupied,
          online: onlineSeatIds.contains(seat.id),
          // #908 — the seat changes hands today: say how many bookings
          // it carries instead of letting one avatar speak for the day.
          shareCount: segments.length > 1 ? segments.length : 0,
        );
      } else if (state == null) {
        // Editor mode: name + orientation so the owner can place seats.
        _orientationArrow(canvas, seat, rect, accent);
        if (label.isNotEmpty) {
          drawLabel(canvas, label, rect, colorScheme.onSurface, center: true);
        }
      }
      if (state != null) drawSeatIdentifier(canvas, rect, seat.name, state, scale: labelScale, style: identifierStyle);
    }

    // #576 — the space highlight rings, on top of everything painted.
    Paint spaceRing() => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colorScheme.tertiary;
    if (highlightedDeskId != null) {
      final desk =
          plan.desks.where((d) => d.id == highlightedDeskId).firstOrNull;
      if (desk != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              _toPx(desk.rect).inflate(3), const Radius.circular(8)),
          spaceRing(),
        );
      }
    }
    if (highlightedOfficeId != null) {
      final office = plan.offices
          .where((o) => o.id == highlightedOfficeId)
          .firstOrNull;
      if (office != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              _toPx(office.rect).inflate(3), const Radius.circular(10)),
          spaceRing(),
        );
      }
    }
    if (highlightLevel) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(2), const Radius.circular(12)),
        spaceRing(),
      );
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

    // #1216 — the editor's only mark on this canvas: where the armed
    // tool may legally place its next element.
    paintDropTargets(
      canvas: canvas,
      size: size,
      plan: plan,
      targets: dropTargets,
      cellSize: cellSize,
      colorScheme: colorScheme,
    );

    final m = marquee;
    if (m != null) {
      final rect = _toPx(m);
      final color = marqueeValid ? colorScheme.primary : colorScheme.error;
      canvas
        ..drawRect(rect, Paint()..color = color.withValues(alpha: 0.2))
        ..drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }
}
