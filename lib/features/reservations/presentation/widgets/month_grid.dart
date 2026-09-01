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
import '../../../../core/time/clock.dart';

/// Fixed geometry of the month availability calendar. Pinned by test.
abstract final class MonthGridMetrics {
  static const double weekdayHeaderHeight = 24;
  // 52→46 (#478): the availability calendar reads the same with a
  // denser grid — more of the month fits without scrolling.
  static const double minCellHeight = 46;
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
    this.isDayOpen,
    super.key,
  });

  /// Any day of the month to render; its date drives the grid.
  final DateTime selectedDay;

  /// Active reservations intersecting this month (both month windows when
  /// the caller's selection sits near a boundary — deduped upstream).
  final List<Reservation> reservations;

  final void Function(DateTime day) onDaySelected;

  /// #814 — whether the workspace is open on a cell's day. A closed day
  /// shows no free-desk count (there is nothing to book) and reads
  /// "Closed"; it stays selectable so the Day view can say why.
  final bool Function(DateTime day)? isDayOpen;

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
    // Whole-space rows (#452) count against every seat they cover — the
    // heat map otherwise over-reports free desks. One id → seat-ids map
    // per space kind, built once per rebuild.
    final deskSeats = <String, List<String>>{};
    final officeSeats = <String, List<String>>{};
    final levelSeats = <String, List<String>>{};
    for (final level in levels ?? const []) {
      final plan = ref.watch(floorPlanProvider(level.id)).value;
      if (plan == null) {
        plansReady = false;
      } else {
        totalSeats += plan.seats.length;
        levelSeats[plan.levelId] = [for (final s in plan.seats) s.id];
        for (final desk in plan.desks) {
          deskSeats[desk.id] = [
            for (final s in plan.seatsOf(desk.id)) s.id,
          ];
          (officeSeats[desk.officeId] ??= []).addAll(deskSeats[desk.id]!);
        }
      }
    }
    Iterable<String> seatIdsOf(Reservation r) {
      final seatId = r.seatId;
      if (seatId != null) return [seatId];
      if (r.deskId != null) return deskSeats[r.deskId] ?? const [];
      if (r.officeId != null) return officeSeats[r.officeId] ?? const [];
      if (r.levelId != null) return levelSeats[r.levelId] ?? const [];
      return const [];
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

    final today = ref.watch(clockProvider).now();
    final weekdayFormat = DateFormat.E();
    // One occupancy fold for the whole grid instead of one reservation
    // scan per cell (perf audit).
    final occupied = plansReady
        ? _occupiedByDay(cells, seatIdsOf)
        : const <DateTime, Set<String>>{};

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
              final open = isDayOpen?.call(day) ?? true;
              final free = plansReady
                  ? totalSeats - (occupied[day]?.length ?? 0)
                  : null;
              return _DayCell(
                day: day,
                inMonth: inMonth,
                isToday: DateUtils.isSameDay(day, today),
                isSelected: DateUtils.isSameDay(day, selectedDay),
                freeSeats: open ? free : null,
                totalSeats: totalSeats,
                closed: !open,
                label: !open
                    ? (l10n?.reserveClosedShort ?? 'Closed')
                    : free == null
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

  /// Occupied seats per visible day, folded in ONE pass over the
  /// reservations (perf audit: the previous per-cell scan was
  /// O(42 × month's reservations) and re-ran on every rebuild). Each
  /// reservation only walks the few grid days it can actually touch;
  /// the exact overlap check stays [Reservation.coversRange] against the
  /// day's workspace-local full window.
  Map<DateTime, Set<String>> _occupiedByDay(
    List<DateTime> cells,
    Iterable<String> Function(Reservation) seatIdsOf,
  ) {
    if (cells.isEmpty) return const {};
    final first = cells.first;
    final last = cells.last;
    final byDay = <DateTime, Set<String>>{};
    for (final r in reservations) {
      if (!r.isActive) continue;
      // Whole-space rows expand to every covered seat (#452); an
      // unknown target (plan still loading) contributes nothing.
      final seatIds = seatIdsOf(r);
      if (seatIds.isEmpty) continue;
      var day = DateTime(r.startsAt.year, r.startsAt.month, r.startsAt.day);
      if (day.isBefore(first)) day = first;
      // The +1 day slack keeps the loop bound conservative across time
      // zones; coversRange below is the exact test.
      while (!day.isAfter(last) &&
          day.isBefore(r.endsAt.add(const Duration(days: 1)))) {
        final window = HalfDayWindows.fullDay(day);
        if (r.coversRange(window.start, window.end)) {
          (byDay[day] ??= <String>{}).addAll(seatIds);
        }
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
    return byDay;
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
    this.closed = false,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int? freeSeats;
  final int totalSeats;
  final String label;
  final VoidCallback? onTap;

  /// #814 — a closed day: neutral fill, no heat, the "Closed" label.
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Heat fill: greener the more free, redder the fuller. Neutral when
    // the workspace has no desks yet or the plans are still loading.
    Color fill;
    if (closed && inMonth) {
      fill = scheme.surfaceContainerHighest;
    } else if (!inMonth || freeSeats == null || totalSeats == 0) {
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

    // The heat tints stay LIGHT in the dark theme (the brand containers
    // are light in both schemes) — pick the day number's ink from the
    // ACTUAL blended cell color, not from the theme (contrast).
    final blended = Color.alphaBlend(fill, scheme.surface);
    final onFill = !inMonth
        ? scheme.onSurfaceVariant.withValues(alpha: 0.5)
        : ThemeData.estimateBrightnessForColor(blended) == Brightness.light
            ? Colors.black87
            : scheme.onSurface;

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
