// SPDX-License-Identifier: 0BSD
import 'reservation.dart';

/// Recurrence patterns supported by the backend (spec §5.2 subset).
enum SeriesPattern { daily, weekdays, weekly }

/// Outcome of a series creation: which instances were booked and which
/// were skipped because of conflicts (spec §5.2: never silently partial).
class SeriesResult {
  const SeriesResult({
    required this.seriesId,
    required this.booked,
    required this.skipped,
  });

  final String seriesId;
  final List<DateTime> booked;
  final List<DateTime> skipped;
}

/// Pure-Dart reservation boundary. All writes go through backend RPCs that
/// re-check conflicts transactionally — the client never decides
/// availability on its own (spec §4.2).
abstract class ReservationRepository {
  /// Active + recent reservations of the workspace intersecting
  /// [from, to). Includes all statuses so history views work.
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });

  /// Creates a reservation for the signed-in member. [checkIn] makes it an
  /// atomic walk-up (reservation + check-in in one transaction).
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? officeId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  });

  /// Admin/owner books FOR another member (#106): tentative reservation
  /// that blocks the seat + pending event the subject must accept.
  /// Returns the pending event id.
  Future<String> createFor({
    required String workspaceId,
    required String subjectMemberId,
    required String seatId,
    required DateTime startsAt,
    required DateTime endsAt,
  });

  Future<void> checkIn(String reservationId);
  Future<void> checkOut(String reservationId);
  Future<void> cancel(String reservationId);

  /// Kiosk elevation (RPC `kiosk_act`, migration 0043): the signed-in
  /// KIOSK account performs [action] AS the member the badge [badgeToken]
  /// resolves to — 'reserve' | 'check_in' | 'check_out'. Stateless: the
  /// member's "session" begins and ends inside the call, so nothing is
  /// cached on the device. Returns the acted-on reservation id.
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    DateTime? startsAt,
    DateTime? endsAt,
  });

  /// Atomically moves MY still-'reserved' booking to a new window on the
  /// same seat (update_reservation, 0033) — rules, closures, seat blocks
  /// and quota re-checked server-side.
  Future<void> updateTimes(
    String reservationId, {
    required DateTime startsAt,
    required DateTime endsAt,
  });

  /// Books a recurring series; the backend expands instances and reports
  /// conflicts as skipped.
  Future<SeriesResult> createSeries({
    required String workspaceId,
    required String seatId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  });

  /// Cancels a whole series, or only instances starting at/after [from].
  Future<int> cancelSeries(String seriesId, {DateTime? from});
}
