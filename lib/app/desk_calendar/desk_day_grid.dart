// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the day at the desk: places down, the opening hours
// across. The hours fit the room the grid has (after the shell, the place
// column and any pane beside it); where that would squeeze an hour under a
// usable width, the grid keeps that width and scrolls sideways, and the zoom
// widens it further. A position on the axis is exactly one instant (the axis
// counts elapsed time), so the day a clock changes shows the repeated hour
// twice and the missing hour as a marker, never a silent shift.
import 'package:flutter/material.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/time/day_axis.dart';
import '../../features/reservations/domain/reservation.dart';
import 'desk_booking_chip.dart';
import 'desk_calendar.dart';
import 'desk_free_region.dart';
import 'desk_grid_rows.dart';
import 'desk_metrics.dart';

/// The key of the sideways scroller of the day grid.
@visibleForTesting
const Key deskDayScrollKey = ValueKey('desk-day-scroll');

/// The key of the clock-change marker before elapsed hour [index].
@visibleForTesting
Key deskClockChangeKey(int index) => ValueKey('desk-clock-change-$index');

class DeskDayGrid extends StatefulWidget {
  const DeskDayGrid({
    required this.axis,
    required this.entries,
    required this.bookings,
    required this.names,
    required this.selectedId,
    required this.zoom,
    required this.open,
    required this.onOpen,
    required this.onFree,
    super.key,
  });

  final DayAxis axis;
  final List<DeskGridEntry> entries;
  final List<Reservation> bookings;
  final Map<String, String> names;
  final String? selectedId;

  /// 1 fits the hours in the room; more widens them.
  final double zoom;

  /// Whether the business opens on this day: a closed day books nothing.
  final bool open;
  final ValueChanged<Reservation> onOpen;

  /// A free place was chosen at [instant].
  final void Function(DeskPlace place, DateTime instant) onFree;

  @override
  State<DeskDayGrid> createState() => _DeskDayGridState();
}

class _DeskDayGridState extends State<DeskDayGrid> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = deskDayScale(
        room: box.maxWidth - DeskCalendarMetrics.placeColumn,
        minutes: widget.axis.minutes,
        zoom: widget.zoom,
      );
      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: DeskCalendarMetrics.placeColumn,
                  height: DeskCalendarMetrics.ruler,
                ),
                for (final e in widget.entries) DeskPlaceName(e),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                key: deskDayScrollKey,
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: scale.width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Ruler(axis: widget.axis, scale: scale),
                      for (final e in widget.entries) _track(context, e, scale),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _track(BuildContext context, DeskGridEntry entry, DeskDayScale scale) {
    final place = entry.place;
    if (place == null) {
      return SizedBox(width: scale.width, height: entry.height);
    }
    final axis = widget.axis;
    final blocks = bookingsOfPlace(place, widget.bookings)
        .where(
          (r) => axis.offsetOf(r.endsAt) > axis.offsetOf(r.startsAt),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final scheme = Theme.of(context).colorScheme;
    final bookable =
        widget.open &&
        place.seat != null &&
        !place.seat!.isBlockedAt(axis.start);
    // The free stretches between the blocks: each its own target, so a block
    // and the free time beside it never share one.
    final free = <({int from, int to})>[];
    var cursor = 0;
    for (final r in blocks) {
      final from = axis.offsetOf(r.startsAt);
      if (from > cursor) free.add((from: cursor, to: from));
      final to = axis.offsetOf(r.endsAt);
      if (to > cursor) cursor = to;
    }
    if (cursor < axis.minutes) free.add((from: cursor, to: axis.minutes));
    final ppm = scale.pixelsPerMinute;
    return DeskGridRow(
      placeId: place.id,
      width: scale.width,
      child: Stack(
        children: [
          for (final t in axis.ticks)
            Positioned(
              left: axis.offsetOf(t.instant) * ppm,
              top: 0,
              bottom: 0,
              width: 1,
              child: IgnorePointer(
                child: ColoredBox(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          if (bookable)
            for (final f in free)
              Positioned(
                left: f.from * ppm,
                width: (f.to - f.from) * ppm,
                top: 0,
                bottom: 0,
                child: DeskFreeRegion(
                  regionKey: ValueKey('desk-free-${place.id}-${f.from}'),
                  label: context.l10n.calendarDeskFreeSlot(
                    place.name,
                    appFormatOf(context).time(axis.instantAt(f.from)),
                    appFormatOf(context).time(axis.instantAt(f.to)),
                  ),
                  pixelsPerMinute: ppm,
                  onChosen: (within) {
                    // The hour the pointer is in, never before the stretch.
                    final hour =
                        (f.from + within) ~/
                        Duration.minutesPerHour *
                        Duration.minutesPerHour;
                    widget.onFree(
                      place,
                      axis.instantAt(hour < f.from ? f.from : hour),
                    );
                  },
                ),
              ),
          for (final r in blocks)
            Positioned(
              left: axis.offsetOf(r.startsAt) * ppm,
              width: (axis.offsetOf(r.endsAt) - axis.offsetOf(r.startsAt)) * ppm,
              top: DeskCalendarMetrics.blockInset,
              bottom: DeskCalendarMetrics.blockInset,
              child: DeskBookingChip(
                booking: r,
                who: deskBookingWho(widget.names, r),
                placeName: place.name,
                selected: widget.selectedId == r.id,
                onOpen: () => widget.onOpen(r),
              ),
            ),
        ],
      ),
    );
  }

}

/// The hour marks across the top.
class _Ruler extends StatelessWidget {
  const _Ruler({required this.axis, required this.scale});

  final DayAxis axis;
  final DeskDayScale scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = appFormatOf(context);
    final l10n = context.l10n;
    return SizedBox(
      width: scale.width,
      height: DeskCalendarMetrics.ruler,
      child: Stack(
        children: [
          for (final (i, t) in axis.ticks.indexed) ...[
            Positioned(
              left: axis.offsetOf(t.instant) * scale.pixelsPerMinute + 3,
              top: 0,
              bottom: 0,
              child: Semantics(
                label: t.repeated
                    ? l10n.calendarDeskRepeatedHour(format.time(t.instant))
                    : format.time(t.instant),
                excludeSemantics: true,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // The second time round of an hour that happens twice.
                    t.repeated
                        ? '${format.time(t.instant)}²'
                        : format.time(t.instant),
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            if (t.afterGap)
              Positioned(
                key: deskClockChangeKey(i),
                left: axis.offsetOf(t.instant) * scale.pixelsPerMinute - 1,
                top: 0,
                bottom: 0,
                width: 2,
                child: Semantics(
                  label: l10n.calendarDeskMissingHour(
                    _wallLabel(format, axis.ticks[i - 1].wallMinutes + 60),
                    _wallLabel(format, t.wallMinutes),
                  ),
                  excludeSemantics: true,
                  child: ColoredBox(color: theme.colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// A wall-clock reading [minutes] after midnight, in the member's clock.
String _wallLabel(AppFormat format, int minutes) => format.wallTime(
  DateTime(2000, 1, 1, minutes ~/ Duration.minutesPerHour,
      minutes % Duration.minutesPerHour),
);
