// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the week at the desk: places down, the seven days across,
// filling the room the grid has. The place column stays; today is marked. A
// day cell lists the bookings of that place on that day, each its own target;
// an empty cell of a seat on an open day opens New booking for that day.
import 'package:flutter/material.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/reservations/domain/reservation.dart';
import 'desk_booking_chip.dart';
import 'desk_calendar.dart';
import 'desk_free_region.dart';
import 'desk_grid_rows.dart';
import 'desk_metrics.dart';

/// The key of the sideways scroller of the week grid.
@visibleForTesting
const Key deskWeekScrollKey = ValueKey('desk-week-scroll');

/// The key of the header of [day].
Key _deskDayHeaderKey(DateTime day) =>
    ValueKey('desk-day-header-${day.year}-${day.month}-${day.day}');

class DeskWeekGrid extends StatelessWidget {
  const DeskWeekGrid({
    required this.days,
    required this.entries,
    required this.bookings,
    required this.names,
    required this.selectedId,
    required this.today,
    required this.isOpen,
    required this.dayStart,
    required this.onOpen,
    required this.onFree,
    super.key,
  });

  /// The seven days, first column first (date-only).
  final List<DateTime> days;
  final List<DeskGridEntry> entries;
  final List<Reservation> bookings;
  final Map<String, String> names;
  final String? selectedId;
  final DateTime today;

  /// Whether the business opens on a day.
  final bool Function(DateTime day) isOpen;

  /// The instant a day starts on the business's calendar.
  final DateTime Function(DateTime day) dayStart;
  final ValueChanged<Reservation> onOpen;

  /// A free seat's cell on [day] was chosen.
  final void Function(DeskPlace place, DateTime day) onFree;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final room = box.maxWidth - DeskCalendarMetrics.placeColumn;
      final fit = room / days.length;
      final dayWidth = fit < DeskCalendarMetrics.minDayWidth
          ? DeskCalendarMetrics.minDayWidth
          : fit;
      final width = dayWidth * days.length;
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
                for (final e in entries) DeskPlaceName(e),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                key: deskWeekScrollKey,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(context, dayWidth),
                      for (final e in entries) _line(context, e, dayWidth),
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

  Widget _header(BuildContext context, double dayWidth) {
    final theme = Theme.of(context);
    final format = appFormatOf(context);
    return SizedBox(
      height: DeskCalendarMetrics.ruler,
      child: Row(
        children: [
          for (final day in days)
            SizedBox(
              key: _deskDayHeaderKey(day),
              width: dayWidth,
              child: Semantics(
                label: format.dates(DateShape.weekdayMonthDay).format(day),
                selected: day == today,
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: day == today
                        ? theme.colorScheme.primaryContainer
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${format.dates(DateShape.weekday).format(day)} '
                      '${format.dates(DateShape.day).format(day)}',
                      maxLines: 1,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: day == today
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, DeskGridEntry entry, double dayWidth) {
    final place = entry.place;
    if (place == null) {
      return SizedBox(width: dayWidth * days.length, height: entry.height);
    }
    return DeskGridRow(
      placeId: place.id,
      width: dayWidth * days.length,
      child: Row(
        children: [
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: _cell(context, place, day),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, DeskPlace place, DateTime day) {
    final scheme = Theme.of(context).colorScheme;
    final from = dayStart(day);
    final to = dayStart(DateTime(day.year, day.month, day.day + 1));
    final here =
        bookingsOfPlace(
          place,
          bookings,
        ).where((r) => r.startsAt.isBefore(to) && r.endsAt.isAfter(from)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final seat = place.seat;
    final bookable = here.isEmpty && isOpen(day) && seat != null && !seat.isBlockedAt(from);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: day == today
            ? scheme.primaryContainer.withValues(alpha: 0.18)
            : isOpen(day)
            ? null
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(left: BorderSide(color: scheme.outlineVariant)),
      ),
      child: here.isEmpty
          ? bookable
                ? DeskFreeRegion(
                    regionKey: ValueKey(
                      'desk-free-${place.id}-${day.year}-${day.month}-${day.day}',
                    ),
                    label: context.l10n.calendarDeskFreeDay(
                      place.name,
                      appFormatOf(context).dates(DateShape.weekdayMonthDay).format(day),
                    ),
                    pixelsPerMinute: 1,
                    focusable: false,
                    onChosen: (_) => onFree(place, day),
                  )
                : const SizedBox.expand()
          : Padding(
              padding: const EdgeInsets.all(DeskCalendarMetrics.blockInset),
              child: Row(
                children: [
                  for (final (i, r) in here.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: DeskBookingChip(
                        booking: r,
                        who: deskBookingWho(names, r),
                        placeName: place.name,
                        selected: selectedId == r.id,
                        showHours: here.length == 1,
                        onOpen: () => onOpen(r),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
