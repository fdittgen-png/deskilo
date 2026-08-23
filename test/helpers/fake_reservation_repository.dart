// SPDX-License-Identifier: 0BSD
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';

import 'package:deskilo/core/time/workspace_time.dart';
import 'test_clock.dart';

/// In-memory [ReservationRepository] mimicking the DB exclusion constraint
/// and the RPC state checks (fakes over mocks).
class FakeReservationRepository implements ReservationRepository {
  FakeReservationRepository({this.myMemberId = 'member-1'});

  final String myMemberId;
  final reservations = <Reservation>[];

  /// The workspace granularity the SERVER would read (#573): the fake
  /// mirrors the canonical walk-up snap-back and the same-day presence
  /// rule only when a test sets a day-based/hours granularity.
  BookingGranularity granularity = BookingGranularity.flexible;

  @override
  Future<Reservation?> fetchById(String reservationId) async =>
      reservations.where((r) => r.id == reservationId).firstOrNull;
  var _nextId = 1;
  /// Mirror of booking_rules.allow_past_bookings (#600) — OFF like the
  /// server default; tests flip it to exercise the backfill path.
  bool allowPastBookings = false;

  /// The fake's clock — defaults to [kTestNow], matching the
  /// FixedClock the standard overrides install (#408: the check-in
  /// window enforcement below must agree with the seeded times).
  DateTime Function() now = () => kTestNow;

  /// One place at a time (#412, 0079 trigger): a member with an ACTIVE
  /// reservation overlapping the window cannot take another — pinned
  /// substring, like the server.
  void _assertMemberFree(String memberId, DateTime start, DateTime end) {
    final busy = reservations.any((r) =>
        r.memberId == memberId &&
        r.isActive &&
        start.isBefore(r.endsAt) &&
        r.startsAt.isBefore(end));
    if (busy) {
      throw const PostgrestException(
          message: 'you already have a reservation in that period');
    }
  }

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

  /// Mirrors `sweep_day_end` (0075): with the workspace flag on, any
  /// fetch first completes past reservations nobody checked in or out.
  /// The server gates on `feature_flags.autoCheckInOut`; tests flip this
  /// bool instead.
  bool autoCheckInOut = false;

  void _sweepDayEnd(String workspaceId) {
    if (!autoCheckInOut) return;
    for (var i = 0; i < reservations.length; i++) {
      final r = reservations[i];
      if (r.workspaceId != workspaceId) continue;
      if (!r.endsAt.isBefore(kTestNow)) continue;
      if (r.status == ReservationStatus.reserved) {
        reservations[i] = r.copyWith(
          status: ReservationStatus.completed,
          checkedInAt: r.startsAt,
          checkedOutAt: r.endsAt,
        );
      } else if (r.status == ReservationStatus.checkedIn) {
        reservations[i] = r.copyWith(
          status: ReservationStatus.completed,
          checkedOutAt: r.endsAt,
        );
      }
    }
  }

