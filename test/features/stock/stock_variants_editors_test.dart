// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (B2) -- the variants, dimensions and supplier articles as a person
// edits them, against the Demo's in-memory configuration (which refuses as
// the server does): a variant is one value per dimension; a duplicate
// combination is said under its variant before anything is sent; the saved
// variant reads back with its label; a dimension gains a value; a supplier
// article is mapped once and refused for a unit the item does not list.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_queries.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';
import 'package:deskilo/features/stock/presentation/stock_items_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester, DemoStockConfigCommands config, Size size) async {
  final ledger = DemoStockLedger('ws-1', config);
  await pumpApp(
    tester,
    const StockItemsScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(DemoStockQueries(ledger)),
      stockRegistryProvider.overrideWithValue(DemoStockRegistry('ws-1', ledger, config)),
      stockConfigCommandsProvider.overrideWithValue(config),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
    ],
  );
  await _settle(tester);
}

/// The Demo's T-shirt: the item whose variants and supplier articles are edited.
const _itemId = 'demo-item-shirt';

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('a variant is one value per dimension, saved and read back with its label; the same combination twice is said under it and not sent', (tester) async {
        final config = DemoStockConfigCommands('ws-1');
        await _open(tester, config, size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-edit-variants-$_itemId')), 200, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
        await tester.tap(find.byKey(const ValueKey('stock-edit-variants-$_itemId')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-variants-add')));
        await _settle(tester);
        await _choose(tester, 'stock-variant-0-demo-dim-colour', 'Red');
        await tester.tap(find.byKey(const ValueKey('stock-variants-add')));
        await _settle(tester);
        await _choose(tester, 'stock-variant-1-demo-dim-colour', 'Red');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-variants-save')));
        await tester.tap(find.byKey(const ValueKey('stock-variants-save')));
        await _settle(tester);
        expect(find.text(_en.stockReasonCombinationDuplicate), findsOneWidget);
        expect(await config.variants('ws-1', 'demo-item-shirt'), isEmpty, reason: 'a mistake the screen can see is not sent');
        await _choose(tester, 'stock-variant-1-demo-dim-colour', 'Blue');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-variants-save')));
        await tester.tap(find.byKey(const ValueKey('stock-variants-save')));
        await _settle(tester);
        final saved = await config.variants('ws-1', 'demo-item-shirt');
        expect(saved.map((v) => v.label), ['Colour: Red', 'Colour: Blue']);
        expect((await config.item('ws-1', 'demo-item-shirt'))!.revision, 2, reason: 'the item revision moved with the variants');
      });

      testWidgets('a dimension gains a value, and the variant editor offers it', (tester) async {
        final config = DemoStockConfigCommands('ws-1');
        await _open(tester, config, size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-edit-variants-$_itemId')), 200, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
        await tester.tap(find.byKey(const ValueKey('stock-edit-variants-$_itemId')));
        await _settle(tester);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-dimensions-manage')));
        await tester.tap(find.byKey(const ValueKey('stock-dimensions-manage')));
        await _settle(tester);
        await tester.tap(find.byKey(const ValueKey('stock-dimension-demo-dim-size')));
        await _settle(tester);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-dimension-add-value')));
        await tester.tap(find.byKey(const ValueKey('stock-dimension-add-value')));
        await _settle(tester);
        await tester.enterText(find.byKey(const ValueKey('stock-dimension-value-2')), 'XL');
        await tester.ensureVisible(find.byKey(const ValueKey('stock-dimension-save')));
        await tester.tap(find.byKey(const ValueKey('stock-dimension-save')));
        await _settle(tester);
        final sizes = (await config.dimensions('ws-1')).firstWhere((d) => d.id == 'demo-dim-size');
        expect(sizes.values.map((v) => v.label), ['M', 'L', 'XL']);
        expect(sizes.revision, 2);
      });

      testWidgets('a supplier article is mapped to the item; the same article twice is refused under its field', (tester) async {
        final config = DemoStockConfigCommands('ws-1');
        await _open(tester, config, size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-edit-mappings-$_itemId')), 200, scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
        await tester.tap(find.byKey(const ValueKey('stock-edit-mappings-$_itemId')));
        await _settle(tester);
        expect(find.byKey(const ValueKey('stock-mappings-none')), findsOneWidget);
        for (final attempt in [1, 2]) {
          await tester.tap(find.byKey(const ValueKey('stock-mapping-add')));
          await _settle(tester);
          await _choose(tester, 'stock-mapping-supplier', 'Textiles Nord');
          await tester.enterText(find.byKey(const ValueKey('stock-mapping-article')), 'TX-100');
          await tester.ensureVisible(find.byKey(const ValueKey('stock-mapping-save')));
          await tester.tap(find.byKey(const ValueKey('stock-mapping-save')));
          await _settle(tester);
          if (attempt == 1) {
            expect((await config.mappings('ws-1')).where((m) => m.articleRef == 'TX-100'), hasLength(1));
          } else {
            expect(find.text(_en.stockReasonMappingDuplicate), findsOneWidget);
            expect((await config.mappings('ws-1')).where((m) => m.articleRef == 'TX-100'), hasLength(1), reason: 'nothing was saved twice');
          }
        }
      });
    });
  }

  test('the Demo refuses what the server refuses: a stale item revision, a unit the item lacks, a value of another dimension', () async {
    final config = DemoStockConfigCommands('ws-1');
    await expectLater(
      config.saveVariants('ws-1', 'demo-item-shirt', variants: const [], expectedRevision: 9, requestId: 'r'),
      throwsA(isA<StockConfigStale>()),
    );
    await expectLater(
      config.saveMapping('ws-1', mapping: const SupplierMappingDraft(supplierId: 'demo-supplier-1', itemId: 'demo-item-shirt', articleRef: 'A', purchaseUnit: 'box', active: true), requestId: 'r'),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.unitNotOfItem)),
    );
    await expectLater(
      config.saveVariants('ws-1', 'demo-item-shirt', variants: const [StockVariant(id: null, values: {'demo-dim-colour': 'demo-val-m'}, priceCents: null, active: true, label: '')], expectedRevision: 1, requestId: 'r'),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', StockRefusal.valueForeign)),
    );
  });
}
