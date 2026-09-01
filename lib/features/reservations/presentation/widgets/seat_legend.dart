// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/seat_state_colors.dart';
import '../../../../l10n/app_localizations.dart';

/// #814 — the seat states, named. The plan, the day, the week and the
/// month views paint five states plus "closed day"; until now the only
/// place that said which colour meant what was the guide. One compact,
/// horizontally scrolling row of swatches with their words, so a
/// member reads the plan without learning it first.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, this.showClosed = true});

  /// Whether the "closed day" entry belongs on this view (the month and
  /// week grids draw closed days; the plan shows a banner instead).
  final bool showClosed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final entries = <(String, Color, IconData?)>[
      (
        l10n?.legendFree ?? 'Free',
        SeatStateColors.of(SeatState.free, brightness: brightness),
        null,
      ),
      (
        l10n?.legendReserved ?? 'Reserved',
        SeatStateColors.of(SeatState.reserved, brightness: brightness),
        null,
      ),
      (
        l10n?.legendOccupied ?? 'Checked in',
        SeatStateColors.of(SeatState.occupied, brightness: brightness),
        Icons.check,
      ),
      (
        l10n?.legendMine ?? 'Mine',
        SeatStateColors.of(SeatState.mine, brightness: brightness),
        Icons.person,
      ),
      (
        l10n?.legendBlocked ?? 'Blocked',
        SeatStateColors.of(SeatState.blocked, brightness: brightness),
        Icons.block,
      ),
      if (showClosed)
        (
          l10n?.legendClosed ?? 'Closed day',
          scheme.surfaceContainerHighest,
          Icons.event_busy_outlined,
        ),
    ];
    return SingleChildScrollView(
      key: const ValueKey('reserve-legend'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Row(children: [
        for (final (label, color, icon) in entries)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadius.smAll,
                ),
                child: icon == null
                    ? null
                    : Icon(icon, size: 10, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
      ]),
    );
  }
}
