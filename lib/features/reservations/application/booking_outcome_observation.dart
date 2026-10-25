// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — what a returned booking says to the task recorder, as the
// recorder's registered outcomes. #2495: read here, beside the outcome
// type, so the recorder names no booking type; the shape is the
// recorder's observation record (task_recorder/application/
// booking_observation.dart). Only categories leave: never the member, a
// reservation id or a date.
import '../../task_recorder/domain/action_registry.dart' show RecorderOutcomes;
import 'book_seat.dart';

/// What a returned [BookingOutcome] says.
({String outcome, Map<String, Object?> payload}) bookingOutcomeObservation(
  BookingOutcome outcome,
) => switch (outcome) {
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
      'series_result': result.skipped.isEmpty
          ? 'all_booked'
          : 'partially_booked',
    },
  ),
};
