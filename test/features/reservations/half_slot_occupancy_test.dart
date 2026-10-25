// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #236 / #2603 — who holds a Week-grid half-slot, as a table on
// halfSlotOccupancy (no taps): any overlap occupies, mine wins over others,
// the first overlapping reservation names the occupant. The hub's Week view
// keeps one wiring test for the tones and the initial.
import 'package:deskilo/features/reservations/domain/half_slot_occupancy.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, [int m = 0]) => DateTime.utc(2026, 5, 13, h, m);

Reservation _r(
  String id,
  String member,
  DateTime from,
  DateTime to, {
  ReservationStatus status = ReservationStatus.reserved,
}) => Reservation(
  id: id,
  workspaceId: 'ws-1',
  seatId: 'seat-4',
  memberId: member,
  startsAt: from,
  endsAt: to,
  status: status,
);

void main() {
  // The display halves of the day: 00:00–13:00 and 13:00–24:00.
  final am = (start: _at(0), end: _at(13));
  final pm = (start: _at(13), end: DateTime.utc(2026, 5, 14));

  final mineEarly = _r('mine-early', 'me', _at(1, 15), _at(5, 15));
  final othersAfternoon = _r('ana-pm', 'ana', _at(15), _at(19));
  final othersFullDay = _r('ana-day', 'ana', _at(0), DateTime.utc(2026, 5, 14));
  final mineMorning = _r('mine-am', 'me', _at(9), _at(11));
  final othersMorning = _r('ana-am', 'ana', _at(8), _at(10));
  final cancelled = _r(
    'mine-cancelled',
    'me',
    _at(9),
    _at(11),
    status: ReservationStatus.cancelled,
  );

  final table =
      <
        String,
        (
          List<Reservation>,
          ({DateTime start, DateTime end}),
          HalfSlotHolder,
          String?,
        )
      >{
        'no reservation: free': (const [], am, HalfSlotHolder.none, null),
        'mine 01:15–05:15 holds the morning': (
          [mineEarly],
          am,
          HalfSlotHolder.mine,
          'mine-early',
        ),
        '…and leaves the afternoon free': (
          [mineEarly],
          pm,
          HalfSlotHolder.none,
          null,
        ),
        "another member's 15:00–19:00 holds the afternoon": (
          [othersAfternoon],
          pm,
          HalfSlotHolder.others,
          'ana-pm',
        ),
        '…and leaves the morning free': (
          [othersAfternoon],
          am,
          HalfSlotHolder.none,
          null,
        ),
        'a full day holds the morning': (
          [othersFullDay],
          am,
          HalfSlotHolder.others,
          'ana-day',
        ),
        'a full day holds the afternoon': (
          [othersFullDay],
          pm,
          HalfSlotHolder.others,
          'ana-day',
        ),
        'mine and another overlap: mine': (
          [mineMorning, othersMorning],
          am,
          HalfSlotHolder.mine,
          'mine-am',
        ),
        'a released or cancelled booking holds nothing': (
          [cancelled],
          am,
          HalfSlotHolder.none,
          null,
        ),
      };

  test('mine wins whatever the order the day lists them in', () {
    final o = halfSlotOccupancy(
      [othersMorning, mineMorning],
      start: am.start,
      end: am.end,
      myMemberId: 'me',
    );
    expect(o.holder, HalfSlotHolder.mine);
  });

  for (final MapEntry(key: name, value: (items, half, holder, covering))
      in table.entries) {
    test(name, () {
      final o = halfSlotOccupancy(
        items,
        start: half.start,
        end: half.end,
        myMemberId: 'me',
      );
      expect((o.holder, o.covering?.id), (holder, covering));
    });
  }
}
