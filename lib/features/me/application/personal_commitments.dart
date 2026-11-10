// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3548 -- the one seam between Me and the bookings of a place business:
// the reservation items a host answers become `PersonalCommitment`s here, and
// the few reservation providers Me needs are re-exported from here, so no
// file of Me's presentation imports `features/reservations` (a lint pins it).
// A later business kind adds its own adapter beside this one.
import '../../reservations/domain/my_reservations.dart';
import '../../reservations/domain/reservation.dart';
import '../domain/personal_commitment.dart';

export '../../reservations/domain/my_reservations.dart'
    show MyReservationsQuery, MyReservationsWindow;
export '../../reservations/providers/reservation_providers.dart'
    show
        myReservationsComposerProvider,
        myReservationsLimitsProvider,
        myReservationsWindowControllerProvider;

/// The commitment a reservation [item] is. [now] decides whether a check-in
/// is open: the rule IS `Reservation.checkInWindowOpen`, without a
/// granularity (the item carries none: the base window, from
/// `Reservation.checkInLeeway` before the start until the end; the server
/// stays the authority); [source] is the installation it was read from and [zone] the
/// IANA zone of its workspace.
PersonalCommitment commitmentOfReservation(
  MyReservationItem item, {
  required DateTime now,
  String source = '',
  String? zone,
}) {
  final state = switch (item.status) {
    ReservationStatus.reserved => CommitmentState.upcoming,
    ReservationStatus.checkedIn => CommitmentState.ongoing,
    ReservationStatus.completed => CommitmentState.done,
    ReservationStatus.cancelled ||
    ReservationStatus.released => CommitmentState.cancelled,
  };
  return PersonalCommitment(
    id: item.id,
    businessId: item.workspaceId,
    businessName: item.workspaceName,
    kind: CommitmentKind.place,
    place: switch (item.placeKind) {
      MyReservationPlaceKind.seat => CommitmentPlace.seat,
      MyReservationPlaceKind.desk => CommitmentPlace.desk,
      MyReservationPlaceKind.office => CommitmentPlace.office,
      MyReservationPlaceKind.level => CommitmentPlace.level,
      MyReservationPlaceKind.other => CommitmentPlace.other,
    },
    label: item.placeLabel,
    startsAt: item.startsAt,
    endsAt: item.endsAt,
    zone: zone,
    state: state,
    canCheckIn: Reservation(
      id: item.id,
      workspaceId: item.workspaceId,
      memberId: '',
      startsAt: item.startsAt,
      endsAt: item.endsAt,
      status: item.status,
    ).checkInWindowOpen(now),
    source: source,
  );
}
