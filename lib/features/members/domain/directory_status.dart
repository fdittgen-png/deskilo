// SPDX-License-Identifier: MIT
//
// Pure status derivation for the member directory (#224) — one status per
// member, resolved in priority order (epic #222 decision):
//   checked in  >  online  >  reserved today  >  offline.
import '../../../core/presence/presence_rules.dart';
import '../../profile/domain/profile.dart';
import '../../reservations/domain/reservation.dart';

/// The four directory states, in display priority order.
enum DirectoryStatusKind { checkedIn, online, reservedToday, offline }

/// Resolved directory status of one member.
class DirectoryStatus {
  const DirectoryStatus._(this.kind, {this.seatName = '', this.lastSeenAt});

  final DirectoryStatusKind kind;

  /// Seat/office name for [DirectoryStatusKind.checkedIn]; '' when the
  /// plan has no name for the booked target.
  final String seatName;

  /// Last heartbeat for [DirectoryStatusKind.offline]; null when the
  /// member was never seen (renders no chip at all).
  final DateTime? lastSeenAt;
}

/// Resolves the directory status of the member [memberId].
///
/// - **Checked in**: a reservation of the member with
///   [ReservationStatus.checkedIn] covering [now]; carries the booked
///   seat/office name from [targetNames].
/// - **Online**: the member's profile heartbeat is younger than
///   [PresenceRules.onlineWindow] ([resolvePresence], #223).
/// - **Reserved today**: any still-active reservation of the member in
///   [todayReservations] that has not ended yet (`endsAt` after [now]) —
///   including a reserved-but-not-checked-in booking covering now.
/// - **Offline**: everything else; carries `lastSeenAt` for the relative
///   label (null = never seen, no chip).
DirectoryStatus resolveDirectoryStatus({
  required String memberId,
  required Profile? profile,
  required List<Reservation> todayReservations,
  required Map<String, String> targetNames,
  required DateTime now,
}) {
  final mine = todayReservations.where((r) => r.memberId == memberId);

  for (final r in mine) {
    if (r.status == ReservationStatus.checkedIn && r.coversInstant(now)) {
      final targetId = r.seatId ?? r.officeId;
      return DirectoryStatus._(
        DirectoryStatusKind.checkedIn,
        seatName: targetNames[targetId] ?? '',
      );
    }
  }

  final lastSeenAt = profile?.lastSeenAt;
  if (resolvePresence(lastSeenAt: lastSeenAt, now: now) ==
      PresenceStatus.online) {
    return const DirectoryStatus._(DirectoryStatusKind.online);
  }

  if (mine.any((r) => r.isActive && r.endsAt.isAfter(now))) {
    return const DirectoryStatus._(DirectoryStatusKind.reservedToday);
  }

  return DirectoryStatus._(DirectoryStatusKind.offline,
      lastSeenAt: lastSeenAt);
}
