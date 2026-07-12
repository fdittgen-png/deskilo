// SPDX-License-Identifier: MIT
//
// Pure resolver rules of the member directory's two indicators (#237):
// the presence resolver (online > relative last-seen, #223/#224) and the
// reservation resolver (checked in now > reserved now > next upcoming
// booking within 14 days; nothing otherwise).
import 'package:deskilo/features/members/domain/directory_status.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 7, 10, 10, 30);

Reservation _reservation({
  required String id,
  String memberId = 'member-1',
  String? seatId = 'seat-1',
  String? officeId,
  required DateTime startsAt,
  required DateTime endsAt,
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: id,
      workspaceId: 'ws-1',
      seatId: seatId,
      officeId: officeId,
      memberId: memberId,
      startsAt: startsAt,
      endsAt: endsAt,
      status: status,
    );

ReservationInfo? _resolve(List<Reservation> reservations) =>
    resolveReservationInfo(
      memberId: 'member-1',
      reservations: reservations,
      now: _now,
    );

void main() {
  group('resolveReservationInfo', () {
    test('a checked-in reservation covering now wins over everything', () {
      final checkedIn = _reservation(
        id: 'res-in',
        startsAt: _now.subtract(const Duration(hours: 1)),
        endsAt: _now.add(const Duration(hours: 1)),
        status: ReservationStatus.checkedIn,
      );
      final info = _resolve([
        // A parallel reserved-now booking (other seat) and an upcoming
        // one both lose against the check-in.
        _reservation(
          id: 'res-parallel',
          seatId: 'seat-2',
          startsAt: _now.subtract(const Duration(minutes: 10)),
          endsAt: _now.add(const Duration(minutes: 30)),
        ),
        _reservation(
          id: 'res-later',
          startsAt: _now.add(const Duration(days: 1)),
          endsAt: _now.add(const Duration(days: 1, hours: 2)),
        ),
        checkedIn,
      ]);

      expect(info, isA<CheckedInNow>());
      expect(info!.reservation, checkedIn);
    });

    test('an active reservation covering now without check-in is '
        'reserved-now and beats any upcoming booking', () {
      final current = _reservation(
        id: 'res-current',
        startsAt: _now.subtract(const Duration(minutes: 5)),
        endsAt: _now.add(const Duration(minutes: 30)),
      );
      final info = _resolve([
        _reservation(
          id: 'res-later',
          startsAt: _now.add(const Duration(hours: 3)),
          endsAt: _now.add(const Duration(hours: 4)),
        ),
        current,
      ]);

      expect(info, isA<ReservedNow>());
      expect(info!.reservation, current);
    });

    test('without a now-covering booking the EARLIEST upcoming one within '
        '14 days wins, regardless of list order', () {
      final sooner = _reservation(
        id: 'res-sooner',
        startsAt: _now.add(const Duration(days: 2)),
        endsAt: _now.add(const Duration(days: 2, hours: 2)),
      );
      final info = _resolve([
        _reservation(
          id: 'res-later',
          startsAt: _now.add(const Duration(days: 5)),
          endsAt: _now.add(const Duration(days: 5, hours: 2)),
        ),
        sooner,
      ]);

      expect(info, isA<UpcomingReservation>());
      expect(info!.reservation, sooner);
    });

    test('a booking starting exactly on the 14-day edge still shows; one '
        'on the 15th day does not', () {
      final edge = _reservation(
        id: 'res-edge',
        startsAt: _now.add(DirectoryReservationRules.upcomingWindow),
        endsAt: _now.add(DirectoryReservationRules.upcomingWindow +
            const Duration(hours: 2)),
      );
      expect(_resolve([edge])!.reservation, edge);

      final beyond = _reservation(
        id: 'res-beyond',
        startsAt: _now.add(DirectoryReservationRules.upcomingWindow +
            const Duration(minutes: 1)),
        endsAt: _now.add(DirectoryReservationRules.upcomingWindow +
            const Duration(hours: 2)),
      );
      expect(_resolve([beyond]), isNull);
    });

    test('cancelled, released and completed bookings never surface', () {
      expect(
        _resolve([
          // Cancelled covering now.
          _reservation(
            id: 'res-cancelled',
            startsAt: _now.subtract(const Duration(minutes: 10)),
            endsAt: _now.add(const Duration(hours: 1)),
            status: ReservationStatus.cancelled,
          ),
          // Completed covering now (checked out early).
          _reservation(
            id: 'res-completed',
            startsAt: _now.subtract(const Duration(hours: 2)),
            endsAt: _now.add(const Duration(minutes: 30)),
            status: ReservationStatus.completed,
          ),
          // Released upcoming.
          _reservation(
            id: 'res-released',
            startsAt: _now.add(const Duration(days: 1)),
            endsAt: _now.add(const Duration(days: 1, hours: 2)),
            status: ReservationStatus.released,
          ),
        ]),
        isNull,
      );
    });

    test('other members\' bookings and an empty list resolve to null', () {
      expect(_resolve(const []), isNull);
      expect(
        _resolve([
          _reservation(
            id: 'res-other',
            memberId: 'member-2',
            startsAt: _now.subtract(const Duration(minutes: 10)),
            endsAt: _now.add(const Duration(hours: 1)),
            status: ReservationStatus.checkedIn,
          ),
        ]),
        isNull,
      );
    });
  });

  group('resolveDirectoryPresence', () {
    test('a fresh heartbeat is online', () {
      final presence = resolveDirectoryPresence(
        lastSeenAt: _now.subtract(const Duration(minutes: 1)),
        now: _now,
      );
      expect(presence.kind, DirectoryPresenceKind.online);
    });

    test('a stale heartbeat is offline and carries lastSeenAt for the '
        'relative label', () {
      final lastSeen = _now.subtract(const Duration(hours: 2));
      final presence = resolveDirectoryPresence(lastSeenAt: lastSeen, now: _now);
      expect(presence.kind, DirectoryPresenceKind.offline);
      expect(presence.lastSeenAt, lastSeen);
    });

    test('never seen is offline without a timestamp (no chip)', () {
      final presence = resolveDirectoryPresence(lastSeenAt: null, now: _now);
      expect(presence.kind, DirectoryPresenceKind.offline);
      expect(presence.lastSeenAt, isNull);
    });
  });
}
