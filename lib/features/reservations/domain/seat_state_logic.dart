// SPDX-License-Identifier: 0BSD
//
// Pure seat-state computation (spec §4.1) — drives the live floor plan AND
// the time scroller: pass any instant, get the plan at that moment.
import '../../../core/theme/seat_state_colors.dart';
import '../../plan/domain/floor_plan.dart';
import '../../plan/domain/seat.dart';
import 'reservation.dart';

export '../../../core/theme/seat_state_colors.dart'
    show SeatState, SeatDayPhase;

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

/// The seat's DAY PHASE (#575): what the browsed day holds for this seat
/// beyond the instant state — a finished booking (grey hint), one
/// running right now (green ring), or one still ahead today (light
/// green ring). [reservations] is the browsed DAY's slice; completed
/// bookings count for [SeatDayPhase.past] — that a reservation HAPPENED
/// is exactly what the glance must show.
SeatDayPhase seatDayPhaseAt({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime at,
}) {
  final officeId = _officeIdOf(plan, seat);
  var past = false;
  var upcoming = false;
  for (final r in reservations) {
    if (r.status == ReservationStatus.cancelled ||
        r.status == ReservationStatus.released) {
      continue;
    }
    if (!_covers(plan, seat, officeId, r)) continue;
    if (r.isActive && r.coversInstant(at)) return SeatDayPhase.ongoing;
    if (!r.endsAt.isAfter(at)) past = true;
    if (r.startsAt.isAfter(at) && r.isActive) upcoming = true;
  }
  // Ahead beats behind: the seat's next relevant fact is the booking
  // still coming, not the one already over.
  if (upcoming) return SeatDayPhase.upcoming;
  if (past) return SeatDayPhase.past;
  return SeatDayPhase.none;
}

/// #903 — one taken stretch of the browsed DAY on a seat: who holds it,
/// when, and where that sits in the open day (`from`/`to` are fractions
/// of the opening window, so a painter can divide the seat symbol and a
/// timeline can place the row without knowing the hours).
class SeatDaySegment {
  const SeatDaySegment({
    required this.reservationId,
    required this.memberId,
    required this.state,
    required this.start,
    required this.end,
    required this.from,
    required this.to,
  });

  final String reservationId;
  final String memberId;

  /// What this stretch deserves on the plan: [SeatState.mine] for the
  /// caller's own booking, [SeatState.occupied] once checked in, else
  /// [SeatState.reserved].
  final SeatState state;

  /// The stretch, clamped to the open day.
  final DateTime start;
  final DateTime end;

  /// Its place in the open day, 0 (opening) → 1 (closing).
  final double from;
  final double to;

  bool get isMine => state == SeatState.mine;

  @override
  bool operator ==(Object other) =>
      other is SeatDaySegment &&
      other.reservationId == reservationId &&
      other.memberId == memberId &&
      other.state == state &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode =>
      Object.hash(reservationId, memberId, state, start, end);
}

/// The taken stretches of `[dayStart, dayEnd)` on [seat], in time order —
/// direct bookings and the whole-desk/office/level ones alike, clamped to
/// the day and placed in it. A seat held all day yields ONE segment from
/// 0 to 1; a morning booking yields one that stops at the boundary; two
/// members sharing the seat yield two.
List<SeatDaySegment> seatDaySegments({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required String? myMemberId,
  required DateTime dayStart,
  required DateTime dayEnd,
}) {
  final span = dayEnd.difference(dayStart).inMinutes;
  if (span <= 0) return const [];
  final officeId = _officeIdOf(plan, seat);
  double place(DateTime at) {
    final minutes = at.difference(dayStart).inMinutes / span;
    return minutes.clamp(0.0, 1.0);
  }

  final taken = <SeatDaySegment>[];
  for (final r in reservations) {
    if (!r.isActive || !_covers(plan, seat, officeId, r)) continue;
    if (!r.startsAt.isBefore(dayEnd) || !dayStart.isBefore(r.endsAt)) continue;
    final start = r.startsAt.isBefore(dayStart) ? dayStart : r.startsAt;
    final end = r.endsAt.isAfter(dayEnd) ? dayEnd : r.endsAt;
    taken.add(SeatDaySegment(
      reservationId: r.id,
      memberId: r.memberId,
      state: r.memberId == myMemberId
          ? SeatState.mine
          : r.status == ReservationStatus.checkedIn
              ? SeatState.occupied
              : SeatState.reserved,
      start: start,
      end: end,
      from: place(start),
      to: place(end),
    ));
  }
  taken.sort((a, b) => a.start.compareTo(b.start));
  return taken;
}

/// Whether [segments] leave the day partly free — what makes a seat read
/// as PART-booked instead of taken.
bool seatDayIsPartial(List<SeatDaySegment> segments) {
  if (segments.isEmpty) return false;
  var covered = 0.0;
  var reach = 0.0;
  for (final s in segments) {
    final from = s.from > reach ? s.from : reach;
    if (s.to > from) covered += s.to - from;
    if (s.to > reach) reach = s.to;
  }
  return covered < 0.995;
}
