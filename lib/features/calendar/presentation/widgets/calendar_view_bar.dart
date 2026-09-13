// SPDX-License-Identifier: 0BSD
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
  });

  final CalendarView view;
  final ValueChanged<CalendarView> onView;
  final VoidCallback onToday;

  /// #1183 — below this, the three view labels no longer fit side by
  /// side and the switcher shows icons alone. Measured from the widest
  /// of the five languages ("Wochenansicht" is the German week label),
  /// plus Material's own segment padding.
  static const double _labelWidth = 280;

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
                final labelled = constraints.maxWidth >= _labelWidth;
                Widget? label(String text) => labelled
                    ? Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)
                    : null;
                return SegmentedButton<CalendarView>(
                  key: const ValueKey('calendar-view-switch'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: CalendarView.agenda,
                      icon: const Icon(Icons.view_agenda_outlined),
                      label: label(l10n?.calendarViewAgenda ?? 'Agenda'),
                      tooltip: l10n?.calendarViewAgenda ?? 'Agenda',
                    ),
                    ButtonSegment(
                      value: CalendarView.week,
                      icon: const Icon(Icons.view_week_outlined),
                      label: label(l10n?.calendarViewWeek ?? 'Week'),
                      tooltip: l10n?.calendarViewWeek ?? 'Week',
                    ),
                    ButtonSegment(
                      value: CalendarView.month,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: label(l10n?.calendarViewMonth ?? 'Month'),
                      tooltip: l10n?.calendarViewMonth ?? 'Month',
                    ),
                  ],
                  selected: {view},
                  onSelectionChanged: (s) => onView(s.first),
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
