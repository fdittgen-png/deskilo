// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two pickers of a booking's edit flow, moved out of
// reservation_detail_actions.dart unchanged (#3843): the repeat modality
// and the half-day window.
import 'package:flutter/material.dart';

import '../../../../core/l10n/lexicon.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/reservation_repository.dart';

/// Repeat-modality picker for the edit flow (spec §5.2): the same
/// choices as the booking sheet's Repeat dropdown, as tappable rows.
Future<SeriesPattern?> pickSeriesPattern(
  BuildContext context,
  AppLocalizations l10n,
) {
  Widget row(String key, SeriesPattern? p, String label, IconData icon) =>
      ListTile(
        key: ValueKey(key),
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.of(context).pop(p),
      );
  return showAppSheet<SeriesPattern?>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row('edit-repeat-none', null, l10n.repeatNone, Icons.event_outlined),
          row(
            'edit-repeat-daily',
            SeriesPattern.daily,
            l10n.repeatDaily,
            Icons.repeat,
          ),
          row(
            'edit-repeat-weekdays',
            SeriesPattern.weekdays,
            l10n.repeatWeekdays,
            Icons.work_outline,
          ),
          row(
            'edit-repeat-weekly',
            SeriesPattern.weekly,
            l10n.repeatWeekly,
            Icons.view_week_outlined,
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// The half-day window to book: [morning], [afternoon] or [fullDay] of the
/// day, as the caller builds them.
Future<T?> pickHalfDayWindow<T>(
  BuildContext context,
  AppLocalizations l10n, {
  required T morning,
  required T afternoon,
  required T fullDay,
}) {
  return showAppSheet<T>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('edit-window-am'),
            leading: const Icon(Icons.wb_twilight_outlined),
            title: Text(
              lexiconText(
                context,
                key: 'planMorningChip',
                fallback: l10n.planMorningChip,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(morning),
          ),
          ListTile(
            key: const ValueKey('edit-window-pm'),
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(
              lexiconText(
                context,
                key: 'planAfternoonChip',
                fallback: l10n.planAfternoonChip,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(afternoon),
          ),
          ListTile(
            key: const ValueKey('edit-window-day'),
            leading: const Icon(Icons.today_outlined),
            title: Text(
              lexiconText(
                context,
                key: 'reserveFullDayChip',
                fallback: l10n.reserveFullDayChip,
              ),
            ),
            onTap: () => Navigator.of(sheetContext).pop(fullDay),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
