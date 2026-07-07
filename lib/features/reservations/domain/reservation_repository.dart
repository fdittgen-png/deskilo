// SPDX-License-Identifier: MIT
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

  Future<void> checkIn(String reservationId);
  Future<void> checkOut(String reservationId);
  Future<void> cancel(String reservationId);

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
