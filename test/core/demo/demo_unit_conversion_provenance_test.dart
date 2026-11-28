// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 (0991) -- the Demo tells a conversion a person wrote from one the units generate, as the server does: editing a unit writes its
// generated conversions again and keeps the authored one, asked to be looked at; writing it again clears the mark.
import 'package:deskilo/core/demo/data/demo_unit_conversions.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an authored conversion survives the edit of its unit, marked for review, until it is written again', () async {
    final conversions = DemoUnitConversions();
    const km = 'km';
    // the owner writes km to m as 1001: authored
    await conversions.save('ws', requestId: 'r1', conversion: const UnitConversion(fromUnit: km, toUnit: 'm', factorNum: 1001, factorDen: 1));
    UnitConversion row(String from, String to) => conversions.rows('ws').firstWhere((c) => c.fromUnit == from && c.toUnit == to);
    expect((row(km, 'm').authored, row(km, 'm').needsReview), (true, false));
    expect(row(km, 'cm').authored, isFalse, reason: 'the others are generated');

    // the unit is edited: its generated rows are written again, the authored one stays
    final unit = builtInUnits.firstWhere((u) => u.code == km);
    conversions.unitSaved('ws', unit, builtInUnits);
    expect((row(km, 'm').factorNum, row(km, 'm').authored, row(km, 'm').needsReview), (1001, true, true));
    expect(row(km, 'cm').needsReview, isFalse);

    // writing it again is the review
    await conversions.save('ws', requestId: 'r2', conversion: const UnitConversion(fromUnit: km, toUnit: 'm', factorNum: 1000, factorDen: 1));
    expect((row(km, 'm').authored, row(km, 'm').needsReview), (true, false));
  });
}
