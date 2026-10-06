// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../calendar_view.dart';

/// The calendar hub's view switcher and its Today button.
///
/// Extracted from the hub screen (#1183): it grew a `LayoutBuilder` so
/// the labels can give way sideways, and the screen it sat in was
/// already at its length budget.
class CalendarViewBar extends StatelessWidget {
  const CalendarViewBar({
    super.key,
    required this.view,
    required this.onView,
    required this.onToday,
    this.alertsAvailable = false,
    this.alertsSelected = false,
    this.onAlerts,
    this.alertsCount = 0,
  });

  final CalendarView view;
  final ValueChanged<CalendarView> onView;
  final VoidCallback onToday;

  /// The calendar is also where alerts and events live: a fourth view.
  final bool alertsAvailable;
  final bool alertsSelected;
  final VoidCallback? onAlerts;

  /// What waits for a decision — shown on the Alerts segment.
  final int alertsCount;

  static const _alerts = '__alerts__';

  /// #1183 — below this, the three view labels no longer fit side by
  /// side and the switcher shows icons alone. Measured from the widest
  /// of the five languages ("Wochenansicht" is the German week label),
  /// plus Material's own segment padding.
  static const double _labelWidth = 280;

  /// Four segments (the Alerts view is offered) need more room.
  static const double _labelWidthFour = 400;

  // ── flag ON: the views ─────────────────────────────────────────────
  @override
    Widget build(BuildContext context) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, 0),
        child: Row(children: [
          Expanded(
            // #1183 — sideways, the split layout gives this row about a
            // third of the width it has in portrait, and Material
            // answered by wrapping the labels MID-WORD: "Agen / da",
            // "Mont / h". Below the width the three labels need, the
            // switcher drops to icons and keeps its tooltips — the
            // labels were never the affordance, the icons are.
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Room for every label: show them all. Otherwise only the
                // selected view names itself and the others are icons —
                // the way a compact segmented control reads on a phone.
                final labelled = constraints.maxWidth >=
                    (alertsAvailable ? _labelWidthFour : _labelWidth);
                final current = alertsSelected ? _alerts : view;
                Widget? labelFor(Object value, String text) =>
                    labelled || value == current
                        ? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null;
                return SegmentedButton<Object>(
                  key: const ValueKey('calendar-view-switch'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: CalendarView.agenda,
                      icon: const Icon(Icons.view_agenda_outlined),
                      label: labelFor(CalendarView.agenda, l10n?.calendarViewAgenda ?? 'Agenda'),
                      tooltip: l10n?.calendarViewAgenda ?? 'Agenda',
                    ),
                    ButtonSegment(
                      value: CalendarView.week,
                      icon: const Icon(Icons.view_week_outlined),
                      label: labelFor(CalendarView.week, l10n?.calendarViewWeek ?? 'Week'),
                      tooltip: l10n?.calendarViewWeek ?? 'Week',
                    ),
                    ButtonSegment(
                      value: CalendarView.month,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: labelFor(CalendarView.month, l10n?.calendarViewMonth ?? 'Month'),
                      tooltip: l10n?.calendarViewMonth ?? 'Month',
                    ),
                    if (alertsAvailable)
                      ButtonSegment(
                        value: _alerts,
                        icon: alertsCount > 0
                            ? Badge.count(
                                count: alertsCount,
                                child: const Icon(Icons.notifications_outlined),
                              )
                            : const Icon(Icons.notifications_outlined),
                        label: labelFor(_alerts, l10n?.calendarViewAlerts ?? 'Alerts'),
                        tooltip: l10n?.calendarViewAlerts ?? 'Alerts',
                      ),
                  ],
                  selected: {alertsSelected ? _alerts : view},
                  onSelectionChanged: (s) {
                    final next = s.first;
                    if (next == _alerts) {
                      onAlerts?.call();
                    } else {
                      onView(next as CalendarView);
                    }
                  },
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('calendar-today'),
            tooltip: l10n?.calendarToday ?? 'Today',
            icon: const Icon(Icons.today_outlined),
            onPressed: onToday,
          ),
        ]),
    );
  }
}
