// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- an item is sold in any of its units at THAT unit's price, and the server and the app say the same: the table of cases
// (unit_price_cases.dart) holds against the domain's rule row by row, and every row stands in the database file that runs it against
// `item_unit_price` (supabase/tests/database/582_item_unit_price.sql).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'unit_price_cases.dart';

const _pgTap = 'supabase/tests/database/582_item_unit_price.sql';

void main() {
  test('the table holds against the domain rule, row by row', () {
    for (final c in unitPriceCases) {
      expect(runUnitPriceCase(c), c.outcome, reason: '${c.id} ${c.name}');
    }
  });

  test('every row of the table is a row of the database file, to the letter', () {
    final sql = File(_pgTap).readAsStringSync();
    for (final c in unitPriceCases) {
      expect(sql, contains(unitPriceAsSql(c)), reason: '${c.id} is not in $_pgTap');
    }
  });
}
