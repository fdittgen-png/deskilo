// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/reservation_repository.dart';

/// Outcome of a series booking (spec §5.2): how many instances landed and
/// which dates were skipped (already taken / closed / blocked / over
/// quota). Shared by the Plan tab and the Reserve hub so a series booked
/// from either place reports identically.
Future<void> showSeriesResultDialog(
  BuildContext context,
  SeriesResult result,
) {
  final l10n = AppLocalizations.of(context);
  final dateFormat = DateFormat.MMMEd();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        l10n?.seriesBookedCount(result.booked.length) ??
            '${result.booked.length} bookings created',
      ),
      content: result.skipped.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n?.seriesSkippedTitle ?? 'Skipped (already taken):'),
                const SizedBox(height: 8),
                for (final d in result.skipped)
                  Text(dateFormat.format(d.toLocal())),
              ],
            ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonOk ?? 'OK'),
        ),
      ],
    ),
  );
}
