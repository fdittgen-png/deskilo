// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till draws its published layout: an item key rings its item up, a key whose item is no longer sold says
// so and is disabled (never a crash), Take cash and Next customer call the till's own commands; with till layouts off,
// or no published layout, the till keeps the generated keys of #4366 unchanged.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_layouts.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_layout.dart';
import 'package:deskilo/features/money/presentation/till_layout/till_layout_keys.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/providers/till_layout_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
const _till = 'till-1';
const _milk = TillKey(id: 'demo-item-milk', name: 'Oat milk', unit: 'l');

/// A store whose published layout of [_till] holds the milk, a key of an item no longer sold, Take cash and Next customer.
Future<DemoTillLayouts> _published() async {
  final store = DemoTillLayouts(items: {'demo-item-milk', 'demo-item-gone'});
  final grid = TillGrid(cols: 4, rows: 5, cells: [
    TillCell(kindWire: TillWidgetKind.itemKey.wire, col: 0, row: 0, params: tillItemKeyParams('demo-item-milk', 'Oat milk')),
    TillCell(kindWire: TillWidgetKind.itemKey.wire, col: 1, row: 0, params: tillItemKeyParams('demo-item-gone', 'Old bread')),
    TillCell(kindWire: TillWidgetKind.functionKey.wire, col: 0, row: 1, params: const {tillCellFunctionParam: 'pay_cash'}),
    TillCell(kindWire: TillWidgetKind.functionKey.wire, col: 1, row: 1, params: const {tillCellFunctionParam: 'next_customer'}),
    TillCell(kindWire: TillWidgetKind.keypad.wire, col: 0, row: 2, colSpan: 2, rowSpan: 3),
    TillCell(kindWire: TillWidgetKind.calculator.wire, col: 2, row: 2, colSpan: 2, rowSpan: 3),
  ]);
  final layout = TillLayout(name: 'Front', pages: [TillPage(name: 'Sale', grids: {for (final s in TillLayoutSize.values) s: grid})]);
  final v = await store.save('ws-1', requestId: 'r1', tillId: _till, layout: layout, expectedVersion: 0);
  await store.publish('ws-1', requestId: 'r2', tillId: _till, expectedVersion: v);
  return store;
}

late TillSession _session;

Future<List<String>> _open(WidgetTester tester, DemoTillLayouts store, {required bool on}) async {
  final calls = <String>[];
  _session = TillSession(port: DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20), workspaceId: 'ws-1');
  await pumpApp(
    tester,
    Scaffold(
      body: TillKeysOrLayout(
        workspaceId: 'ws-1',
        tillId: _till,
        items: const AsyncValue.data([_milk]),
        session: _session,
        onTap: (k, typed) => calls.add('tap ${k.id} ${typed ?? '-'}'),
        onPayCash: () => calls.add('pay'),
      ),
    ),
    overrides: [
      ...standardTestOverrides(),
      tillLayoutPortProvider.overrideWithValue(store),
      tillLayoutsOnProvider.overrideWithValue(on),
    ],
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return calls;
}

void main() {
  testWidgets('the published layout rings up its item, runs its function keys, and disables a key no longer sold', (tester) async {
    final calls = await _open(tester, await tester.runAsync(_published) as DemoTillLayouts, on: true);
    expect(find.byKey(const ValueKey('till-layout-keys')), findsOneWidget);
    expect(find.byKey(const ValueKey('till-keys')), findsNothing);
    await tester.tap(find.text('Oat milk'));
    await tester.ensureVisible(find.text(_en.tillPayCash));
    await tester.tap(find.text(_en.tillPayCash));
    expect(calls, ['tap demo-item-milk -', 'pay']);
    final gone = find.byKey(const ValueKey('till-layout-key-1'));
    expect(find.descendant(of: gone, matching: find.textContaining(_en.tillLayoutGone)), findsOneWidget);
    expect(tester.widget<OutlinedButton>(gone).onPressed, isNull);
  });

  testWidgets('a quantity typed on the keypad goes with the next item, once', (tester) async {
    final calls = await _open(tester, await tester.runAsync(_published) as DemoTillLayouts, on: true);
    for (final k in ['1', '.', '5']) {
      await tester.ensureVisible(find.byKey(ValueKey('till-keypad-$k')));
      await tester.tap(find.byKey(ValueKey('till-keypad-$k')));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('till-keypad-shown'))).data, '1.5');
    await tester.ensureVisible(find.text('Oat milk'));
    await tester.tap(find.text('Oat milk'));
    await tester.tap(find.text('Oat milk'));
    expect(calls, ['tap demo-item-milk 1.5', 'tap demo-item-milk -']);
  });

  testWidgets('the calculator puts its result onto the last line as its quantity', (tester) async {
    await _open(tester, await tester.runAsync(_published) as DemoTillLayouts, on: true);
    await tester.runAsync(() => _session.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l'));
    for (final k in ['till-calc-2', 'till-calc-multiply', 'till-calc-3', 'till-calc-equals']) {
      await tester.ensureVisible(find.byKey(ValueKey(k)));
      await tester.tap(find.byKey(ValueKey(k)));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('till-calc-shown'))).data, '6');
    await tester.ensureVisible(find.byKey(const ValueKey('till-calc-push')));
    await tester.tap(find.byKey(const ValueKey('till-calc-push')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(_session.state.value.lines.last.quantity, '6');
  });

  testWidgets('with till layouts off, the till keeps its generated keys', (tester) async {
    await _open(tester, await tester.runAsync(_published) as DemoTillLayouts, on: false);
    expect(find.byKey(const ValueKey('till-keys')), findsOneWidget);
    expect(find.byKey(const ValueKey('till-layout-keys')), findsNothing);
  });

  testWidgets('a till without a published layout keeps its generated keys', (tester) async {
    await _open(tester, DemoTillLayouts(), on: true);
    expect(find.byKey(const ValueKey('till-keys')), findsOneWidget);
  });
}
