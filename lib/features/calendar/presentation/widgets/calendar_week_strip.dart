// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'calendar_item_row.dart';

/// #818 — the week as a strip: seven pills, Monday to Sunday, each with
/// its weekday, its number, its markers and a count. Tapping a pill
/// scrolls the feed to that day (the caller decides); the whole week is
/// loaded below.
class CalendarWeekStrip extends StatelessWidget {
  const CalendarWeekStrip({
    super.key,
    required this.weekStart,
    required this.selectedDay,
    required this.today,
    required this.groupsByDay,
    required this.countsByDay,
    required this.onSelect,
    this.isDayOpen,
    this.locale,
  });

  final DateTime weekStart;
  final DateTime selectedDay;
  final DateTime today;
  final Map<DateTime, Set<CalendarGroup>> groupsByDay;
  final Map<DateTime, int> countsByDay;
  final ValueChanged<DateTime> onSelect;
  final bool Function(DateTime day)? isDayOpen;
  final String? locale;

  static Key pillKey(DateTime day) =>
      ValueKey('calendar-week-${day.year}-${day.month}-${day.day}');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final weekdayFormat = DateFormat.E(locale);
    return Padding(
      key: const ValueKey('calendar-week-strip'),
      padding: AppSpacing.smH,
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(builder: (context) {
              final day = DateTime(
                  weekStart.year, weekStart.month, weekStart.day + i);
              final selected = DateUtils.isSameDay(day, selectedDay);
              final isToday = DateUtils.isSameDay(day, today);
              final open = isDayOpen?.call(day) ?? true;
              final groups = groupsByDay[day] ?? const <CalendarGroup>{};
              final count = countsByDay[day] ?? 0;
              return Padding(
                padding: const EdgeInsets.all(2),
                child: Material(
                  color: selected
                      ? scheme.primaryContainer
                      : open
                          ? Colors.transparent
                          : scheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: isToday
                        ? BorderSide(color: scheme.primary, width: 1.5)
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: pillKey(day),
                    onTap: () => onSelect(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Column(children: [
                        Text(
                          weekdayFormat.format(day).substring(0, 1),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isToday || selected
                                ? FontWeight.w700
                                : null,
                            decoration:
                                open ? null : TextDecoration.lineThrough,
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
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 1),
                                          child: Icon(
                                            Icons.circle,
                                            size: 5,
                                            color: calendarGroupColor(
                                                scheme, group),
                                          ),
                                        ),
                                  ],
                                ),
                        ),
                        Text(
                          count == 0 ? '' : '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ),
      ]),
    );
  }
}
