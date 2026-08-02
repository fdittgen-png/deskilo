// SPDX-License-Identifier: 0BSD
//
// Presence rule (#408, migration 0077): check-in means "I am standing
// here NOW". The window is [starts_at − 15 min, ends_at) — never ahead
// of it (the future), never after the reservation ended (the past).
// These tests pin the domain predicate and the fake's mirror of the
// server contract, including the pinned error substrings the UI maps.

import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Reservation _res({
  DateTime? start,
  DateTime? end,
  ReservationStatus status = ReservationStatus.reserved,
}) =>
    Reservation(
      id: 'res-1',
      workspaceId: 'ws-1',
      seatId: 'seat-4',
      memberId: 'member-1',
      startsAt: start ?? kTestNow,
      endsAt: end ?? kTestNow.add(const Duration(hours: 4)),
      status: status,
    );

void main() {
  group('checkInWindowOpen', () {
    test('open exactly 15 minutes before the start, closed a second '
        'earlier', () {
      final r = _res(start: kTestNow.add(const Duration(minutes: 15)));
      expect(r.checkInWindowOpen(kTestNow), isTrue,
          reason: 'the spec §4.3 leeway: the member is at the door');
      final tooEarly = _res(
          start: kTestNow.add(const Duration(minutes: 15, seconds: 1)));
      expect(tooEarly.checkInWindowOpen(kTestNow), isFalse,
          reason: 'ahead of the window is the FUTURE — not present yet');
    });

    test('closed from ends_at on — the past cannot be attended', () {
      final r = _res(
        start: kTestNow.subtract(const Duration(hours: 4)),
        end: kTestNow,
      );
      expect(r.checkInWindowOpen(kTestNow), isFalse,
          reason: 'end-exclusive, like coversInstant');
      final stillRunning = _res(
        start: kTestNow.subtract(const Duration(hours: 1)),
        end: kTestNow.add(const Duration(seconds: 1)),
      );
      expect(stillRunning.checkInWindowOpen(kTestNow), isTrue,
          reason: 'a late arrival during the reservation is present');
    });

    test('only a reserved booking has a window', () {
      for (final status in [
        ReservationStatus.checkedIn,
        ReservationStatus.completed,
        ReservationStatus.cancelled,
        ReservationStatus.released,
      ]) {
        expect(
          _res(
            start: kTestNow.subtract(const Duration(hours: 1)),
            status: status,
          ).checkInWindowOpen(kTestNow),
          isFalse,
          reason: '$status is not checkable-in',
        );
      }
    });
  });

  group('fake mirrors the server contract', () {
    test('future reservation: pinned "not open yet" refusal', () async {
      final repo = FakeReservationRepository()
        ..reservations.add(_res(
          start: kTestNow.add(const Duration(hours: 2)),
          end: kTestNow.add(const Duration(hours: 4)),
        ));
      await expectLater(
        repo.checkIn('res-1'),
        throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
            contains('check-in window not open yet'))),
      );
      expect(repo.reservations.single.status, ReservationStatus.reserved);
    });

    test('ended reservation: pinned "window closed" refusal', () async {
      final repo = FakeReservationRepository()
        ..reservations.add(_res(
          start: kTestNow.subtract(const Duration(hours: 4)),
          end: kTestNow.subtract(const Duration(hours: 1)),
        ));
      await expectLater(
        repo.checkIn('res-1'),
        throwsA(isA<PostgrestException>().having((e) => e.message, 'message',
            contains('check-in window closed'))),
      );
    });

    test('inside the window it checks in, stamped at now', () async {
      final repo = FakeReservationRepository()
        ..reservations.add(_res(
          start: kTestNow.add(const Duration(minutes: 10)),
          end: kTestNow.add(const Duration(hours: 4)),
        ));
      await repo.checkIn('res-1');
      final r = repo.reservations.single;
      expect(r.status, ReservationStatus.checkedIn);
      expect(r.checkedInAt, kTestNow);
    });
  });
}
