// SPDX-License-Identifier: MIT
//
// Pure reminder derivation (spec §4.3): my reserved (not yet checked-in)
// bookings starting within the lookahead get a reminder [before] their start.
import '../../../core/notifications/notification_service.dart';
import 'reservation.dart';

export '../../../core/notifications/notification_service.dart'
    show ReminderRequest;

List<ReminderRequest> upcomingCheckInReminders({
  required List<Reservation> reservations,
  required String myMemberId,
  required DateTime now,
  required String Function(String targetName, DateTime startsAt) titleOf,
  required String Function(String targetName, DateTime startsAt) bodyOf,
  required Map<String, String> targetNames,
  Duration lookahead = const Duration(days: 7),
  Duration before = const Duration(minutes: 15),
}) {
  final horizon = now.add(lookahead);
  final result = <ReminderRequest>[];
  for (final r in reservations) {
    if (r.memberId != myMemberId) continue;
    if (r.status != ReservationStatus.reserved) continue;
    if (!r.startsAt.isAfter(now) || r.startsAt.isAfter(horizon)) continue;
    final remindAt = r.startsAt.subtract(before);
    if (!remindAt.isAfter(now)) continue;
    final target = targetNames[r.seatId ?? r.officeId] ?? '';
    result.add(
      ReminderRequest(
        reservationId: r.id,
        remindAt: remindAt,
        title: titleOf(target, r.startsAt),
        body: bodyOf(target, r.startsAt),
      ),
    );
  }
  result.sort((a, b) => a.remindAt.compareTo(b.remindAt));
  return result;
}
