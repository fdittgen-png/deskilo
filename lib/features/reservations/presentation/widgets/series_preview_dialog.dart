// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2575 -- before a series is booked, the dates that would fail are named
// and the person chooses: book the others, or nothing. A partial series is
// never silent (spec §5.2).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/workspace_time.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../domain/series_preview.dart';
import 'booking_sheet.dart';

/// Whether to book [ask] (null: not a series, nothing to ask): true when every date would book or the person
/// chose to book the others; false when they cancelled or none would book.
/// A preview that cannot be read does not block: the server re-checks and
/// the result dialog still names every skipped date.
Future<bool> confirmSeriesPreview(
  BuildContext context,
  SeriesPreviewer Function() previewer,
  SeriesAsk? ask,
) async {
  if (ask == null) return true;
  final ({int booked, List<DateTime> failing}) preview;
  try {
    final run = await previewer().preview(ask);
    preview = (booked: run.booked.length, failing: run.skipped);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'reservations',
      'series preview unavailable: $e',
      stackTrace: st,
    );
    return true;
  }
  if (preview.failing.isEmpty) return true;
  if (!context.mounted) return false;
  final l10n = context.l10n;
  final dateFormat = DateFormat.MMMEd();
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('series-preview-dialog'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.seriesPreviewFailing),
          const SizedBox(height: AppSpacing.sm),
          for (final d in preview.failing)
            Text(dateFormat.format(WorkspaceTime.dateOf(d))),
          if (preview.booked == 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.seriesPreviewNone),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('series-preview-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        if (preview.booked > 0)
          FilledButton(
            key: const ValueKey('series-preview-book-others'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.seriesPreviewBookOthers(preview.booked)),
          ),
      ],
    ),
  );
  return go ?? false;
}

/// The repeat [choice] asks for on [seatId], when the person books it for
/// themselves; null for a single booking or one made for someone else.
SeriesAsk? ownSeriesAsk(
  BookingChoice choice,
  String workspaceId,
  String seatId,
  String? myMemberId,
) {
  final pattern = choice.pattern;
  final until = choice.until;
  if (pattern == null || until == null) return null;
  if (choice.forMemberId != null && choice.forMemberId != myMemberId) {
    return null;
  }
  return SeriesAsk(
    workspaceId: workspaceId,
    seatId: seatId,
    firstStart: choice.start,
    firstEnd: choice.end,
    pattern: pattern,
    until: until,
  );
}
