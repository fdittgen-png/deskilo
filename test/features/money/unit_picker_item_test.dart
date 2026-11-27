// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4479 -- the unit picker of an order line of a stocked item offers only the units it converts from (the stock wires the answer); a
// row with no item, or an item that is not restricted, keeps the business's units.
import 'package:deskilo/features/money/domain/line_unit.dart';
import 'package:deskilo/features/money/presentation/widgets/master_data_pickers.dart';
import 'package:deskilo/features/money/providers/pickable_units_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _all = [LineUnit(code: 'piece'), LineUnit(code: 'kg'), LineUnit(code: 'carton')];

Future<void> _open(WidgetTester tester, {String? itemId, List<LineUnit>? only}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: UnitPickerField(key: const ValueKey('picker'), workspaceId: 'ws-1', itemId: itemId, value: 'piece', label: 'Unit', onChanged: (_) {}),
    ),
    overrides: [
      pickableUnitsProvider.overrideWith((ref, ws) => _all),
      itemOrderUnitsProvider.overrideWith((ref, key) async => only == null ? null : ItemOrderUnits(units: only)),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('picker')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a stocked item offers the units it converts from, not a kilo of mugs', (tester) async {
    await _open(tester, itemId: 'mugs', only: const [LineUnit(code: 'piece'), LineUnit(code: 'carton')]);
    expect(find.text('carton'), findsWidgets);
    expect(find.text('kg'), findsNothing);
  });

  testWidgets('an item that is not restricted keeps the business\'s units', (tester) async {
    await _open(tester, itemId: 'service');
    expect(find.text('kg'), findsWidgets);
  });

  testWidgets('a row with no item keeps the business\'s units', (tester) async {
    await _open(tester);
    expect(find.text('kg'), findsWidgets);
  });
}
