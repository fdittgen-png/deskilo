// SPDX-License-Identifier: MIT
//
// Pure seat-state computation (spec §4.1) — drives the live floor plan AND
// the time scroller: pass any instant, get the plan at that moment.
import '../../../core/theme/seat_state_colors.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/seat.dart';
import 'reservation.dart';

export '../../../core/theme/seat_state_colors.dart' show SeatState;

/// State of [seat] at instant [at]. [reservations] is the workspace's
/// active-window slice; office-as-whole bookings mark all seats of that
/// office. [myMemberId] marks the caller's own bookings as [SeatState.mine].
SeatState seatStateAt({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required String? myMemberId,
  required DateTime at,
}) {
  if (seat.isBlockedAt(at)) return SeatState.blocked;

  final officeId =
      plan.desks.where((d) => d.id == seat.deskId).firstOrNull?.officeId;

  Reservation? covering;
  for (final r in reservations) {
    if (!r.coversInstant(at)) continue;
    if (r.seatId == seat.id || (r.officeId != null && r.officeId == officeId)) {
      covering = r;
      break;
    }
  }
  if (covering == null) return SeatState.free;
  if (covering.memberId == myMemberId) return SeatState.mine;
  return covering.status == ReservationStatus.checkedIn
      ? SeatState.occupied
      : SeatState.reserved;
}

/// The reservation covering [seat] at [at], if any (incl. office-as-whole).
Reservation? reservationOnSeatAt({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime at,
}) {
  final officeId =
      plan.desks.where((d) => d.id == seat.deskId).firstOrNull?.officeId;
  for (final r in reservations) {
    if (!r.coversInstant(at)) continue;
    if (r.seatId == seat.id || (r.officeId != null && r.officeId == officeId)) {
      return r;
    }
  }
  return null;
}

/// Next active reservation on [seat] strictly after [at] — caps walk-up
/// end times (spec §4.2 step 4).
Reservation? nextReservationOnSeat({
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime at,
}) {
  Reservation? next;
  for (final r in reservations) {
    if (r.seatId != seat.id || !r.isActive) continue;
    if (r.startsAt.isAfter(at)) {
      if (next == null || r.startsAt.isBefore(next.startsAt)) next = r;
    }
  }
  return next;
}
