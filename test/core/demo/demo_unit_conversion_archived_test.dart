// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 (0989) -- the Demo refuses an archived unit in a new conversion, as the server does (`unit_archived`, field `unit`); a unit that
// is not archived is still taken.
import 'package:deskilo/core/demo/data/demo_unit_conversions.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an archived unit takes no new conversion; a unit that is not archived does', () async {
    final conversions = DemoUnitConversions()
      ..unitsOf = (_) => [for (final u in builtInUnits) u.code == 'cm' ? u.copyWith(archived: true) : u];
    await expectLater(
      conversions.save('ws', requestId: 'r1', conversion: const UnitConversion(fromUnit: 'cm', toUnit: 'm', factorNum: 1, factorDen: 100)),
      throwsA(isA<StockConfigRefused>().having((e) => e.field, 'field', 'unit').having((e) => e.reason, 'reason', StockRefusal.unitArchived)),
    );
    final kept = await conversions.save('ws', requestId: 'r2', conversion: const UnitConversion(fromUnit: 'mm', toUnit: 'm', factorNum: 1, factorDen: 1000));
    expect((kept.fromUnit, kept.toUnit), ('mm', 'm'));
  });
}
