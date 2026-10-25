// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2375 — the BU-Schlüssel of each German rate group ships in the bundled
// tax reference: a sale booked to a revenue account that is not automatic
// carries the key of its rate (3 for 19 %, 2 for 7 %), so DATEV computes the
// tax. The key does not depend on the chart: SKR03 and SKR04 read the same
// `datev/tax:<group>` rows.
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/core/vat/tax_value.dart';
import 'package:deskilo/features/money/domain/datev_revenue.dart';
import 'package:flutter_test/flutter_test.dart';

String? _key(String group) =>
    datevGroupTaxKey(ActiveTaxReference.current, group);

void main() {
  test('every German rate resolves to its group\'s BU-Schlüssel', () {
    final reference = ActiveTaxReference.current;
    final keys = {
      for (final row in reference.ownRows(TaxDomain.rate, 'DE'))
        (row.value as RateValue).percent: _key(
          reference.groupOfRate('DE', (row.value as RateValue).percent, 'S'),
        ),
    };
    expect(keys, {19.0: '3', 7.0: '2'});
  });

  test('the key rows name no account and stay unconfirmed', () {
    final rows = [
      for (final row in ActiveTaxReference.current.ownRows(
        TaxDomain.accountMap,
        'DE',
      ))
        if (row.key.startsWith('datev/tax:')) row,
    ];
    expect(rows.map((r) => r.key).toSet(), {
      'datev/tax:standard',
      'datev/tax:reduced',
    });
    for (final row in rows) {
      final value = row.value as AccountMapValue;
      expect((value.format, value.account), ('datev', ''), reason: row.key);
      expect(row.confirmed, isFalse, reason: row.key);
    }
  });

  test('a group the reference has no key for answers none', () {
    expect(_key('zero'), isNull);
  });
}
