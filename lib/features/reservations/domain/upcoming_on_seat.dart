// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3817 — the plan shows the window now, so a seat the person has booked
// for later today is drawn free. Tapping it opens that booking (to cancel
// it or check in when its time comes), not a second booking sheet.
import '../../../core/time/workspace_time.dart';
import 'reservation.dart';

/// [memberId]'s own next booking of [seatId] that starts after [now] on
/// [now]'s workspace-local day; null when there is none.
Reservation? myUpcomingOnSeat(
  Iterable<Reservation> reservations, {
  required String seatId,
  required String? memberId,
  required DateTime now,
}) {
  if (memberId == null) return null;
  final today = WorkspaceTime.dateOf(now);
  Reservation? next;
  for (final r in reservations) {
    if (r.seatId != seatId || r.memberId != memberId || !r.isActive) continue;
    if (!r.startsAt.isAfter(now)) continue;
    if (WorkspaceTime.dateOf(r.startsAt) != today) continue;
    if (next == null || r.startsAt.isBefore(next.startsAt)) next = r;
  }
  return next;
}
