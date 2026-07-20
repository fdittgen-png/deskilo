// SPDX-License-Identifier: MIT
//
// Shared seat-occupancy derivations of the read-only plan canvases: which
// reservation holds a seat over the browsed window, the occupant's label,
// the per-seat paint states and the online (presence-dot) seats. Formerly
// duplicated between plan_screen and reserve_screen ("same rule as the
// Plan tab").
import '../../members/domain/directory_status.dart';
import '../../profile/domain/profile.dart';
import '../../reservations/domain/reservation.dart';
import '../../reservations/domain/seat_state_logic.dart';
import '../../workspace/domain/member.dart';
import '../domain/floor_plan.dart';
import '../domain/seat.dart';

/// First word of a member's display name — the seat-label shorthand.
String firstNameOf(String name) => name.split(' ').firstOrNull ?? name;

/// The reservation holding [seat] over the browsed window: at the instant
/// [from] when [to] is null (walk-up "now" browsing), else anywhere within
/// `[from, to)`.
Reservation? occupantOnSeat({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required DateTime from,
  DateTime? to,
}) =>
    to == null
        ? reservationOnSeatAt(
            plan: plan,
            seat: seat,
            reservations: reservations,
            at: from,
          )
        : reservationOnSeatInRange(
            plan: plan,
            seat: seat,
            reservations: reservations,
            from: from,
            to: to,
          );

/// Painter label of [seat]: the occupant's first name, '' when free.
String occupantLabelFor({
  required FloorPlan plan,
  required Seat seat,
  required List<Reservation> reservations,
  required Map<String, String> names,
  required DateTime from,
  DateTime? to,
}) {
  final r = occupantOnSeat(
    plan: plan,
    seat: seat,
    reservations: reservations,
    from: from,
    to: to,
  );
  if (r == null) return '';
  return firstNameOf(names[r.memberId] ?? '');
}

/// Per-seat paint states over the browsed window. On a closed day (#186)
/// every seat renders in the muted blocked state — nothing looks bookable.
Map<String, SeatState> seatStatesFor({
  required FloorPlan plan,
  required List<Reservation> reservations,
  required String? myMemberId,
  required DateTime from,
  DateTime? to,
  bool dayOpen = true,
}) =>
    {
      for (final seat in plan.seats)
        seat.id: !dayOpen
            ? SeatState.blocked
            : to == null
                ? seatStateAt(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    at: from,
                  )
                : seatStateInRange(
                    plan: plan,
                    seat: seat,
                    reservations: reservations,
                    myMemberId: myMemberId,
                    from: from,
                    to: to,
                  ),
    };

/// Seats whose occupant is online (presence heartbeat): the painter marks
/// them with a green dot. Resolves each taken seat's occupant → member →
/// profile last-seen, same rule as the directory.
Set<String> onlineSeatIdsFor({
  required FloorPlan plan,
  required List<Reservation> reservations,
  required List<Member> members,
  required Map<String, Profile> profiles,
  required DateTime from,
  DateTime? to,
  DateTime? now,
}) {
  if (profiles.isEmpty || members.isEmpty) return const {};
  final userIdOf = {for (final m in members) m.id: m.userId};
  final presenceNow = now ?? DateTime.now();
  bool online(String memberId) {
    final uid = userIdOf[memberId];
    final profile = uid == null ? null : profiles[uid];
    return resolveDirectoryPresence(
          lastSeenAt: profile?.lastSeenAt,
          now: presenceNow,
        ).kind ==
        DirectoryPresenceKind.online;
  }

  return {
    for (final seat in plan.seats)
      if (occupantOnSeat(
            plan: plan,
            seat: seat,
            reservations: reservations,
            from: from,
            to: to,
          )
          case final r?)
        if (online(r.memberId)) seat.id,
  };
}
