// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — naming a house's prices: the rows still to name are its inactive
// services and packages; a row's hint proposes the house's one active rate of
// that category, and none when the house has no such rate or more than one.
import 'package:deskilo/features/money/domain/house_prices.dart';
import 'package:deskilo/features/money/domain/package.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceItem _service(String id, {bool active = false}) => ServiceItem(
  id: id,
  workspaceId: 'house',
  name: id,
  priceCents: 0,
  active: active,
);

Package _package(String id, {bool active = false}) => Package(
  id: id,
  workspaceId: 'house',
  name: id,
  days: 10,
  priceCents: 0,
  active: active,
);

void main() {
  test('the rows to name are the inactive services, then the inactive '
      'packages', () {
    final rows = houseRowsToName(
      services: [_service('Coffee'), _service('Locker', active: true)],
      packages: [_package('Ten days')],
    );
    expect(
      [for (final r in rows) (r.kind, r.id)],
      [(HouseRowKind.services, 'Coffee'), (HouseRowKind.packages, 'Ten days')],
    );
  });

  group('the rate a hint proposes', () {
    final row = houseRowsToName(
      services: [_service('Coffee')],
      packages: const [],
    ).single;
    const hints = {'services:Coffee': 'S'};
    const standard = VatRate(id: 'r-23', label: '23 %', percent: 23);
    const reduced = VatRate(
      id: 'r-8',
      label: '8 %',
      percent: 8,
      groupKey: 'reduced',
    );
    const zero = VatRate(id: 'r-0', label: '0 %', percent: 0, category: 'Z');

    test('the one active rate of the category', () {
      expect(proposedHouseRate(row, hints, [standard, zero])?.id, 'r-23');
    });

    test('none when two rates share the category: the owner chooses', () {
      expect(proposedHouseRate(row, hints, [standard, reduced]), isNull);
    });

    test('none when the house has no rate of it, or no hint was given', () {
      expect(proposedHouseRate(row, hints, [zero]), isNull);
      expect(proposedHouseRate(row, const {}, [standard]), isNull);
    });
  });
}
