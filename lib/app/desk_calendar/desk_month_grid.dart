// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the month at the desk: cells that grow with the window and
// list the day's bookings by name until they no longer fit, then say how many
// more. "N more" opens exactly the bookings that were left out. A day's number
// opens that day.
import 'package:flutter/material.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/i18n/week_start.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/reservations/domain/reservation.dart';
import 'desk_booking_chip.dart';
import 'desk_calendar.dart';
import 'desk_metrics.dart';

/// The key of the cell of [day].
@visibleForTesting
Key deskMonthCellKey(DateTime day) =>
    ValueKey('desk-month-cell-${day.year}-${day.month}-${day.day}');

/// The key of the "N more" button of [day].
@visibleForTesting
Key deskMonthMoreKey(DateTime day) =>
    ValueKey('desk-month-more-${day.year}-${day.month}-${day.day}');

/// How many booking lines fit a cell of [cellHeight]: the cell's room under
/// the day's number, in lines a mouse hits.
@visibleForTesting
int deskMonthLines(double cellHeight) =>
    ((cellHeight - DeskCalendarMetrics.monthDayHeader) /
            DeskCalendarMetrics.monthLine)
        .floor();

/// What a cell of [lines] lines shows of [count] bookings: how many it lists
/// and how many it leaves for "N more". A cell that cannot list them all keeps
/// its last line for the count.
@visibleForTesting
({int shown, int hidden}) deskMonthSplit(int count, int lines) {
  if (count <= lines) return (shown: count, hidden: 0);
  final shown = lines > 1 ? lines - 1 : 0;
  return (shown: shown, hidden: count - shown);
}

class DeskMonthGrid extends StatelessWidget {
  const DeskMonthGrid({
    required this.month,
    required this.weeks,
    required this.bookings,
    required this.names,
    required this.placeNames,
    required this.selectedId,
    required this.today,
    required this.isOpen,
    required this.dayStart,
    required this.onOpen,
    required this.onDay,
    required this.onMore,
    super.key,
  });

  final DateTime month;
  final List<List<DateTime>> weeks;
  final List<Reservation> bookings;
  final Map<String, String> names;
  final Map<String, String> placeNames;
  final String? selectedId;
  final DateTime today;
  final bool Function(DateTime day) isOpen;
  final DateTime Function(DateTime day) dayStart;
  final ValueChanged<Reservation> onOpen;
  final ValueChanged<DateTime> onDay;

  /// "N more" was chosen on [day], with the bookings the cell left out.
  final void Function(DateTime day, List<Reservation> hidden) onMore;

  @override
  Widget build(BuildContext context) {
    final format = appFormatOf(context);
    final headers = weekdayHeaders(format);
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxHeight - DeskCalendarMetrics.monthDayHeader;
        final fit = room / weeks.length;
        final cellHeight = fit < DeskCalendarMetrics.monthCellMin
            ? DeskCalendarMetrics.monthCellMin
            : fit;
        final cellWidth = box.maxWidth / 7;
        return Column(
          children: [
            SizedBox(
              height: DeskCalendarMetrics.monthDayHeader,
              child: Row(
                children: [
                  for (final h in headers)
                    SizedBox(
                      width: cellWidth,
                      child: Center(
                        child: Semantics(
                          label: h.full,
                          excludeSemantics: true,
                          child: Text(
                            h.narrow,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final week in weeks)
                      Row(
                        children: [
                          for (final day in week)
                            DeskMonthCell(
                              day: day,
                              inMonth: day.month == month.month,
                              width: cellWidth,
                              height: cellHeight,
                              today: day == today,
                              open: isOpen(day),
                              bookings: day.month == month.month
                                  ? _of(day)
                                  : const [],
                              grid: this,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Reservation> _of(DateTime day) {
    final from = dayStart(day);
    final to = dayStart(DateTime(day.year, day.month, day.day + 1));
    return bookings
        .where((r) => r.startsAt.isBefore(to) && r.endsAt.isAfter(from))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }
}

/// One day's cell of the month grid (measured as a row by the guards).
class DeskMonthCell extends StatelessWidget {
  const DeskMonthCell({
    super.key,
    required this.day,
    required this.inMonth,
    required this.width,
    required this.height,
    required this.today,
    required this.open,
    required this.bookings,
    required this.grid,
  });

  final DateTime day;
  final bool inMonth;
  final double width;
  final double height;
  final bool today;
  final bool open;
  final List<Reservation> bookings;
  final DeskMonthGrid grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final split = deskMonthSplit(bookings.length, deskMonthLines(height));
    final hidden = bookings.sublist(split.shown);
    return SizedBox(
      key: deskMonthCellKey(day),
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: today
              ? scheme.primaryContainer.withValues(alpha: 0.18)
              : inMonth && open
              ? null
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
        child: Column(
          children: [
            SizedBox(
              height: DeskCalendarMetrics.monthDayHeader,
              child: Semantics(
                button: true,
                selected: today,
                label: format.dates(DateShape.weekdayMonthDay).format(day),
                excludeSemantics: true,
                child: InkWell(
                  key: ValueKey(
                    'desk-month-day-${day.year}-${day.month}-${day.day}',
                  ),
                  onTap: () => grid.onDay(day),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        format.dates(DateShape.day).format(day),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: today
                              ? scheme.primary
                              : inMonth
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            for (final r in bookings.take(split.shown))
              SizedBox(
                height: DeskCalendarMetrics.monthLine,
                child: Padding(
                  padding: const EdgeInsets.all(DeskCalendarMetrics.blockInset),
                  child: DeskBookingChip(
                    booking: r,
                    who: deskBookingWho(grid.names, r),
                    placeName: grid.placeNames[bookingTargetId(r)] ?? '',
                    selected: grid.selectedId == r.id,
                    showHours: false,
                    onOpen: () => grid.onOpen(r),
                  ),
                ),
              ),
            if (split.hidden > 0)
              SizedBox(
                height: DeskCalendarMetrics.monthLine,
                child: TextButton(
                  key: deskMonthMoreKey(day),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    alignment: AlignmentDirectional.centerStart,
                  ),
                  onPressed: () => grid.onMore(day, hidden),
                  child: Text(l10n.calendarDeskMore(split.hidden)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