  @override
  Future<List<Reservation>> fetchAllForExport(String workspaceId) async =>
      [...reservations.where((r) => r.workspaceId == workspaceId)]
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  @override
  Future<List<Reservation>> fetchWindow(
    String workspaceId, {
    required DateTime from,
    required DateTime to,
  }) async {
    _sweepDayEnd(workspaceId);
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
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
    bool checkIn = false,
  }) async {
    final targets =
        [seatId, deskId, officeId, levelId].whereType<String>().length;
    if (targets != 1) {
      throw StateError('exactly one of seat, desk, office or level required');
    }
    // #600 guards, mirroring create_reservation v10: past means the
    // booking's workspace-local DAY already ended, not its instant.
    final lastDay = WorkspaceTime.dateOf(
        endsAt.subtract(const Duration(seconds: 1)));
    if (lastDay.isBefore(WorkspaceTime.dateOf(now())) &&
        !allowPastBookings) {
      throw StateError('the booking lies entirely in the past');
    }
    if (checkIn &&
        WorkspaceTime.dateOf(startsAt) != WorkspaceTime.dateOf(now())) {
      throw StateError('a walk-up check-in must start today');
    }
    // #573 — a day-based walk-up check-in books the SLOT the chosen end
    // belongs to: the start snaps back; if the early slot part is taken,
    // ONE retry anchors at now() (mirroring create_reservation v9).
    var snapped = false;
    if (checkIn && granularity.isDayBased) {
      final canon = _canonicalStartFor(startsAt, endsAt);
      if (canon != null && canon.isBefore(startsAt)) {
        startsAt = canon;
        snapped = true;
      }
    }
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        _validateCreate(
          seatId: seatId,
          deskId: deskId,
          officeId: officeId,
          levelId: levelId,
          startsAt: startsAt,
          endsAt: endsAt,
        );
        break;
      } catch (_) {
        if (attempt == 1 &&
            snapped &&
            startsAt.isBefore(now()) &&
            now().isBefore(endsAt)) {
          startsAt = now();
        } else {
          rethrow;
        }
      }
    }
    final reservation = Reservation(
      id: 'res-${_nextId++}',
      workspaceId: workspaceId,
      seatId: seatId,
      deskId: deskId,
      officeId: officeId,
      levelId: levelId,
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

  /// canonical_walkup_start (0113): the slot start pairing with the
  /// chosen end, or null for overtime/odd windows.
  DateTime? _canonicalStartFor(DateTime startsAt, DateTime endsAt) {
    final day = startsAt;
    final morning = HalfDayWindows.morning(day);
    final afternoon = HalfDayWindows.afternoon(day);
    final full = HalfDayWindows.fullDay(day);
    if (granularity == BookingGranularity.halfDay) {
      if (endsAt == morning.end) return morning.start;
      if (endsAt == full.end) {
        return startsAt.isBefore(afternoon.start)
            ? full.start
            : afternoon.start;
      }
      return null;
    }
    return endsAt == full.end ? full.start : null;
  }

  void _validateCreate({
    String? seatId,
    String? deskId,
    String? officeId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    if (levelId != null &&
        reservations.any((r) =>
            r.levelId == levelId && r.coversRange(startsAt, endsAt))) {
      throw StateError('the level has reservations in that period');
    }
    if (deskId != null &&
        reservations.any((r) =>
            r.deskId == deskId && r.coversRange(startsAt, endsAt))) {
      throw StateError('conflict');
    }
    if (_overlapsActive(seatId, officeId, startsAt, endsAt)) {
      throw StateError('conflict');
    }
    _assertMemberFree(myMemberId, startsAt, endsAt);
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
      <({String subjectMemberId, String? seatId, String? levelId,
        DateTime startsAt})>[];

  @override
  Future<String> createFor({
    required String workspaceId,
    required String subjectMemberId,
    String? seatId,
    String? levelId,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    if ((seatId == null) == (levelId == null)) {
      throw StateError('exactly one of seat or level required');
    }
    if (_overlapsActive(seatId, null, startsAt, endsAt)) {
      throw StateError('conflict');
    }
    _assertMemberFree(subjectMemberId, startsAt, endsAt);
    bookedForOthers.add(
      (
        subjectMemberId: subjectMemberId,
        seatId: seatId,
        levelId: levelId,
        startsAt: startsAt,
      ),
    );
    reservations.add(
      Reservation(
        id: 'res-${_nextId++}',
        workspaceId: workspaceId,
        seatId: seatId,
        levelId: levelId,
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
    // Presence rule (#408 → #573, migration 0113): 15-minute leeway
    // (one grid step for minute grids), OR the reservation's own
    // workspace day under day-based/hours granularity — being early on
    // your own slot's day is presence. Pinned substrings.
    final at = now();
    var leeway = Reservation.checkInLeeway;
    final step = granularity.stepMinutes;
    if (step != null && step > leeway.inMinutes) {
      leeway = Duration(minutes: step);
    }
    final sameDay = granularity.offersDayWindows &&
        at.year == r.startsAt.year &&
        at.month == r.startsAt.month &&
        at.day == r.startsAt.day;
    if (at.isBefore(r.startsAt.subtract(leeway)) && !sameDay) {
      throw const PostgrestException(message: 'check-in window not open yet');
    }
    if (!at.isBefore(r.endsAt)) {
      throw const PostgrestException(message: 'check-in window closed');
    }
    // 0079 mirror: stale check-ins complete at their own end; a check-in
    // still RUNNING elsewhere refuses.
    for (final other in reservations
        .where((o) =>
            o.memberId == r.memberId &&
            o.id != r.id &&
            o.status == ReservationStatus.checkedIn)
        .toList()) {
      if (other.endsAt.isAfter(at)) {
        throw const PostgrestException(message: 'already checked in elsewhere');
      }
      _replace(other.copyWith(
          status: ReservationStatus.completed, checkedOutAt: other.endsAt));
    }
    _replace(
      r.copyWith(status: ReservationStatus.checkedIn, checkedInAt: at),
    );
  }

  /// (action, badgeToken, seatId, levelId) of kiosk_act calls (0043/0050).
  final kioskActs = <({
    String action,
    String badgeToken,
    String? seatId,
    String? levelId,
    DateTime? startsAt,
    DateTime? endsAt,
  })>[];

  @override
  Future<String> kioskIdentify({
    required String workspaceId,
    required String badgeToken,
  }) async {
    if (badgeToken == 'bad-badge') {
      throw const PostgrestException(message: 'badge not recognized');
    }
    return 'Flo';
  }

  @override
  Future<String> kioskAct({
    required String workspaceId,
    required String badgeToken,
    required String action,
    String? seatId,
    String? levelId,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    // The sentinel token models an unknown/revoked badge (kiosk_act's
    // pinned refusal, 0043).
    if (badgeToken == 'bad-badge') {
      throw const PostgrestException(message: 'badge not recognized');
    }
    // #430: the one-place trigger refusing a kiosk walk-up while the
    // badge member is active elsewhere — pinned substring.
    if (badgeToken == 'busy-badge') {
      throw const PostgrestException(
          message: 'you already have a reservation in that period');
    }
    kioskActs.add((
      action: action,
      badgeToken: badgeToken,
      seatId: seatId,
      levelId: levelId,
      startsAt: startsAt,
      endsAt: endsAt,
    ));
    return 'res-kiosk-${kioskActs.length}';
  }

  @override
  Future<void> checkOut(String reservationId) async {
    final r = _byId(reservationId);
    if (r.status != ReservationStatus.checkedIn) {
      throw StateError('not checked in');
    }
    // #600 complete_check_out: the completed row records the REAL
    // presence — an early same-day check-in (0113) can sit before
    // startsAt, so the window becomes [checkedInAt, now), floored at
    // one minute, never end <= start.
    final at = now();
    var start = r.startsAt;
    final checkedIn = r.checkedInAt;
    if (checkedIn != null && checkedIn.isBefore(start)) start = checkedIn;
    var end = at.isBefore(r.endsAt) ? at : r.endsAt;
    if (!end.isAfter(start)) end = start.add(const Duration(minutes: 1));
    _replace(r.copyWith(
      status: ReservationStatus.completed,
      checkedOutAt: at,
      startsAt: start,
      endsAt: end,
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
    // update_reservation v2 (0113): a RUNNING booking may only move its
    // end (later than now); anything not active is uneditable.
    if (r.status == ReservationStatus.checkedIn) {
      if (startsAt != r.startsAt) {
        throw const PostgrestException(
            message: 'a running booking keeps its start');
      }
      if (!endsAt.isAfter(now())) {
        throw const PostgrestException(
            message: 'the new end must lie ahead');
      }
    } else if (r.status != ReservationStatus.reserved) {
      throw const PostgrestException(
          message: 'only upcoming reservations can be edited');
    }
    if (_overlapsActive(r.seatId, r.officeId, startsAt, endsAt,
        ignoreId: reservationId)) {
      throw StateError('seat already reserved in that window');
    }
    reservations[i] = r.copyWith(startsAt: startsAt, endsAt: endsAt);
  }

  @override
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
        // Seat overlap check for seat series; whole-space fakes lean on
        // the widget-level conflict displays (the server re-checks).
        if (seatId != null && _overlapsActive(seatId, null, start, end)) {
          skipped.add(start);
        } else if (reservations.any((r) =>
            r.memberId == myMemberId &&
            r.isActive &&
            start.isBefore(r.endsAt) &&
            r.startsAt.isBefore(end))) {
          // 0079 trigger mirror: member-busy dates land in the skip
          // report, exactly like target conflicts.
          skipped.add(start);
        } else {
          reservations.add(
            Reservation(
              id: 'res-${_nextId++}',
              workspaceId: workspaceId,
              seatId: seatId,
              deskId: deskId,
              officeId: officeId,
              levelId: levelId,
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
