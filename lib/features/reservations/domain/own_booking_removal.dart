// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2328 — one rule for removing MY booking, whichever sheet asks.
//
// The plan's "your seat" sheet offered Cancel on a checked-in booking
// while the booking's detail sheet offered Request deletion for the same
// state. #492 is the rule both now read: an upcoming booking is
// cancelled directly; a started, checked-in or completed one is never
// deleted directly — deleting it becomes a request an owner or
// administrator decides.
import 'reservation.dart';

/// How the member who holds a booking may remove it.
enum OwnBookingRemoval {
  /// Still upcoming and not checked in: cancelled directly.
  cancel,

  /// Started, checked in or completed: a request somebody decides.
  requestDeletion,

  /// Nothing to offer (already cancelled or released, or requests off).
  none,
}

/// The removal [reservation] offers its holder at [now].
///
/// [deletionRequests] is whether the space has the deletion-request
/// feature on; without it a started booking offers nothing.
OwnBookingRemoval ownBookingRemoval(
  Reservation reservation, {
  required DateTime now,
  required bool deletionRequests,
}) {
  final started = !reservation.startsAt.isAfter(now);
  return switch (reservation.status) {
    ReservationStatus.reserved when !started => OwnBookingRemoval.cancel,
    ReservationStatus.reserved ||
    ReservationStatus.checkedIn ||
    ReservationStatus.completed =>
      deletionRequests
          ? OwnBookingRemoval.requestDeletion
          : OwnBookingRemoval.none,
    ReservationStatus.cancelled ||
    ReservationStatus.released => OwnBookingRemoval.none,
  };
}
