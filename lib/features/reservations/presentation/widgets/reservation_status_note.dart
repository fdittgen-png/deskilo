// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../domain/reservation.dart';
import '../../domain/reservation_note.dart';

/// The line under a reservation's place that says why it is not an
/// upcoming booking ([reservationNoteOf]): recorded after its period,
/// checked out at a time, or over without a check-in. Nothing otherwise.
class ReservationStatusNote extends StatelessWidget {
  const ReservationStatusNote({
    super.key,
    required this.reservation,
    required this.now,
  });

  final Reservation reservation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final note = reservationNoteOf(reservation, now);
    if (note == null) return const SizedBox.shrink();
    // English from the catalogue itself, not a second copy inline.
    final words = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final text = switch (note) {
      ReservationNote.recordedAfterEnd => words.reservationNoteRecordedAfterEnd,
      ReservationNote.checkedOut => words.reservationNoteCheckedOutAt(
        appFormatOf(context).time(reservation.checkedOutAt!),
      ),
      ReservationNote.overNotCheckedIn => words.reservationNoteOverNotCheckedIn,
    };
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        key: ValueKey('reservation-note-${note.name}'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            note == ReservationNote.overNotCheckedIn
                ? Icons.event_busy_outlined
                : Icons.history,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
