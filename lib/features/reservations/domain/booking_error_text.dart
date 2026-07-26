// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../l10n/app_localizations.dart';
import '../../money/domain/quota_rules.dart';
import '../../workspace/domain/workspace_availability.dart';
import '../../workspace/domain/booking_granularity.dart';

/// THE booking-failure → user-message mapper (maintainability audit:
/// this switch was pasted, and drifting, across four screens). Maps the
/// server's pinned error substrings to their localized explanations;
/// anything unmapped falls back to [fallback].
///
/// Order matters once: quota before granularity, because 'half-day
/// quota' also contains the granularity substring 'half-day'.
String bookingErrorText(
  AppLocalizations? l10n,
  Object error,
  String fallback, {
  int? stepMinutes,
}) {
  if (error is! PostgrestException) return fallback;
  final message = error.message;
  if (message.contains(WorkspaceClosedError.serverSubstring)) {
    return l10n?.planClosedDayError ??
        'The workspace is closed on that day.';
  }
  if (message.contains(QuotaExceededError.serverSubstring)) {
    return l10n?.quotaExceededError ??
        'Monthly half-day quota reached — request extra half-days '
            'from the Money tab.';
  }
  if (message.contains(ReservationLimitError.serverSubstring)) {
    return l10n?.reservationLimitError ??
        'Reservation limit reached — you already hold the maximum '
            'number of open reservations.';
  }
  if (message.contains(BookingGranularityError.serverSubstring)) {
    return l10n?.planHalfDayError ?? 'Bookings here are per half day.';
  }
  if (message.contains(BookingGranularityError.fullDayServerSubstring)) {
    return l10n?.planFullDayError ?? 'Bookings here cover the full day.';
  }
  if (message.contains(BookingGranularityError.slotServerSubstring)) {
    final step = stepMinutes ?? 15;
    return l10n?.planSlotError(step) ??
        'Bookings must start and end on the $step-minute grid.';
  }
  // Whole-space paths (0050/0057): grant refusals and occupancy
  // conflicts share these pinned substrings across office and level.
  if (message.contains('not allowed to reserve a level')) {
    return l10n?.levelNotAllowed ??
        'You are not allowed to reserve a whole office or level.';
  }
  if (message.contains('reservations in that period') ||
      message.contains('already reserved') ||
      message.contains('reserved as a whole')) {
    return l10n?.levelConflict ??
        'The level has reservations in that period.';
  }
  return fallback;
}
