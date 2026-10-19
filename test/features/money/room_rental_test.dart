// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2568 -- the rented-room wire models: a rental reads as the server writes
// it, the window includes both of its days and names the cause of a refusal,
// and the offer a member is shown carries the fee for them and nothing else.
import 'package:deskilo/features/money/domain/room_level_kind.dart';
import 'package:deskilo/features/money/domain/room_rental.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _rental({String status = 'active'}) => {
  'id': 'r1',
  'revision': 3,
  'office_id': 'o1',
  'office_name': 'Rented room',
  'supplier_id': 's1',
  'supplier_name': 'Landlord SA',
  'available_from': '2027-03-01',
  'available_until': '2027-08-31',
  'cost_kind': 'fixed_per_period',
  'cost_cents': 40000,
  'period': 'month',
  'currency': 'EUR',
  'status': status,
  'audience': [
    {'plan_id': 'p1'},
    {'member_id': 'm4'},
  ],
  'fees': [
    {'unit': 'half_day', 'fee_cents': 1500},
    {'unit': 'half_day', 'fee_cents': 1000, 'member_id': 'm4'},
  ],
};

void main() {
  test('the rental reads as the server writes it', () {
    final r = RoomRental.fromJson(_rental());
    expect(r.revision, 3);
    expect(r.supplierName, 'Landlord SA');
    expect(r.audience.map((a) => a.planId ?? a.memberId), ['p1', 'm4']);
    expect(r.fees.last.audience.memberId, 'm4');
    expect(r.fees.first.toJson(), {'unit': 'half_day', 'fee_cents': 1500});
  });

  test('the window is inclusive of both days, and names the cause', () {
    final r = RoomRental.fromJson(_rental());
    expect(r.windowRefusal(DateTime(2027, 3), DateTime(2027, 3)), isNull);
    expect(r.windowRefusal(DateTime(2027, 8, 31), DateTime(2027, 8, 31)), isNull);
    expect(
      r.windowRefusal(DateTime(2027, 9), DateTime(2027, 9)),
      RoomWindowRefusal.afterEnd,
    );
    expect(
      r.windowRefusal(DateTime(2027, 8, 31), DateTime(2027, 9)),
      RoomWindowRefusal.afterEnd,
    );
    expect(
      r.windowRefusal(DateTime(2027, 2, 28), DateTime(2027, 2, 28)),
      RoomWindowRefusal.beforeStart,
    );
  });

  test('a draft or ended rental is not rented, whatever the dates', () {
    final r = RoomRental.fromJson(_rental(status: 'draft'));
    expect(
      r.windowRefusal(DateTime(2027, 4), DateTime(2027, 4)),
      RoomWindowRefusal.notRented,
    );
  });

  test('an open-ended rental has no end to refuse', () {
    final json = _rental()..['available_until'] = null;
    final r = RoomRental.fromJson(json);
    expect(r.windowRefusal(DateTime(2031), DateTime(2031)), isNull);
  });

  test('the offer carries what a use costs the member and nothing else', () {
    final offer = RoomOffer.fromJson({
      'office_id': 'o1',
      'available_from': '2027-03-01',
      'available_until': null,
      'currency': 'EUR',
      'fees': [
        {'unit': 'half_day', 'fee_cents': 1500},
      ],
    });
    expect(offer.feeFor(RoomFeeUnit.halfDay), 1500);
    expect(offer.feeFor(RoomFeeUnit.hour), isNull);
    expect(offer.availableUntil, isNull);
  });

  test('an unknown level kind reads as the space\'s own', () {
    expect(LevelKind.of('external'), LevelKind.external);
    expect(LevelKind.of('something else'), LevelKind.own);
    expect(LevelKind.of(null), LevelKind.own);
  });
}
