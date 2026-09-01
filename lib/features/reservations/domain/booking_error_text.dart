// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../../l10n/app_localizations.dart';
import '../../money/domain/quota_rules.dart';
import '../../workspace/domain/workspace_availability.dart';
import '../../workspace/domain/booking_granularity.dart';
import '../../workspace/domain/booking_policies.dart';
import 'booking_gate.dart';

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
  // #814 — the kiosk's seat-block refusal (kiosk_act) rendered generic.
  if (message.contains('seat is blocked')) {
    return l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.';
  }
  // #649 — the three limits enforce_booking_rules coalesces (#814: they
  // rendered as "the seat may have just been taken").
  if (message.contains('beyond the advance-booking horizon')) {
    return l10n?.bookingHorizonError(_leadingInt(message) ?? 0) ??
        'Too far ahead — bookings are open ${_leadingInt(message) ?? 0} '
            'days in advance.';
  }
  if (message.contains('below the minimum duration')) {
    return l10n?.bookingTooShortError(_leadingInt(message) ?? 0) ??
        'Too short — a booking lasts at least '
            '${_leadingInt(message) ?? 0} minutes.';
  }
  if (message.contains('above the maximum duration')) {
    return l10n?.bookingTooLongError(_leadingInt(message) ?? 0) ??
        'Too long — a booking lasts at most '
            '${_leadingInt(message) ?? 0} minutes.';
  }
  // #644 — a booking ends on the day it starts.
  if (message.contains('must end on the day it starts')) {
    return l10n?.bookingSameDayError ??
        'A booking ends on the day it starts — book the next day '
            'separately.';
  }
  // #600 booking-policy refusals (migration 0116).
  if (message.contains('lies entirely in the past')) {
    return l10n?.bookingPastError ??
        'This booking lies entirely in the past.';
  }
  if (message.contains('must start today')) {
    return l10n?.bookingWalkUpTodayError ??
        'A walk-up check-in must start today.';
  }
  if (message.contains('stay within the working hours')) {
    return l10n?.bookingOutsideHoursError ??
        'Bookings must stay within the working hours.';
  }
  // #634 outside-hours mode 'walkup_only' (migration 0120): the same
  // pinned substring plus 'spontaneous check-in' — checked FIRST, so
  // the member learns the door is only closed for booking AHEAD.
  if (message.contains('spontaneous check-in') &&
      message.contains('outside the opening hours')) {
    return l10n?.bookingOutsideWalkUpError ??
        'Outside the opening hours only a spontaneous check-in is '
            'possible — booking ahead is not.';
  }
  // #624 outside-hours mode 'off' (migration 0118, pinned substring).
  if (message.contains('outside the opening hours')) {
    return l10n?.bookingOutsideOffError ??
        'Bookings outside the opening hours are not allowed.';
  }
  // Presence rule (#408, migration 0077): check-in only inside
  // [starts − 15 min, end).
  if (message.contains('check-in window not open yet')) {
    return l10n?.planCheckInNotYetError ??
        'Check-in opens 15 minutes before the start.';
  }
  if (message.contains('check-in window closed')) {
    return l10n?.planCheckInOverError ??
        'This reservation is over — check-in is no longer possible.';
  }
  // One place at a time (#412, 0079 trigger + check-in guards).
  if (message.contains('you already have a reservation in that period')) {
    return l10n?.bookingOnePlace ??
        'You already have a booking in that period — one place at a time.';
  }
  if (message.contains('already checked in elsewhere')) {
    return l10n?.bookingCheckedInElsewhere ??
        'You are checked in elsewhere — check out there first.';
  }
  // Whole-space paths (0050/0057): grant refusals and occupancy
  // conflicts share these pinned substrings across office and level.
  if (message.contains('not allowed to reserve a level')) {
    return l10n?.levelNotAllowed ??
        'You are not allowed to reserve a whole office or level.';
  }
  // #412: these two rendered as "Something went wrong" — the owner had
  // no way to learn WHICH toggle was missing.
  if (message.contains('not bookable as a whole')) {
    return l10n?.spaceNotWholeBookable ??
        'This space is not set up for whole booking — the owner enables '
            '"Bookable as a whole" on it in the editor.';
  }
  if (message.contains('level booking is not enabled')) {
    return l10n?.levelFeatureOff ??
        'Office & level reservations are switched off in Features.';
  }
  if (message.contains('reservations in that period') ||
      message.contains('already reserved') ||
      message.contains('reserved as a whole')) {
    return l10n?.levelConflict ??
        'The level has reservations in that period.';
  }
  return fallback;
}

/// The number the server put in its message ('... of 90 days').
int? _leadingInt(String message) =>
    int.tryParse(RegExp(r'of (\d+) ').firstMatch(message)?.group(1) ?? '');

/// #814 — the SAME sentences, for a refusal the client foresaw. A
/// surface that asks the gate before acting prints exactly what the
/// server would have answered, so nobody learns two vocabularies.
String bookingRefusalText(
  AppLocalizations? l10n,
  BookingRefusal refusal, {
  required BookingPolicies policies,
  int? stepMinutes,
}) =>
    switch (refusal) {
      BookingRefusal.closedDay =>
        l10n?.planClosedDayError ?? 'The workspace is closed on that day.',
      BookingRefusal.seatBlocked =>
        l10n?.planSeatBlocked ?? 'This seat is blocked for maintenance.',
      BookingRefusal.beyondHorizon =>
        l10n?.bookingHorizonError(policies.advanceHorizonDays) ??
            'Too far ahead — bookings are open '
                '${policies.advanceHorizonDays} days in advance.',
      BookingRefusal.tooShort =>
        l10n?.bookingTooShortError(policies.minDurationMinutes) ??
            'Too short — a booking lasts at least '
                '${policies.minDurationMinutes} minutes.',
      BookingRefusal.tooLong =>
        l10n?.bookingTooLongError(policies.maxDurationMinutes) ??
            'Too long — a booking lasts at most '
                '${policies.maxDurationMinutes} minutes.',
      BookingRefusal.past =>
        l10n?.bookingPastError ?? 'This booking lies entirely in the past.',
      BookingRefusal.walkUpNotToday =>
        l10n?.bookingWalkUpTodayError ?? 'A walk-up check-in must start today.',
      BookingRefusal.crossesMidnight => l10n?.bookingSameDayError ??
          'A booking ends on the day it starts — book the next day '
              'separately.',
      BookingRefusal.outsideHoursOff => l10n?.bookingOutsideOffError ??
          'Bookings outside the opening hours are not allowed.',
      BookingRefusal.outsideHoursAheadOnly =>
        l10n?.bookingOutsideWalkUpError ??
            'Outside the opening hours only a spontaneous check-in is '
                'possible — booking ahead is not.',
    };

/// #622 — whether [error] is an occupancy refusal caused by ANOTHER
/// member's reservation (the pinned others-blocking substrings above;
/// 'you already have a reservation in that period' is the member's OWN
/// booking and deliberately not matched). Surfaces use this to offer
/// contacting the reserver.
bool isBlockedByOtherError(Object error) {
  if (error is! PostgrestException) return false;
  final message = error.message;
  return message.contains('reservations in that period') ||
      message.contains('already reserved') ||
      message.contains('reserved as a whole');
}
