// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the calendar at the desk: a week, a day and a month that
// use the monitor, with the booking beside them. The period, the view and the
// open booking are the address (`/calendar?view=week&day=…&res=…`), so a
// reload or a link opens the same thing; the keys T, ← →, D / W / M and N come
// from the registry. Below the large window class the calendar branch draws
// the phone's hub instead (unchanged).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_format.dart';
import '../../core/i18n/format_controller.dart';
import '../../core/i18n/week_start.dart';
import '../../core/l10n/context_l10n.dart';
import '../../core/shortcuts/app_shortcuts.dart';
import '../../core/shortcuts/shortcut_scope.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/time/clock.dart';
import '../../core/ui/loading_view.dart';
import '../../features/calendar/presentation/screens/calendar_hub_screen.dart';
import '../../features/calendar/providers/calendar_view_request.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'desk_calendar.dart';
import 'desk_calendar_body.dart';

/// The key of the Today button.
const Key _deskTodayKey = ValueKey('desk-today');

/// The key of the view choice (day, week, month).
const Key _deskViewKey = ValueKey('desk-view');

/// The key of the mode choice (calendar, all bookings, agenda).
const Key _deskModeKey = ValueKey('desk-mode');

class DeskCalendarPage extends ConsumerWidget {
  const DeskCalendarPage({required this.query, super.key});

  /// The address' query (`view`, `day`, `mode`, `res`).
  final Map<String, String> query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(readyWorkspaceContextProvider)?.calendar;
    if (calendar == null) return const LoadingView();
    final today = calendar.dateOf(ref.watch(clockProvider).now());
    final parsed = DeskCalendarAddress.parse(query, today: today);
    // The bell and a link to the alerts ask for the hub's Alerts view.
    final alerts = ref.watch(calendarAlertsRequestProvider);
    final address = alerts && parsed.mode != DeskMode.agenda
        ? parsed.copyWith(mode: DeskMode.agenda)
        : parsed;
    void go(DeskCalendarAddress next) => context.go(next.location);
    return ShortcutScope(
      handlers: address.mode == DeskMode.agenda ? const {} : {
        AppShortcutId.today: () => go(address.copyWith(day: today)),
        AppShortcutId.previousPeriod: () => go(
          address.copyWith(
            day: shiftDeskAnchor(address.view, address.day, -1),
          ),
        ),
        AppShortcutId.nextPeriod: () => go(
          address.copyWith(day: shiftDeskAnchor(address.view, address.day, 1)),
        ),
        AppShortcutId.viewDay: () => go(address.copyWith(view: DeskView.day)),
        AppShortcutId.viewWeek: () => go(address.copyWith(view: DeskView.week)),
        AppShortcutId.viewMonth: () =>
            go(address.copyWith(view: DeskView.month)),
      },
      child: Scaffold(
        body: Column(
          children: [
            _Header(address: address, today: today, go: go),
            Expanded(
              child: address.mode == DeskMode.agenda
                  ? const CalendarHubScreen()
                  : DeskCalendarBody(address: address, calendar: calendar),
            ),
          ],
        ),
      ),
    );
  }
}

/// Period, view and mode: the controls above the grid.
class _Header extends ConsumerWidget {
  const _Header({required this.address, required this.today, required this.go});

  final DeskCalendarAddress address;
  final DateTime today;
  final void Function(DeskCalendarAddress next) go;

  String _label(BuildContext context, AppFormat format, int firstWeekday) {
    final span = deskSpanOf(address.view, address.day, firstWeekday);
    return switch (address.view) {
      DeskView.day => format.dates(DateShape.weekdayMonthDay).format(address.day),
      DeskView.week =>
        '${format.dates(DateShape.monthDay).format(span.from)} – '
            '${format.dates(DateShape.monthDay).format(DateTime(span.to.year, span.to.month, span.to.day - 1))}',
      DeskView.month => format.dates(DateShape.monthYear).format(address.day),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final agenda = address.mode == DeskMode.agenda;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!agenda) ...[
            IconButton(
              key: const ValueKey('calendar-prev'),
              tooltip: l10n.calendarPrevious,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => go(
                address.copyWith(
                  day: shiftDeskAnchor(address.view, address.day, -1),
                ),
              ),
            ),
            Text(
              _label(context, format, weekStartOf(format)),
              key: const ValueKey('calendar-period-label'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              key: const ValueKey('calendar-next'),
              tooltip: l10n.calendarNext,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => go(
                address.copyWith(
                  day: shiftDeskAnchor(address.view, address.day, 1),
                ),
              ),
            ),
            TextButton(
              key: _deskTodayKey,
              onPressed: () => go(address.copyWith(day: today)),
              child: Text(l10n.calendarToday),
            ),
            SegmentedButton<DeskView>(
              key: _deskViewKey,
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: DeskView.day,
                  label: Text(l10n.calendarDay),
                ),
                ButtonSegment(
                  value: DeskView.week,
                  label: Text(l10n.calendarViewWeek),
                ),
                ButtonSegment(
                  value: DeskView.month,
                  label: Text(l10n.reserveMonthView),
                ),
              ],
              selected: {address.view},
              onSelectionChanged: (s) => go(address.copyWith(view: s.first)),
            ),
          ],
          SegmentedButton<DeskMode>(
            key: _deskModeKey,
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: DeskMode.grid,
                icon: const Icon(Icons.calendar_view_week_outlined),
                label: Text(l10n.tabCalendar),
              ),
              ButtonSegment(
                value: DeskMode.table,
                icon: const Icon(Icons.table_rows_outlined),
                label: Text(l10n.calendarDeskModeTable),
              ),
              ButtonSegment(
                value: DeskMode.agenda,
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text(l10n.calendarViewAgenda),
              ),
            ],
            selected: {address.mode},
            onSelectionChanged: (s) => go(address.copyWith(mode: s.first)),
          ),
        ],
      ),
    );
  }
}
