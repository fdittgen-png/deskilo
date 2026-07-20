// SPDX-License-Identifier: MIT
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';

/// In-memory [ReservationRepository] mimicking the DB exclusion constraint
/// and the RPC state checks (fakes over mocks).
class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository({this.myMemberId = 'member-1'});

  final String myMemberId;
  final reservations = <Reservation>[];
  var _nextId = 1;
  DateTime Function() now = DateTime.now;

  bool _overlapsActive(
    String? seatId,
    String? officeId,
    DateTime start,
    DateTime end, {
    String? ignoreId,
  }) {
    return reservations.any((r) =>
        r.id != ignoreId &&
        r.isActive &&
        ((seatId != null && r.seatId == seatId) ||
            (officeId != null && r.officeId == officeId)) &&
        r.startsAt.isBefore(end) &&
        start.isBefore(r.endsAt));
  }

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    return reservations
        .where((r) =>
            r.workspaceId == workspaceId &&
            r.startsAt.isBefore(to) &&
            from.isBefore(r.endsAt))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  }

  @override
  Future<String> create({
    required String workspaceId,
    String? seatId,
    String? officeId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    if ((seatId == null) == (officeId == null)) {
      throw StateError('exactly one of seat or office required');
    }
    if (_overlapsActive(seatId, officeId, startsAt, endsAt)) {
      throw StateError('conflict');
    }
    final reservation = Reservation(
      id: 'res-${_nextId++}',
      workspaceId: workspaceId,
      seatId: seatId,
      officeId: officeId,
      memberId: myMemberId,
      startsAt: startsAt,
      endsAt: endsAt,
      status:
          checkIn ? ReservationStatus.checkedIn : ReservationStatus.reserved,
      checkedInAt: checkIn ? now() : null,
    );
    reservations.add(reservation);
    return reservation.id;
  }

  Reservation _byId(String id) =>
      reservations.firstWhere((r) => r.id == id, orElse: () {
        throw StateError('unknown reservation');
      });

  void _replace(Reservation updated) {
    final i = reservations.indexWhere((r) => r.id == updated.id);
    reservations[i] = updated;
  }

  final bookedForOthers =
      <({String subjectMemberId, String seatId, DateTime startsAt})>[];

  @override
  Future<String> createFor({
    required String workspaceId,
    required String subjectMemberId,
    required String seatId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if (_overlapsActive(seatId, null, startsAt, endsAt)) {
      throw StateError('conflict');
    }
    bookedForOthers.add(
      (
        subjectMemberId: subjectMemberId,
        seatId: seatId,
        startsAt: startsAt,
      ),
    );
    reservations.add(
      Reservation(
        id: 'res-${_nextId++}',
        workspaceId: workspaceId,
        seatId: seatId,
        memberId: subjectMemberId,
        startsAt: startsAt,
        endsAt: endsAt,
        status: ReservationStatus.reserved,
      ),
    );
    return 'evt-for-${bookedForOthers.length}';
  }

  @override
  Future<void> checkIn(String reservationId) async {
    final r = _byId(reservationId);
    if (r.status != ReservationStatus.reserved) {
      throw StateError('not in reserved state');
    }
    _replace(
      r.copyWith(status: ReservationStatus.checkedIn, checkedInAt: now()),
    );
  }

  /// (action, badgeToken, seatId) of kiosk_act calls (0043).
  final kioskActs = <({String action, String badgeToken, String? seatId})>[];

  @override
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    kioskActs.add((action: action, badgeToken: badgeToken, seatId: seatId));
    return 'res-kiosk-${kioskActs.length}';
  }

  @override
  Future<void> checkOut(String reservationId) async {
    final r = _byId(reservationId);
    if (r.status != ReservationStatus.checkedIn) {
      throw StateError('not checked in');
    }
    final at = now();
    _replace(r.copyWith(
      status: ReservationStatus.completed,
      checkedOutAt: at,
      endsAt: at.isBefore(r.endsAt) ? at : r.endsAt,
    ));
  }

  @override
  Future<void> cancel(String reservationId) async {
    final r = _byId(reservationId);
    if (!r.isActive) throw StateError('not cancellable');
    _replace(r.copyWith(status: ReservationStatus.cancelled));
  }

  @override
  Future<void> updateTimes(
    String reservationId, {
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    final i = reservations.indexWhere((r) => r.id == reservationId);
    if (i < 0) throw StateError('unknown reservation');
    final r = reservations[i];
    if (_overlapsActive(r.seatId, r.officeId, startsAt, endsAt,
        ignoreId: reservationId)) {
      throw StateError('seat already reserved in that window');
    }
    reservations[i] = r.copyWith(startsAt: startsAt, endsAt: endsAt);
  }

  @override
  Future<SeriesResult> createSeries({
    required String workspaceId,
    required String seatId,
    required DateTime firstStart,
    required DateTime firstEnd,
    required SeriesPattern pattern,
    required DateTime until,
  }) async {
    final seriesId = 'series-${_nextId++}';
    final booked = <DateTime>[];
    final skipped = <DateTime>[];
    final step = pattern == SeriesPattern.weekly
        ? const Duration(days: 7)
        : const Duration(days: 1);
    var start = firstStart;
    var end = firstEnd;
    while (!start.isAfter(until)) {
      final isWeekday = start.weekday <= DateTime.friday;
      if (pattern != SeriesPattern.weekdays || isWeekday) {
        if (_overlapsActive(seatId, null, start, end)) {
          skipped.add(start);
        } else {
          reservations.add(
            Reservation(
              id: 'res-${_nextId++}',
              workspaceId: workspaceId,
              seatId: seatId,
              memberId: myMemberId,
              startsAt: start,
              endsAt: end,
              status: ReservationStatus.reserved,
              seriesId: seriesId,
              seriesPattern: pattern.name,
            ),
          );
          booked.add(start);
        }
      }
      start = start.add(step);
      end = end.add(step);
    }
    return SeriesResult(seriesId: seriesId, booked: booked, skipped: skipped);
  }

  @override
  Future<int> cancelSeries(String seriesId, {DateTime? from}) async {
    var count = 0;
    for (var i = 0; i < reservations.length; i++) {
      final r = reservations[i];
      if (r.seriesId == seriesId &&
          r.status == ReservationStatus.reserved &&
          (from == null || !r.startsAt.isBefore(from))) {
        reservations[i] = r.copyWith(status: ReservationStatus.cancelled);
        count++;
      }
    }
    if (count == 0) throw StateError('nothing to cancel');
    return count;
  }
}
