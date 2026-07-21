// SPDX-License-Identifier: 0BSD
//
// Pure status derivation for the member directory. Since #237 a member
// row carries TWO independent indicators instead of one merged status
// (#224/#222): a presence chip (online > relative last-seen) and a
// reservation chip (checked in now > reserved now > next upcoming
// reservation within [DirectoryReservationRules.upcomingWindow]).
import '../../../core/presence/presence_rules.dart';
import '../../reservations/domain/reservation.dart';

/// Reservation-chip tuning (#237), pinned by test (no magic numbers rule).
abstract final class DirectoryReservationRules {
  /// How far ahead the directory looks for a member's next reservation.
  /// A booking starting exactly `now + upcomingWindow` still shows; the
  /// 15th day does not.
  static const Duration upcomingWindow = Duration(days: 14);
}

/// The two presence states of the directory presence chip.
enum DirectoryPresenceKind { online, offline }

/// Resolved presence of one member — the left indicator of a row (#237).
class DirectoryPresence {
  const DirectoryPresence._(this.kind, {this.lastSeenAt});

  final DirectoryPresenceKind kind;

  /// Last heartbeat for [DirectoryPresenceKind.offline]; null when the
  /// member was never seen (renders no presence chip at all).
  final DateTime? lastSeenAt;
}

/// Resolves the presence indicator of a member from its profile
/// heartbeat: **online** when the heartbeat is younger than
/// [PresenceRules.onlineWindow] ([resolvePresence], #223), otherwise
/// **offline** carrying `lastSeenAt` for the relative label (null =
/// never seen, no chip).
DirectoryPresence resolveDirectoryPresence({
  required DateTime? lastSeenAt,
  required DateTime now,
}) {
  if (resolvePresence(lastSeenAt: lastSeenAt, now: now) ==
      PresenceStatus.online) {
    return const DirectoryPresence._(DirectoryPresenceKind.online);
  }
  return DirectoryPresence._(DirectoryPresenceKind.offline,
      lastSeenAt: lastSeenAt);
}

/// Resolved reservation indicator of one member — the right indicator of
/// a row (#237). Exactly one of the three concrete states, or null when
/// the member has no relevant booking (no reservation chip).
sealed class ReservationInfo {
  const ReservationInfo(this.reservation);

  /// The reservation backing the chip; the UI resolves the seat/office
  /// name via `targetNames[reservation.seatId ?? reservation.officeId]`.
  final Reservation reservation;
}

/// A checked-in reservation covers now — the member is physically in.
final class CheckedInNow extends ReservationInfo {
  const CheckedInNow(super.reservation);
}

/// An active reservation covers now but was not checked in (yet).
final class ReservedNow extends ReservationInfo {
  const ReservedNow(super.reservation);
}

/// The member's NEXT active reservation, starting after [DateTime] `now`
/// and within [DirectoryReservationRules.upcomingWindow].
final class UpcomingReservation extends ReservationInfo {
  const UpcomingReservation(super.reservation);
}

/// Resolves the reservation indicator of the member [memberId] from
/// [reservations] (any list covering now and the upcoming window — the
/// directory feeds the merged month windows, see
/// `directoryReservationsProvider`), in priority order:
///
/// - [CheckedInNow]: a reservation with [ReservationStatus.checkedIn]
///   covering [now].
/// - [ReservedNow]: an active reservation covering [now] without
///   check-in.
/// - [UpcomingReservation]: the earliest still-active reservation with
///   `startsAt` in `(now, now + upcomingWindow]` — start exactly on the
///   window edge included, anything later excluded.
/// - null: nothing relevant. Cancelled/released/completed bookings never
///   surface ([Reservation.isActive]).
ReservationInfo? resolveReservationInfo({
  required String memberId,
  required List<Reservation> reservations,
  required DateTime now,
}) {
  final mine = reservations.where((r) => r.memberId == memberId);

  Reservation? reservedNow;
  Reservation? upcoming;
  final horizon = now.add(DirectoryReservationRules.upcomingWindow);

  for (final r in mine) {
    if (r.coversInstant(now)) {
      if (r.status == ReservationStatus.checkedIn) return CheckedInNow(r);
      reservedNow ??= r;
      continue;
    }
    if (r.isActive &&
        r.startsAt.isAfter(now) &&
        !r.startsAt.isAfter(horizon) &&
        (upcoming == null || r.startsAt.isBefore(upcoming.startsAt))) {
      upcoming = r;
    }
  }

  if (reservedNow != null) return ReservedNow(reservedNow);
  if (upcoming != null) return UpcomingReservation(upcoming);
  return null;
}
