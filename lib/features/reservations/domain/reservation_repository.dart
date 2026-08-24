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
/// Who a kiosk badge resolved to (#616): the display name plus what the
/// receipt needs to show their profile photo (0038 avatars bucket).
typedef KioskIdentity = ({String name, String userId, bool hasAvatar});

abstract class ReservationRepository {
  /// Active + recent reservations of the workspace intersecting
  /// [from, to). Includes all statuses so history views work.
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  });

  /// EVERY reservation of the workspace, oldest first — the reservations
  /// and check-ins tabs of the data export (#395). Not windowed: an
  /// export that silently clips history reads as complete when it is not.
  Future<List<Reservation>> fetchAllForExport(String workspaceId);

  /// One reservation by id, or null when it no longer exists — message
  /// references (#523) resolve live and must survive deletions.
  Future<Reservation?> fetchById(String reservationId);

  /// Creates a reservation for the signed-in member. [checkIn] makes it an
  /// atomic walk-up (reservation + check-in in one transaction).
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
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
    String? seatId,
    String? levelId,
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
  /// Kiosk identification (RPC `kiosk_identify`, 0054 → 0117): who
  /// does [badgeToken] belong to? Resolves the badge to the member's
  /// display name WITHOUT acting — the confirm step between reading the
  /// badge and running [kioskAct]. Pinned refusal: 'badge not
  /// recognized'.
  Future<KioskIdentity> kioskIdentify({
    required String workspaceId,
    required String badgeToken,
  });

  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    String? levelId,
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
  /// Exactly one of [seatId], [deskId], [officeId], [levelId] (0065):
  /// whole-space series carry the same repetition as seats.
  Future<SeriesResult> createSeries({
    required String workspaceId,
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  });

  /// Cancels a whole series, or only instances starting at/after [from].
  Future<int> cancelSeries(String seriesId, {DateTime? from});
}
