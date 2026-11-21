// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4157 (A2 of #4174) — a confirmation acts on the workspace and account its
// displayed data was read from.
//
// A booking, check-in, checkout, cancellation, time edit or deletion request
// is confirmed in a sheet or a dialog, and the person may switch installation,
// workspace or account while it is open. [BoundReservation] is the immutable
// handle taken when the confirmation opens, BEFORE its first await: the
// operation context the data was read under, and the repositories and the
// recovery of THAT context. Every command re-reads the current context after
// each confirmation await and refuses, writing nothing, unless it is the very
// same operation ([WorkspaceContext.sameOperationAs]: identity, installation,
// workspace, local account, epochs and captured business inputs). Equal local
// workspace or reservation ids on two installations are two targets.
//
// Once a command has been sent it is not undone by a later switch: its answer
// stays with the origin it was sent to ([isCurrent] tells the caller whether
// the context it ran in is still the one on screen, so a late result is not
// shown or refreshed as if the new context owned it). The original request id
// and the booking's recovery are the captured ones; a second booking is never
// made to recover the first.
//
// No `BuildContext`, `WidgetRef`, presentation, data or events import: the
// reservation repository and the recovery are supplied by the composition root.
import '../../../core/backend/operation_context.dart';
import '../../../core/booking/my_seat_action.dart';
import '../domain/reservation_repository.dart';
import 'book_seat.dart';
import 'booking_recovery.dart';

/// The context changed (another installation, workspace or account, a
/// sign-out, a disposed screen) between what was displayed and the command:
/// nothing was sent. The person reopens the confirmation.
class StaleReservationContext implements Exception {
  const StaleReservationContext();

  @override
  String toString() => 'StaleReservationContext';
}

/// The reservation commands of one operation context.
class BoundReservation {
  BoundReservation({
    required this.origin,
    required this.reservations,
    required this.recovery,
    required this.readContext,
  });

  /// The context the displayed data was read under.
  final WorkspaceContext origin;

  /// The origin's own reservation repository and recovery, taken with it.
  final ReservationRepository reservations;
  final BookingRecovery recovery;

  /// Reads the context on screen NOW (not a captured one).
  final Future<WorkspaceContext?> Function() readContext;

  /// Whether the context on screen now is the origin. A missing context, a
  /// signed-out account, a disposed screen or any failure to read it is "no".
  Future<bool> isCurrent() async {
    try {
      final now = await readContext();
      return now != null && now.sameOperationAs(origin);
    } on Object {
      // trace-exempt: a context that cannot be read is not the origin.
      return false;
    }
  }

  /// Runs [command] on the origin's reservation repository, after proving the
  /// context is still the origin. The one gate every write passes through.
  Future<T> withReservations<T>(
    Future<T> Function(ReservationRepository reservations) command,
  ) async {
    if (!await isCurrent()) throw const StaleReservationContext();
    return command(reservations);
  }

  /// An own-booking action of [reservationId]: check in, check out, cancel.
  /// Every choice names its command. A deletion request is not one of them:
  /// it is a request an owner validates, filed through the events (see
  /// `requestBookingDeletion`), so it is refused here rather than falling
  /// through to a cancellation.
  Future<void> perform(
    MySeatAction action,
    String reservationId,
  ) => switch (action) {
    MySeatAction.checkIn => withReservations((r) => r.checkIn(reservationId)),
    MySeatAction.checkOut => withReservations((r) => r.checkOut(reservationId)),
    MySeatAction.cancel => withReservations((r) => r.cancel(reservationId)),
    MySeatAction.requestDeletion => throw ArgumentError.value(
      action,
      'action',
      'a deletion request is filed through the events, not performed here',
    ),
  };

  /// A booking: the decision of WHICH write it is stays in [bookSeat]; this
  /// binds it to the origin's repository and recovery.
  Future<BookingOutcome> book(
    BookingRequest request, {
    required String? myMemberId,
  }) => withReservations(
    (r) => bookSeat(r, request, myMemberId: myMemberId, recovery: recovery),
  );
}
