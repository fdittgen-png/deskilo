// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- a conversion is defined, never implied, and the server and the app say the same: the table of cases
// (unit_convert_cases.dart) holds against the domain's rule row by row, and every row stands in the database file that runs it against
// `unit_convert` (supabase/tests/database/573_unit_convert.sql). The built-in conversions the Demo and a new business start from are
// the ones the server's `unit_conversions_link` writes.
import 'dart:io';

import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

import 'unit_convert_cases.dart';

const _pgTap = 'supabase/tests/database/573_unit_convert.sql';

void main() {
  test('the table holds against the domain rule, row by row', () {
    for (final c in unitConvertCases) {
      expect(runUnitConvertCase(c), c.outcome, reason: '${c.id} ${c.name}');
    }
  });

  test('every row of the table is a row of the database file, to the letter', () {
    final sql = File(_pgTap).readAsStringSync();
    for (final c in unitConvertCases) {
      expect(sql, contains(unitConvertAsSql(c)), reason: '${c.id} is not in $_pgTap');
    }
  });

  test('a business starts with the conversions its built-in units give: the larger converts to the smaller, nothing across dimensions', () {
    final rows = {for (final c in builtInConversions) '${c.fromUnit}>${c.toUnit}': '${c.factorNum}/${c.factorDen}'};
    expect(rows['kg>g'], '1000/1');
    expect(rows['l>cl'], '100/1');
    expect(rows['km>m'], '1000/1');
    expect(rows['h>min'], '60/1');
    expect(rows.containsKey('g>kg'), isFalse, reason: 'the reverse is the inverse factor, not a second row');
    expect(rows.keys.any((k) => k.startsWith('kg>') && !k.endsWith('>g')), isFalse, reason: 'a mass converts to a mass only');
    expect(builtInConversions, hasLength(11));
  });

  test('a packaging unit is joined to no other by a general conversion', () {
    final units = [...builtInUnits, const WorkspaceUnit(code: 'carton', dimension: UnitDimension.package, factorNum: 1, factorDen: 1)];
    expect(linkedConversions(units).where((c) => c.fromUnit == 'carton' || c.toUnit == 'carton'), isEmpty);
  });
}
