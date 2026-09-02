// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import 'calendar_item_row.dart';

/// #818 — the month as a SELECTOR with a glance: one compact cell per
/// day, up to three markers under the number (one per group that has
/// something that day), today ringed, the selected day filled, closed
/// days muted with a small mark. Tapping a day hands it to [onSelect];
/// the feed below is the content.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.selectedDay,
    required this.today,
    required this.groupsByDay,
    required this.onSelect,
    this.isDayOpen,
    this.locale,
  });

  /// Compact: the grid is a picker, not the content (#478 phone audit).
  static const double cellHeight = 40;

  /// Any day of the month to draw.
  final DateTime month;
  final DateTime selectedDay;
  final DateTime today;

  /// Date-only day → the groups that have at least one fact that day.
  final Map<DateTime, Set<CalendarGroup>> groupsByDay;
  final ValueChanged<DateTime> onSelect;

  /// Whether the workspace is open on a day; null = always open.
  final bool Function(DateTime day)? isDayOpen;
  final String? locale;

  static Key cellKey(DateTime day) => ValueKey(
      'calendar-cell-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final rows = ((leading + daysInMonth) / 7).ceil();
    final weekdayFormat = DateFormat.E(locale);
    return Padding(
      key: const ValueKey('calendar-month-grid'),
      padding: AppSpacing.smH,
      child: Column(children: [
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  // 2026-06-01 is a Monday.
                  weekdayFormat.format(DateTime(2026, 6, 1 + i)).substring(0, 1),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ]),
        for (var row = 0; row < rows; row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: Builder(builder: (context) {
                  final index = row * 7 + col - leading;
                  if (index < 0 || index >= daysInMonth) {
                    return const SizedBox(height: cellHeight);
                  }
                  final day = DateTime(month.year, month.month, index + 1);
                  return _cell(context, scheme, day);
                }),
              ),
          ]),
      ]),
    );
  }

  Widget _cell(BuildContext context, ColorScheme scheme, DateTime day) {
    final selected = DateUtils.isSameDay(day, selectedDay);
    final isToday = DateUtils.isSameDay(day, today);
    final open = isDayOpen?.call(day) ?? true;
    final groups = groupsByDay[day] ?? const <CalendarGroup>{};
    final decoration = selected
        ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle)
        : isToday
            ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primary, width: 1.5),
              )
            : !open
                ? BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  )
                : null;
    return InkWell(
      key: cellKey(day),
      onTap: () => onSelect(day),
      borderRadius: AppRadius.mdAll,
      child: SizedBox(
        height: cellHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: decoration,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: selected
                      ? scheme.onPrimary
                      : open
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                  fontWeight: isToday || selected ? FontWeight.w700 : null,
                  decoration: open ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            SizedBox(
              height: 6,
              child: groups.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final group in CalendarGroup.values)
                          if (groups.contains(group))
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Icon(
                                Icons.circle,
                                key: ValueKey(
                                    'calendar-marker-${day.day}-${group.name}'),
                                size: 5,
                                color: calendarGroupColor(scheme, group),
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// #818 — the three colours, named — under the grid and the strip.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key, this.showClosed = true});

  final bool showClosed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      key: const ValueKey('calendar-legend'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final group in CalendarGroup.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.circle,
                  size: 8, color: calendarGroupColor(scheme, group)),
              const SizedBox(width: AppSpacing.xs),
              Text(calendarGroupLabel(l10n, group), style: style),
            ]),
          if (showClosed)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(l10n?.calendarClosedDay ?? 'Closed', style: style),
            ]),
        ],
      ),
    );
  }
}
