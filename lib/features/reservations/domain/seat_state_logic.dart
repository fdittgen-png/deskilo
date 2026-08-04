// SPDX-License-Identifier: 0BSD
//
// Pure seat-state computation (spec §4.1) — drives the live floor plan AND
// the time scroller: pass any instant, get the plan at that moment.
import '../../../core/theme/seat_state_colors.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/seat.dart';
import 'reservation.dart';

export '../../../core/theme/seat_state_colors.dart' show SeatState;

/// Whether [r] covers [seat] — directly (seat_id), as part of a
/// whole-desk (desk_id), whole-office (office_id via [officeId]) or
/// whole-level booking (level_id, #452: a level reservation occupies
/// EVERY seat of its plan, visible to everyone). One predicate for the
/// derivations below — the copies had already drifted apart once
/// (level_id was silently dropped everywhere).
bool _covers(FloorPlan plan, Seat seat, String? officeId, Reservation r) =>
    r.seatId == seat.id ||
    (r.deskId != null && r.deskId == seat.deskId) ||
    (r.officeId != null && r.officeId == officeId) ||
    (r.levelId != null && r.levelId == plan.levelId);

String? _officeIdOf(FloorPlan plan, Seat seat) =>
    plan.desks.where((d) => d.id == seat.deskId).firstOrNull?.officeId;

/// State of [seat] at instant [at]. [reservations] is the workspace's
/// active-window slice; whole-space bookings (desk/office/level) mark all
/// their seats. [myMemberId] marks the caller's own bookings as
/// [SeatState.mine].
SeatState seatStateAt({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required String? myMemberId,
  required DateTime at,
}) {
  if (seat.isBlockedAt(at)) return SeatState.blocked;

  final covering = reservationOnSeatAt(
    plan: plan,
    seat: seat,
    reservations: reservations,
    at: at,
  );
  if (covering == null) return SeatState.free;
  if (covering.memberId == myMemberId) return SeatState.mine;
  return covering.status == ReservationStatus.checkedIn
      ? SeatState.occupied
      : SeatState.reserved;
}

/// The reservation covering [seat] at [at], if any (incl. whole-space).
Reservation? reservationOnSeatAt({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime at,
}) {
  final officeId = _officeIdOf(plan, seat);
  for (final r in reservations) {
    if (!r.coversInstant(at)) continue;
    if (_covers(plan, seat, officeId, r)) return r;
  }
  return null;
}

/// State of [seat] over the half-open window `[from, to)` (#184) — drives
/// the plan while browsing a time frame: any overlap with the window
/// counts, so a seat is only [SeatState.free] when it is free for the
/// WHOLE window. Live mode keeps using the instant-based [seatStateAt].
SeatState seatStateInRange({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required String? myMemberId,
  required DateTime from,
  required DateTime to,
}) {
  if (_seatBlockOverlapsRange(seat, from, to)) return SeatState.blocked;

  final covering = reservationOnSeatInRange(
    plan: plan,
    seat: seat,
    reservations: reservations,
    from: from,
    to: to,
  );
  if (covering == null) return SeatState.free;
  if (covering.memberId == myMemberId) return SeatState.mine;
  return covering.status == ReservationStatus.checkedIn
      ? SeatState.occupied
      : SeatState.reserved;
}

/// The first reservation overlapping [seat] within `[from, to)` (#184),
/// if any (incl. whole-space) — the range twin of [reservationOnSeatAt].
Reservation? reservationOnSeatInRange({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime from,
  required DateTime to,
}) {
  final officeId = _officeIdOf(plan, seat);
  for (final r in reservations) {
    if (!r.coversRange(from, to)) continue;
    if (_covers(plan, seat, officeId, r)) return r;
  }
  return null;
}

/// Maintenance block overlapping the half-open window `[from, to)` (#184).
/// Open-ended bounds mirror [Seat.isBlockedAt]: `blockedFrom == null` means
/// "since forever", `blockedTo == null` means "forever".
bool _seatBlockOverlapsRange(Seat seat, DateTime from, DateTime to) {
  if (seat.blockedFrom == null && seat.blockedTo == null) return false;
  final startsBeforeWindowEnd =
      seat.blockedFrom == null || seat.blockedFrom!.isBefore(to);
  final endsAfterWindowStart =
      seat.blockedTo == null || from.isBefore(seat.blockedTo!);
  return startsBeforeWindowEnd && endsAfterWindowStart;
}

/// Next active reservation covering [seat] strictly after [at] — caps
/// walk-up end times (spec §4.2 step 4). Whole-space bookings count
/// (#452): a walk-up must not be offered a window running into an
/// upcoming whole-desk/office/level reservation.
Reservation? nextReservationOnSeat({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime at,
}) {
  final officeId = _officeIdOf(plan, seat);
  Reservation? next;
  for (final r in reservations) {
    if (!r.isActive || !_covers(plan, seat, officeId, r)) continue;
    if (r.startsAt.isAfter(at)) {
      if (next == null || r.startsAt.isBefore(next.startsAt)) next = r;
    }
  }
  return next;
}
