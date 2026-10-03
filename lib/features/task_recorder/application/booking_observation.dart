// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — the booking adapter: what the recorder may say about a
// booking, derived from what the member asked for and from what the
// booking command (reservations/application/book_seat.dart) actually
// returned or threw. Pure: no provider, no widget, no clock.
//
// Only categories leave here. Whom a booking is for becomes "self" or
// "another member", never the member; a refusal becomes "a conflict" or
// "a policy", never the server's words; a reservation id never appears.

import 'dart:async';

import '../../../core/trace/trace_logger.dart' show isTransientNetworkFailure;
import '../../reservations/application/book_seat.dart';
import '../domain/action_registry.dart';

/// One observation to hand to the recorder.
typedef Observation = ({String outcome, Map<String, Object?> payload});

/// The attempt's payload: what was asked for, as categories.
Map<String, Object?> bookingAttemptPayload({
  required bool forSomeoneElse,
  required bool series,
  required bool checkIn,
}) =>
    {
      'for_whom': forSomeoneElse ? 'other_member' : 'self',
      'repeat': series ? 'series' : 'once',
      'check_in': checkIn ? 'yes' : 'no',
    };

/// What a returned [BookingOutcome] says.
Observation bookingOutcomeObservation(BookingOutcome outcome) =>
    switch (outcome) {
      Booked(:final checkedIn) => (
          outcome: RecorderOutcomes.bookingConfirmed,
          payload: {'check_in': checkedIn ? 'yes' : 'no'},
        ),
      SentForConfirmation() => (
          outcome: RecorderOutcomes.bookingRequested,
          payload: const <String, Object?>{},
        ),
      SeriesBooked(:final result) => (
          outcome: RecorderOutcomes.seriesBooked,
          payload: {
            'series_result':
                result.skipped.isEmpty ? 'all_booked' : 'partially_booked',
          },
        ),
    };

/// What a thrown error says. A lost connection or a timeout is an
/// outcome nobody can vouch for: the booking may or may not exist. Any
/// other error is the server refusing, sorted into a category by its
/// code or wording — which is then thrown away.
Observation bookingErrorObservation(Object error) {
  if (error is TimeoutException || isTransientNetworkFailure(error)) {
    return (
      outcome: RecorderOutcomes.bookingUnknown,
      payload: const <String, Object?>{},
    );
  }
  return (
    outcome: RecorderOutcomes.bookingRefused,
    payload: {'refusal': refusalCategory(error)},
  );
}

/// The refusal category of a server error.
String refusalCategory(Object error) {
  final text = error.toString().toLowerCase();
  bool any(List<String> marks) => marks.any(text.contains);
  if (any(['23p01', 'overlap', 'conflict', 'already booked', 'already reserved', 'taken'])) {
    return 'conflict';
  }
  if (any(['quota', 'allowance', 'simultaneous', 'limit'])) return 'quota';
  if (any(['closed', 'opening hours', 'outside the opening'])) {
    return 'closed';
  }
  if (any(['42501', 'permission', 'not allowed', 'not an admin', 'forbidden'])) {
    return 'permission';
  }
  if (any(['policy', 'horizon', 'past', 'duration', 'granularity'])) {
    return 'policy';
  }
  return 'other';
}

/// Where [day] sits relative to [today], as a category. Both are dates
/// in the workspace's own calendar; the day itself is never recorded.
String dateRelation(DateTime day, DateTime today) {
  final d = DateTime.utc(day.year, day.month, day.day);
  final t = DateTime.utc(today.year, today.month, today.day);
  final days = d.difference(t).inDays;
  if (days < 0) return 'past';
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  // Monday is 1, Sunday 7: the rest of this week.
  if (days <= DateTime.sunday - today.weekday) return 'later_this_week';
  return 'later';
}

/// The period a picked window is, as a category: a long window is the
/// full day, otherwise the half it starts in. [startHour] is the
/// workspace's wall-clock hour.
String periodOf({required int startHour, required Duration length}) {
  if (length >= const Duration(hours: 7)) return 'full_day';
  return startHour < 12 ? 'morning' : 'afternoon';
}
