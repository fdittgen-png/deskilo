// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/l10n/lexicon.dart';
import '../../../../core/theme/app_spacing.dart';

/// What the Reserve hub shows.
///
/// [plan] and [list] are two presentations of the SAME booking view — where
/// can I book, for this window — and switch directly. [day], [week] and
/// [month] are time views for exploring, and live behind [ReserveViewMenu].
enum ReserveView {
  plan,
  list,
  day,
  week,
  month;

  /// Whether the window chips act on this view: Plan and its list filter by
  /// the booking window and Day books it on a free-row tap; Week books per
  /// tapped half and Month is an overview, so neither shows them.
  bool get showsWindowControls => this != week && this != month;

  /// Whether the map ↔ list toggle applies: only the two presentations of
  /// the booking view switch between each other.
  bool get showsSeatViewSwitch => this == plan || this == list;

  /// Whether the legend names closed days: the time views draw them.
  bool get legendShowsClosed => this == day || this == week || this == month;
}

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
    this.onGetStarted,
    this.onLegend,
  });

  final ReserveView view;

  /// #1654 — when set, the menu ends with a "Get started" entry that
  /// reopens the dismissed card. Null hides the entry: the menu is the
  /// hub's view chooser first.
  final VoidCallback? onGetStarted;

  /// #3068 — when set, the menu carries a "Colour legend" entry that opens
  /// the seat legend in a sheet. The header row has no room for a fourth
  /// control at 360 dp (#699 pins two rows), so the legend lives with the
  /// other plan controls, here. Null hides the entry (booking gate off).
  final VoidCallback? onLegend;

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
    final l10n = context.l10n;
    String nameOf(ReserveView view) => switch (view) {
          ReserveView.plan || ReserveView.list => lexiconText(context,
              key: 'tabPlan', fallback: l10n.tabPlan),
          ReserveView.day => lexiconText(context,
              key: 'reserveDayView', fallback: l10n.reserveDayView),
          ReserveView.week => lexiconText(context,
              key: 'reserveWeekView',
              fallback: l10n.reserveWeekView),
          ReserveView.month => lexiconText(context,
              key: 'reserveMonthView',
              fallback: l10n.reserveMonthView),
        };
    final current = view == ReserveView.list ? ReserveView.plan : view;
    final currentName = nameOf(current);

    return PopupMenuButton<ReserveView>(
      key: const ValueKey('reserve-view-switch'),
      tooltip: l10n.reserveViewMenu,
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
        if (onLegend != null || onGetStarted != null)
          const PopupMenuDivider(),
        if (onLegend != null)
          PopupMenuItem<ReserveView>(
            key: const ValueKey('reserve-view-legend'),
            onTap: onLegend,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.legend_toggle),
              title: Text(l10n.reserveLegendTooltip),
            ),
          ),
        if (onGetStarted != null) ...[
          PopupMenuItem<ReserveView>(
            key: const ValueKey('reserve-view-get-started'),
            onTap: onGetStarted,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.gettingStartedReopen),
            ),
          ),
        ],
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
              // #1583 — the two icons say what this is and that it
              // opens; the NAME is the part that can give ground when
              // the header strip hands the control less than its
              // natural width (a long lexicon word, twice the text
              // size). Flexible + ellipsis shortens the label rather
              // than pushing the caret off the right edge, and the
              // 48 dp box above keeps the target whole.
              Flexible(
                child: Text(
                  currentName,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}
