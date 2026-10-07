// SPDX-License-Identifier: AGPL-3.0-or-later
import 'reservation.dart';

/// What a reservation's details must explain beyond its date and place:
/// why a booking that exists is not an upcoming one.
enum ReservationNote {
  /// Booked after its period had ended (same-day attendance, 0116/0122):
  /// kept as a past visit, and the day-end sweep (0075) completes it at
  /// once — the member must not think it failed or vanished.
  recordedAfterEnd,

  /// A completed stay, with the time it ended.
  checkedOut,

  /// The period is over and nobody checked in.
  overNotCheckedIn,
}

/// The note [r] needs at [now], or null when its date, place and actions
/// already say everything.
ReservationNote? reservationNoteOf(Reservation r, DateTime now) {
  final created = r.system.createdAt;
  final over = !r.endsAt.isAfter(now);
  if (created != null &&
      !created.isBefore(r.endsAt) &&
      (r.status == ReservationStatus.completed ||
          (r.status == ReservationStatus.reserved && over))) {
    return ReservationNote.recordedAfterEnd;
  }
  if (r.status == ReservationStatus.completed && r.checkedOutAt != null) {
    return ReservationNote.checkedOut;
  }
  if (r.status == ReservationStatus.reserved && over) {
    return ReservationNote.overNotCheckedIn;
  }
  return null;
}
