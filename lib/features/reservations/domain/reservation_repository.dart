// SPDX-License-Identifier: MIT
import 'reservation.dart';

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
}
