// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/half_day_windows.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/reservation.dart';

/// Fixed geometry of the month availability calendar. Pinned by test.
abstract final class MonthGridMetrics {
  static const double weekdayHeaderHeight = 24;
  static const double minCellHeight = 52;
  static const double cellInset = 3;
}

/// Month availability calendar (#7): one cell per calendar day of the
/// selected day's month, each showing how many desks are free across ALL
/// floors — a heat fill scaled by occupancy, the free/total count, and a
/// today ring. Tapping a day selects it and (via [onDaySelected]) drills
/// into the Day view where occupants are named. Leading/trailing days of
/// the neighbouring months render muted and are not selectable, so the
/// grid always shows whole Monday–Sunday weeks.
class MonthGrid extends ConsumerWidget {
  const MonthGrid({
    required this.selectedDay,
    required this.reservations,
    required this.onDaySelected,
    super.key,
  });

  /// Any day of the month to render; its date drives the grid.
  final DateTime selectedDay;

  /// Active reservations intersecting this month (both month windows when
  /// the caller's selection sits near a boundary — deduped upstream).
  final List<Reservation> reservations;

  final void Function(DateTime day) onDaySelected;

  /// Key of one day cell (tests): the cell of [day]'s date.
  static Key cellKey(DateTime day) =>
      ValueKey('month-cell-${_stamp(day)}');

  static String _stamp(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Total bookable desks across every floor — the availability
    // denominator. Null while any level's plan still loads.
    final levels = ref.watch(levelsProvider).value;
    var totalSeats = 0;
    var plansReady = levels != null;
    for (final level in levels ?? const []) {
      final plan = ref.watch(floorPlanProvider(level.id)).value;
      if (plan == null) {
        plansReady = false;
      } else {
        totalSeats += plan.seats.length;
      }
    }

    final first = DateTime(selectedDay.year, selectedDay.month);
    final daysInMonth =
        DateTime(selectedDay.year, selectedDay.month + 1, 0).day;
    // Monday-based leading blanks so weeks read Mon–Sun.
    final leading = first.weekday - 1;
    final cells = <DateTime>[];
    for (var i = 0; i < leading; i++) {
      cells.add(DateTime(first.year, first.month, i - leading + 1));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(first.year, first.month, d));
    }
    while (cells.length % 7 != 0) {
      final last = cells.last;
      cells.add(DateTime(last.year, last.month, last.day + 1));
    }

    final today = DateTime.now();
    final weekdayFormat = DateFormat.E();

    return Column(
      children: [
        SizedBox(
          height: MonthGridMetrics.weekdayHeaderHeight,
          child: Row(
            children: [
              for (var w = 0; w < 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      // 2026-06-01 is a Monday: index the weekday labels.
                      weekdayFormat.format(DateTime(2026, 6, 1 + w)),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: AppSpacing.smH,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: MonthGridMetrics.minCellHeight,
            ),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              final day = cells[index];
              final inMonth = day.month == selectedDay.month;
              final free = plansReady
                  ? totalSeats - _occupiedSeatsOn(day)
                  : null;
              return _DayCell(
                day: day,
                inMonth: inMonth,
                isToday: DateUtils.isSameDay(day, today),
                isSelected: DateUtils.isSameDay(day, selectedDay),
                freeSeats: free,
                totalSeats: totalSeats,
                label: free == null
                    ? ''
                    : (l10n?.monthFreeCount(free, totalSeats) ??
                        '$free/$totalSeats'),
                onTap: inMonth ? () => onDaySelected(day) : null,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Distinct seats with an active reservation overlapping [day]'s full
  /// workspace-local window — the day's occupancy across all floors.
  int _occupiedSeatsOn(DateTime day) {
    final window = HalfDayWindows.fullDay(day);
    final seatIds = <String>{};
    for (final r in reservations) {
      if (r.seatId == null) continue;
      if (r.coversRange(window.start, window.end)) seatIds.add(r.seatId!);
    }
    return seatIds.length;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.freeSeats,
    required this.totalSeats,
    required this.label,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int? freeSeats;
  final int totalSeats;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Heat fill: greener the more free, redder the fuller. Neutral when
    // the workspace has no desks yet or the plans are still loading.
    Color fill;
    if (!inMonth || freeSeats == null || totalSeats == 0) {
      fill = Colors.transparent;
    } else {
      final freeRatio = freeSeats! / totalSeats;
      fill = Color.lerp(
        scheme.errorContainer,
        scheme.primaryContainer,
        freeRatio,
      )!
          .withValues(alpha: 0.55);
    }

    final onFill = inMonth
        ? scheme.onSurface
        : scheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.all(MonthGridMetrics.cellInset),
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: isSelected
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: MonthGrid.cellKey(day),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 1.5),
                      )
                    : null,
                padding: const EdgeInsets.all(3),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: onFill,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: onFill,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
