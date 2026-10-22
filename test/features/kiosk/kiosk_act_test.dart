// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- what a badge does at the kiosk, how a refusal reads and
// whose booking blocks a tap, as tables on the decisions (no taps): the
// screen only maps each answer to its call and its words.
import 'package:deskilo/features/kiosk/domain/kiosk_act.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/domain/space_act.dart';
import 'package:flutter_test/flutter_test.dart';

Reservation _r(
  String id, {
  String? seat,
  String? level,
  int from = 9,
  int to = 13,
}) => Reservation(
  id: id,
  workspaceId: 'w',
  memberId: 'm-$id',
  seatId: seat,
  levelId: level,
  startsAt: DateTime(2026, 10, 22, from),
  endsAt: DateTime(2026, 10, 22, to),
  status: ReservationStatus.reserved,
);

void main() {
  group('the action sent for a badge', () {
    final table = <String, (KioskAction, bool, KioskAction, bool)>{
      'a check-in is a check-in': (
        KioskAction.checkIn,
        false,
        KioskAction.checkIn,
        true,
      ),
      'a reservation stays one': (
        KioskAction.reserve,
        false,
        KioskAction.reserve,
        true,
      ),
      'a reservation that starts now checks in at once': (
        KioskAction.reserve,
        true,
        KioskAction.checkIn,
        true,
      ),
      'a check-out books no window': (
        KioskAction.checkOut,
        true,
        KioskAction.checkOut,
        false,
      ),
    };
    for (final MapEntry(key: name, value: (asked, now, sent, window))
        in table.entries) {
      test(name, () {
        final plan = kioskActPlan(asked, checkInNow: now);
        expect(plan.action, sent);
        expect(plan.booksWindow, window);
      });
    }
  });

  group('how a refusal reads', () {
    final table = <String, KioskRefusal>{
      'badge not recognized': KioskRefusal.badgeRejected,
      'reservation not checked in': KioskRefusal.notCheckedIn,
      'that space is already reserved in that period': KioskRefusal.other,
    };
    for (final MapEntry(key: message, value: refusal) in table.entries) {
      test(message, () => expect(kioskRefusalOf(message), refusal));
    }
  });

  group('whose booking blocks the tap', () {
    final day = [_r('a', seat: 's1'), _r('b', level: 'l1', from: 14, to: 18)];
    final start = DateTime(2026, 10, 22, 10);
    final end = DateTime(2026, 10, 22, 12);
    test('the seat holder', () {
      expect(
        blockingReservation(day, seatId: 's1', start: start, end: end)?.id,
        'a',
      );
    });
    test('another seat is free', () {
      expect(
        blockingReservation(day, seatId: 's2', start: start, end: end),
        isNull,
      );
    });
    test('the level is booked only in the afternoon', () {
      expect(
        blockingReservation(day, levelId: 'l1', start: start, end: end),
        isNull,
      );
      expect(
        blockingReservation(
          day,
          levelId: 'l1',
          start: DateTime(2026, 10, 22, 15),
          end: DateTime(2026, 10, 22, 16),
        )?.id,
        'b',
      );
    });
  });
}
