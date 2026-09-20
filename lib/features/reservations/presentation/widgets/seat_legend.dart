// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../../core/l10n/lexicon.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/theme/seat_legend_profile.dart';
import '../../../../l10n/app_localizations.dart';

/// #814 — the seat states, named. The plan, the day, the week and the
/// month views paint five states plus "closed day"; until now the only
/// place that said which colour meant what was the guide. One compact
/// row of swatches with their words, so a member reads the plan
/// without learning it first.
class SeatLegend extends StatelessWidget {
  const SeatLegend({
    super.key,
    this.showClosed = true,
    this.profile = LegendProfile.full,
  });

  /// Whether the "closed day" entry belongs on this view (the month and
  /// week grids draw closed days; the plan shows a banner instead).
  final bool showClosed;

  /// #1281 — how many states this space tells apart. The entries below
  /// are the DISTINCT groups `legendGroupOf` produces, so the legend
  /// cannot list a word the canvas does not paint, or omit a colour it
  /// does.
  final LegendProfile profile;

  /// The states this legend speaks about, before grouping.
  List<SeatStateKind> get _states => [
        SeatStateKind.free,
        SeatStateKind.reserved,
        SeatStateKind.occupied,
        SeatStateKind.mine,
        SeatStateKind.blocked,
        if (showClosed) SeatStateKind.closed,
      ];

  /// The groups a member actually sees, in order, each once.
  List<SeatGroup> get groups {
    final seen = <SeatGroup>[];
    for (final state in _states) {
      final group = legendGroupOf(state, profile);
      if (!seen.contains(group)) seen.add(group);
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final entries = <(String, Color, IconData?)>[
      for (final group in groups) _describe(context, l10n, group, scheme, brightness),
    ];

    // #1183 — a Wrap, not a horizontal scroller. Sideways, the legend
    // sits in a 260 dp side panel and the scroller cut it mid-word:
    // "Free · Reserved · Checked in · M…". Scrolling is the wrong
    // answer for a legend in any case — nothing in it is tappable, so
    // an entry you have to find by dragging is an entry you never read.
    //
    // #1269 — but a legend that wraps is a legend that lies about
    // itself: "Blocked" alone on a second line reads as a heading for
    // what is under it, not as the fifth of five equals. On a 360 dp
    // phone the five plan states needed 361 dp of the 328 available,
    // so it spilled by one entry every time. Two changes: the chrome
    // per entry went 30 dp → 23 (a 12 dp swatch, a 3 dp gap, an 8 dp
    // separator, none after the last), which alone brings the five to
    // 318; and whatever still does not fit — six entries, a German
    // "Geschlossener Tag", a 320 dp screen — is scaled down to the one
    // row rather than folded onto a second.
    //
    // The scale-down is skipped when the reader has asked for larger
    // text: shrinking it back would hand them exactly the size they
    // said was too small. They get the honest two lines instead.
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, (label, color, icon)) in entries.indexed)
          Padding(
            padding: EdgeInsets.only(
                right: index == entries.length - 1 ? 0 : AppSpacing.sm),
            child: _entry(context, label, color, icon),
          ),
      ],
    );
    final enlarged = MediaQuery.textScalerOf(context).scale(100) > 115;
    return Padding(
      key: const ValueKey('reserve-legend'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: enlarged
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final (label, color, icon) in entries)
                  _entry(context, label, color, icon),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: row,
              ),
            ),
    );
  }

  /// One group's word, colour and icon. The words come from the
  /// lexicon (#1277) so a space that calls a seat «Place» reads
  /// «Place libre» here without a second hardcoded string set.
  (String, Color, IconData?) _describe(
    BuildContext context,
    AppLocalizations? l10n,
    SeatGroup group,
    ColorScheme scheme,
    Brightness brightness,
  ) {
    Color colorOf(SeatState state) =>
        SeatStateColors.of(state, brightness: brightness);
    String word(String key, String fallback) =>
        lexiconText(context, key: key, fallback: fallback);

    return switch (group) {
      SeatGroup.free => (
          word('legendFree', l10n?.legendFree ?? 'Free'),
          colorOf(SeatState.free),
          null,
        ),
      SeatGroup.reserved => (
          word('legendReserved', l10n?.legendReserved ?? 'Reserved'),
          colorOf(SeatState.reserved),
          null,
        ),
      SeatGroup.occupied => (
          word('legendOccupied', l10n?.legendOccupied ?? 'Checked in'),
          colorOf(SeatState.occupied),
          Icons.check,
        ),
      SeatGroup.mine => (
          word('legendMine', l10n?.legendMine ?? 'Mine'),
          colorOf(SeatState.mine),
          Icons.person,
        ),
      SeatGroup.blocked => (
          word('legendBlocked', l10n?.legendBlocked ?? 'Blocked'),
          colorOf(SeatState.blocked),
          Icons.block,
        ),
      SeatGroup.closed => (
          word('legendClosed', l10n?.legendClosed ?? 'Closed day'),
          scheme.surfaceContainerHighest,
          Icons.event_busy_outlined,
        ),
      // #1281 — one word for blocked AND closed, which is why it is not
      // called «blocked»: under the simple profile the two are the same
      // answer to a member, «you cannot have this».
      SeatGroup.unavailable => (
          word('legendUnavailable', l10n?.legendUnavailable ?? 'Unavailable'),
          colorOf(SeatState.blocked),
          Icons.block,
        ),
    };
  }

  Widget _entry(
    BuildContext context,
    String label,
    Color color,
    IconData? icon,
  ) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.smAll,
          ),
          child: icon == null
              ? null
              : Icon(icon, size: 9, color: Colors.white),
        ),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]);
}
