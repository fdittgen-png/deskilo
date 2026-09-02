// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/closure_day.dart';
import '../calendar_view.dart';
import 'calendar_item_row.dart';

/// #818 — the hub's feed, grouped by workspace day. With [relative] on,
/// a day header reads *Today · Wed 2 Sep* rather than a bare date, a
/// closed day says so before its rows, and the empty state names the
/// view ("nothing in the next 30 days", not "nothing on these dates").
class CalendarFeed extends ConsumerWidget {
  const CalendarFeed({
    super.key,
    required this.page,
    required this.names,
    required this.onOpen,
    required this.onRefresh,
    this.view,
    this.today,
    this.days,
    this.closures = const [],
    this.openWeekdays,
    this.relative = false,
    this.coloured = false,
    this.emptyTitle,
  });

  final CalendarPage page;
  final Map<String, String> names;
  final void Function(CalendarItem item) onOpen;
  final Future<void> Function() onRefresh;

  /// The view the feed serves (empty-state wording); null = the plain hub.
  final CalendarView? view;
  final DateTime? today;

  /// The days the feed covers, in order — with [relative] on, every one
  /// of them gets a header, so an empty closed day still says "Closed".
  /// Null = only the days that have items.
  final List<DateTime>? days;
  final List<ClosureDay> closures;
  final List<int>? openWeekdays;
  final bool relative;
  final bool coloured;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = ref.watch(appFormatProvider);
    final byDay = <DateTime, List<CalendarItem>>{};
    for (final item in page.items) {
      final day = WorkspaceTime.dateOf(item.at);
      byDay.putIfAbsent(DateTime(day.year, day.month, day.day), () => []).add(item);
    }
    // Every covered day when asked; otherwise the days that have items.
    final shown = days == null
        ? (byDay.keys.toList()..sort())
        : [
            for (final d in days!)
              if (byDay.containsKey(d) || !_open(d)) d,
          ];
    if (page.items.isEmpty && page.locked.isEmpty && shown.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: emptyTitle ??
            (l10n?.calendarNothingHere ?? 'Nothing on these dates.'),
      );
    }
    final weekday = DateFormat.EEEE(format.locale);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('calendar-feed'),
        children: [
          if (page.locked.isNotEmpty)
            Padding(
              padding: AppSpacing.mdAll,
              child: Row(children: [
                Icon(Icons.lock_outline,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n?.calendarLockedKinds(
                          page.locked
                              .map((k) => calendarKindLabel(l10n, k))
                              .join(', '),
                        ) ??
                        'Not visible to you for this member: '
                            '${page.locked.map((k) => calendarKindLabel(l10n, k)).join(', ')}',
                    key: const ValueKey('calendar-locked'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          if (page.items.isEmpty && shown.every((d) => !byDay.containsKey(d)))
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                emptyTitle ??
                    (l10n?.calendarNothingHere ?? 'Nothing on these dates.'),
                key: const ValueKey('calendar-empty-line'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          for (final day in shown) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _header(l10n, format, weekday, day),
                    key: ValueKey('calendar-day-${day.year}-${day.month}-${day.day}'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: relative && _isToday(day)
                          ? theme.colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                if (relative && !_open(day))
                  Container(
                    key: ValueKey(
                        'calendar-closed-${day.year}-${day.month}-${day.day}'),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      _closedText(l10n, day),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ]),
            ),
            if (relative && !byDay.containsKey(day))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  l10n?.calendarDayEmpty ?? 'Nothing on this day.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            for (final item in byDay[day] ?? const <CalendarItem>[])
              CalendarItemRow(
                item: item,
                memberName: names[item.memberId] ?? '',
                coloured: coloured,
                onTap: () => onOpen(item),
              ),
          ],
        ],
      ),
    );
  }

  bool _isToday(DateTime day) =>
      today != null && relativeDayOf(day, today!) == RelativeDay.today;

  bool _open(DateTime day) {
    final weekdays = openWeekdays;
    if (weekdays != null && !weekdays.contains(day.weekday)) return false;
    return !closures.any((c) =>
        c.day.year == day.year &&
        c.day.month == day.month &&
        c.day.day == day.day);
  }

  String _closedText(AppLocalizations? l10n, DateTime day) {
    final reason = closures
        .where((c) =>
            c.day.year == day.year &&
            c.day.month == day.month &&
            c.day.day == day.day)
        .map((c) => c.reason)
        .firstOrNull;
    if (reason == null || reason.trim().isEmpty) {
      return l10n?.calendarClosedDay ?? 'Closed';
    }
    return l10n?.calendarClosedDayReason(reason) ?? 'Closed — $reason';
  }

  String _header(
    AppLocalizations? l10n,
    dynamic format,
    DateFormat weekday,
    DateTime day,
  ) {
    final noon = WorkspaceTime.at(day.year, day.month, day.day, 12);
    final date = '${weekday.format(day)} ${format.shortDate(noon)}';
    if (!relative || today == null) return format.shortDate(noon) as String;
    return switch (relativeDayOf(day, today!)) {
      RelativeDay.today => '${l10n?.calendarToday ?? 'Today'} · $date',
      RelativeDay.tomorrow => '${l10n?.calendarTomorrow ?? 'Tomorrow'} · $date',
      RelativeDay.yesterday =>
        '${l10n?.calendarYesterday ?? 'Yesterday'} · $date',
      null => date,
    };
  }
}
