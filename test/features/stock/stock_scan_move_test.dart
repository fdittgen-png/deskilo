// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- a scanner that types, in the move sheet, at a phone and a desk width: the place scanned sets
// where the goods are taken from, a second place where they go, an item code names the item and counts it, a
// carton code adds its exact factor (12 pieces), a repeated scan asks for the quantity when the business wants it,
// a code that names nothing says so, a focused field keeps its own typing, and with the feature off a scanner is
// ignored. The scans go through the same resolver port the server answers.
import 'package:deskilo/core/demo/data/demo_stock_code_resolver.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_operations.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/features/stock/presentation/stock_transfers_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _World {
  _World() {
    ledger = DemoStockLedger('ws-1', config);
    operations = DemoStockOperations(ledger, config);
    resolver = DemoStockCodeResolver('ws-1', config, DemoStockRegistry('ws-1', ledger, config));
  }

  final config = DemoStockConfigCommands('ws-1');
  late final DemoStockLedger ledger;
  late final DemoStockOperations operations;
  late final DemoStockCodeResolver resolver;
}

Future<void> _open(WidgetTester tester, _World w, Size size, {bool scanning = true, bool addsOne = true}) async {
  await pumpApp(
    tester,
    const StockTransfersScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(w.ledger)),
      stockConfigCommandsProvider.overrideWithValue(w.config),
      stockOperationsProvider.overrideWithValue(w.operations),
      stockCodeResolverProvider.overrideWithValue(w.resolver),
      stockScanningProvider.overrideWithValue(scanning),
      stockScanAddsOneProvider.overrideWithValue(addsOne),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
      enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement}),
    ],
  );
  await _frames(tester);
  await tester.tap(find.byKey(const ValueKey('stock-move-open')));
  await _frames(tester);
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A scanner in keyboard mode: every character at once, then Enter.
Future<void> _scan(WidgetTester tester, String code) async {
  for (final ch in code.split('')) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: ch);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  await _frames(tester);
}

String? _shown(WidgetTester tester, String key) {
  final field = tester.widget<DropdownButtonFormField<String?>>(find.byKey(ValueKey(key)));
  return field.initialValue;
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('scan the place, the next place, then the items: a carton adds its 12 pieces', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _scan(tester, 'MAIN');
        expect(_shown(tester, 'stock-move-from'), 'demo-place-main');
        expect(find.byKey(const ValueKey('stock-scan-place')), findsOneWidget);
        await _scan(tester, 'SHELF-A');
        expect(_shown(tester, 'stock-move-to'), 'demo-place-shelf');
        await _scan(tester, '4006381333931');
        expect(_shown(tester, 'stock-move-item'), 'demo-item-mugs');
        expect(find.text(_en.stockScanLast('Mugs', '1', 'piece')), findsOneWidget);
        await _scan(tester, 'MUG-CARTON');
        expect(find.text(_en.stockScanLast('Mugs', '13', 'piece')), findsOneWidget, reason: '1 piece + a carton of 12');
        final before = w.ledger.balance('demo-item-mugs', 'demo-place-shelf').text;
        await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
        await _frames(tester);
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-main').text, '23');
        expect(before, '10', reason: 'the 12 shelved less the 2 sold');
        expect(w.ledger.balance('demo-item-mugs', 'demo-place-shelf').text, '23');
      });

      testWidgets('a code that names nothing is said, and nothing is filled', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await _scan(tester, '9999999999');
        expect(find.byKey(const ValueKey('stock-scan-unknown')), findsOneWidget);
        expect(find.text(_en.stockScanUnknown('9999999999')), findsOneWidget);
        expect(_shown(tester, 'stock-move-item'), isNull);
        expect(_shown(tester, 'stock-move-from'), isNull);
      });

      testWidgets('a typing person in a focused field is not taken for a scanner', (tester) async {
        final w = _World();
        await _open(tester, w, size);
        await tester.tap(find.byKey(const ValueKey('stock-move-quantity')));
        await _frames(tester);
        await _scan(tester, 'MAIN');
        expect(_shown(tester, 'stock-move-from'), isNull, reason: 'the field has the focus: it keeps its typing');
        expect(find.byKey(const ValueKey('stock-scan-place')), findsNothing);
      });

      testWidgets('when the business asks for the quantity, a repeated scan does not count: it opens the field', (tester) async {
        final w = _World();
        await _open(tester, w, size, addsOne: false);
        await _scan(tester, '4006381333931');
        expect(find.text(_en.stockScanLast('Mugs', '1', 'piece')), findsOneWidget);
        await _scan(tester, '4006381333931');
        expect(find.text(_en.stockScanLast('Mugs', '1', 'piece')), findsOneWidget, reason: 'not counted again');
        final field = tester.widget<EditableText>(find.descendant(of: find.byKey(const ValueKey('stock-move-quantity')), matching: find.byType(EditableText)));
        expect(field.focusNode.hasFocus, isTrue, reason: 'the quantity field is where the person is');
      });

      testWidgets('with the feature off a scanner is ignored and nothing of it is shown', (tester) async {
        final w = _World();
        await _open(tester, w, size, scanning: false);
        await _scan(tester, 'MAIN');
        expect(_shown(tester, 'stock-move-from'), isNull);
        expect(find.byKey(const ValueKey('stock-scan-place')), findsNothing);
      });
    });
  }
}
