// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/l10n/lexicon.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// What the Reserve hub shows.
///
/// [plan] and [list] are two presentations of the SAME booking view — where
/// can I book, for this window — and switch directly. [day], [week] and
/// [month] are time views for exploring, and live behind [ReserveViewMenu].
enum ReserveView { plan, list, day, week, month }

/// #1301 S2 — the time views behind ONE named control.
///
/// Four equal segments presented Plan, Day, Week and Month as four equal
/// ways to book, and put three exploration views in competition with the
/// booking surface a member came for. The control now names what you are
/// looking at ("Plan ▾") and opens the list of views; plan ↔ list stays
/// the direct toggle beside it, because that one changes only how the
/// same availability is drawn.
///
/// No text of its own beyond the menu's name: the view names are the
/// existing (lexicon-aware) tab and view labels.
class ReserveViewMenu extends StatelessWidget {
  const ReserveViewMenu({
    super.key,
    required this.view,
    required this.onChanged,
  });

  final ReserveView view;

  /// Called with the chosen view; choosing the one already shown does not
  /// fire, so choosing Plan from the list presentation keeps the list.
  final ValueChanged<ReserveView> onChanged;

  static const menuViews = [
    ReserveView.plan,
    ReserveView.day,
    ReserveView.week,
    ReserveView.month,
  ];

  static IconData iconOf(ReserveView view) => switch (view) {
        // The Plan TAB's former icon — not a map (the list/map button
        // beside this control owns that) and not a seat (the raised
        // Reserve button owns that).
        ReserveView.plan || ReserveView.list => Icons.grid_view_outlined,
        ReserveView.day => Icons.view_timeline_outlined,
        ReserveView.week => Icons.view_week_outlined,
        ReserveView.month => Icons.calendar_month_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String nameOf(ReserveView view) => switch (view) {
          ReserveView.plan || ReserveView.list => lexiconText(context,
              key: 'tabPlan', fallback: l10n?.tabPlan ?? 'Plan'),
          ReserveView.day => lexiconText(context,
              key: 'reserveDayView', fallback: l10n?.reserveDayView ?? 'Day'),
          ReserveView.week => lexiconText(context,
              key: 'reserveWeekView',
              fallback: l10n?.reserveWeekView ?? 'Week'),
          ReserveView.month => lexiconText(context,
              key: 'reserveMonthView',
              fallback: l10n?.reserveMonthView ?? 'Month'),
        };
    final current = view == ReserveView.list ? ReserveView.plan : view;
    final currentName = nameOf(current);

    return PopupMenuButton<ReserveView>(
      key: const ValueKey('reserve-view-switch'),
      tooltip: l10n?.reserveViewMenu ?? 'View',
      initialValue: current,
      onSelected: (chosen) {
        if (chosen != current) onChanged(chosen);
      },
      itemBuilder: (context) => [
        for (final option in menuViews)
          PopupMenuItem<ReserveView>(
            key: ValueKey('reserve-view-${option.name}'),
            value: option,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(iconOf(option)),
              title: Text(nameOf(option)),
              trailing: option == current ? const Icon(Icons.check) : null,
            ),
          ),
      ],
      // 48dp both ways: the header row is scrollable precisely so no
      // control shrinks under the touch-target floor (#284).
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconOf(current)),
              const SizedBox(width: AppSpacing.xs),
              Text(currentName),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
