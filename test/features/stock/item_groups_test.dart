// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- item groups as a person uses them, on the Demo's in-memory groups (the server's rules), at a
// phone and a desk width: the groups are listed with their items and settings; a change to a group is PREVIEWED
// (what it reaches, what keeps its own value) and only a second save applies it, and the history says what
// changed; a sub-group cannot have sub-groups and per-piece tags need tracking by piece, in words; an empty group
// can be deleted; an item shows where each setting comes from and an own value goes back to the group's; moving
// an item previews how many settings change.
import 'package:deskilo/core/demo/data/demo_item_groups.dart';
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/ui/dropdown_field.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/presentation/item_group_assign_dialog.dart';
import 'package:deskilo/features/stock/presentation/item_groups_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_item_editor.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The Demo's stock settings whose read of the places fails.
class _NoPlaces extends DemoStockConfigCommands {
  _NoPlaces() : super('ws-1');

  @override
  Future<List<StockPlaceConfig>> places(String workspaceId) => Future.error(Exception('places down'));
}

Future<DemoItemGroups> _open(
  WidgetTester tester,
  Size size, {
  Widget? home,
  bool places = true,
  bool finance = false,
  Future<void> Function(DemoItemGroups groups)? seed,
}) async {
  final config = places ? DemoStockConfigCommands('ws-1') : _NoPlaces();
  final groups = DemoItemGroups('ws-1', config, () => DateTime(2026, 11, 22));
  await seed?.call(groups);
  await pumpApp(
    tester,
    home ?? const ItemGroupsScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      itemGroupsProvider.overrideWithValue(groups),
      stockConfigCommandsProvider.overrideWithValue(config),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock, if (finance) ...{WorkspacePermission.manageServices, WorkspacePermission.viewFinances}}),
      vatRatesProvider.overrideWith((ref) async => const [VatRate(id: 'vat-std', label: 'Standard 20 %', percent: 20, isDefault: true), VatRate(id: 'vat-red', label: 'Reduced 5.5 %', percent: 5.5), VatRate(id: 'demo-vat-20', label: 'Demo standard 20 %', percent: 20)]),
      enabledFeaturesSyncProvider.overrideWithValue({WorkspaceFeature.stockManagement, WorkspaceFeature.stockItemGroups}),
    ],
  );
  await _frames(tester);
  return groups;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _frames(tester);
}

Future<void> _choose(WidgetTester tester, String key, String text) async {
  await _tap(tester, key);
  await tester.tap(find.text(text).last);
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the groups are listed with their items and settings', (tester) async {
        await _open(tester, size);
        expect(find.text('Drinks'), findsOneWidget);
        expect(find.textContaining(_en.stockCyclePlanItemsCount(2)), findsOneWidget);
        expect(find.text('Hot drinks'), findsOneWidget);
        expect(find.text('Homeware'), findsOneWidget);
      });

      testWidgets('a change is previewed first and applied by a second save; the history says it', (tester) async {
        final w = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('item-group-demo-group-drinks')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('item-group-shelf')), '120');
        await _tap(tester, 'item-group-save');
        expect(find.byKey(const ValueKey('item-group-preview')), findsOneWidget);
        expect(find.text(_en.itemGroupPreviewLine(_en.stockEditShelfLife, 1, 1, 0)), findsOneWidget, reason: 'the milk follows; the syrup keeps its own; the beans have their sub-group');
        expect(find.text(_en.itemGroupConfirm), findsOneWidget);
        expect((await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks').params['shelf_life_days'], 180, reason: 'a preview applies nothing');
        await _tap(tester, 'item-group-save');
        expect((await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks').params['shelf_life_days'], 120);
        expect((await w.history('ws-1', groupId: 'demo-group-drinks')).single.affected, 1);
      });

      testWidgets('a group with sub-groups cannot become a sub-group', (tester) async {
        await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('item-group-demo-group-drinks')));
        await _frames(tester);
        await _choose(tester, 'item-group-parent', 'Homeware');
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.itemGroupReasonDepth), findsOneWidget);
      });

      testWidgets('per-piece tags need tracking by piece', (tester) async {
        await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Gift baskets');
        await _choose(tester, 'item-group-tag-mode', _en.itemGroupTagUnit);
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.itemGroupReasonNeedsSerial), findsOneWidget);
      });

      testWidgets('a group carries what it proposes to a new item: the purchase unit with its factor, the reorder point and quantity, the home zone', (tester) async {
        final w = await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Dry goods');
        await _choose(tester, 'item-group-purchase-unit', 'kg');
        await tester.enterText(find.byKey(const ValueKey('item-group-factor')), '12');
        await tester.enterText(find.byKey(const ValueKey('item-group-reorder-point')), '5.5');
        await tester.enterText(find.byKey(const ValueKey('item-group-reorder-qty')), '20');
        await _choose(tester, 'item-group-home-zone', 'Back room');
        await _tap(tester, 'item-group-save');
        final saved = (await w.groups('ws-1')).firstWhere((g) => g.name == 'Dry goods');
        expect(saved.params['default_purchase_unit'], 'kg');
        expect((saved.params['default_purchase_factor_num'], saved.params['default_purchase_factor_den']), (12, 1));
        expect(saved.params['reorder_point_default'], '5.5');
        expect(saved.params['reorder_quantity_default'], '20');
        expect(saved.params['home_zone_id'], 'demo-place-back');
        expect(find.textContaining('kg'), findsWidgets, reason: 'the group line says what it proposes');
      });

      testWidgets('a group carries what the till reads: category, key colour, deposit amount and label template; a colour is #rrggbb', (tester) async {
        final w = await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Beverages');
        await tester.enterText(find.byKey(const ValueKey('item-group-till-category')), 'Cold drinks');
        await tester.enterText(find.byKey(const ValueKey('item-group-key-colour')), 'blue');
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.stockReasonOutOfRange), findsOneWidget);
        expect((await w.groups('ws-1')).where((g) => g.name == 'Beverages'), isEmpty);
        await tester.enterText(find.byKey(const ValueKey('item-group-key-colour')), '#1E88E5');
        await tester.enterText(find.byKey(const ValueKey('item-group-deposit-minor')), '25');
        await tester.enterText(find.byKey(const ValueKey('item-group-label-template')), 'shelf-small');
        await _tap(tester, 'item-group-save');
        // the settings are previewed first; a second save applies them
        await _tap(tester, 'item-group-save');
        final saved = (await w.groups('ws-1')).firstWhere((g) => g.name == 'Beverages');
        expect(saved.params['till_category'], 'Cold drinks');
        expect(saved.params['quick_key_colour'], '#1E88E5');
        expect(saved.params['deposit_minor'], 25);
        expect(saved.params['label_template'], 'shelf-small');
      });

      testWidgets('#4471 an old free purchase unit is shown, flagged and must be replaced from the list before the group is saved', (tester) async {
        final w = await _open(
          tester,
          size,
          seed: (groups) => groups.save(
            'ws-1',
            requestId: 'old-free-unit',
            groupId: 'old-group',
            expectedRevision: 0,
            body: const ItemGroupDraft(
              name: 'Old group',
              parentId: null,
              parameters: {'default_purchase_unit': 'carton', 'default_purchase_factor_num': 12, 'default_purchase_factor_den': 1},
            ),
          ),
        );
        await _tap(tester, 'item-group-old-group');
        expect(tester.takeException(), isNull);
        expect(find.descendant(of: find.byKey(const ValueKey('item-group-purchase-unit')), matching: find.text('carton')), findsWidgets);
        expect(find.descendant(of: find.byKey(const ValueKey('item-group-purchase-unit')), matching: find.text(_en.masterDataUnlisted)), findsOneWidget);
        await _tap(tester, 'item-group-save');
        expect(find.byKey(const ValueKey('item-group-save')), findsOneWidget, reason: 'nothing was saved: the sheet stays');
        await _choose(tester, 'item-group-purchase-unit', 'kg');
        await _tap(tester, 'item-group-save');
        final saved = (await w.groups('ws-1')).firstWhere((g) => g.id == 'old-group');
        expect(saved.params['default_purchase_unit'], 'kg');
      });

      testWidgets('a purchase unit needs its factor, a factor is one number or a fraction above zero, and a third is exact', (tester) async {
        final w = await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Syrups');
        await _choose(tester, 'item-group-purchase-unit', 'l');
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.stockReasonOutOfRange), findsOneWidget, reason: 'a unit without a factor');
        await tester.enterText(find.byKey(const ValueKey('item-group-factor')), '1/0');
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.stockReasonOutOfRange), findsOneWidget, reason: 'a zero denominator');
        await tester.enterText(find.byKey(const ValueKey('item-group-factor')), '1/3');
        await _tap(tester, 'item-group-save');
        final saved = (await w.groups('ws-1')).firstWhere((g) => g.name == 'Syrups');
        expect((saved.params['default_purchase_factor_num'], saved.params['default_purchase_factor_den']), (1, 3));
      });

      testWidgets('a reorder quantity of zero or below six decimals is refused, a point or a comma reads the same', (tester) async {
        await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Quantities');
        for (final bad in ['0.0', '0,00', '0.0000004']) {
          await tester.enterText(find.byKey(const ValueKey('item-group-reorder-qty')), bad);
          await _tap(tester, 'item-group-save');
          expect(find.text(_en.stockReasonOutOfRange), findsOneWidget, reason: bad);
        }
        await tester.enterText(find.byKey(const ValueKey('item-group-reorder-qty')), '2,5');
        await _tap(tester, 'item-group-save');
      });

      testWidgets('a failed read of the places still opens the group sheet, without home zones', (tester) async {
        await _open(tester, size, places: false);
        await _tap(tester, 'item-group-add');
        expect(find.byKey(const ValueKey('item-group-name')), findsOneWidget);
      });

      testWidgets('what an item costs or sells for is set by someone who may manage services and see the finances', (tester) async {
        final w = await _open(tester, size, finance: true);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Fresh');
        await _choose(tester, 'item-group-vat', 'Reduced 5.5 %');
        await _choose(tester, 'item-group-supply', _en.itemGroupSupplyGeneral);
        await _choose(tester, 'item-group-rounding', '0.05');
        await tester.enterText(find.byKey(const ValueKey('item-group-margin')), '35,5');
        await _tap(tester, 'item-group-save');
        // a setting that reaches items is previewed first: the second save applies it
        await _tap(tester, 'item-group-save');
        final saved = (await w.groups('ws-1')).firstWhere((g) => g.name == 'Fresh');
        expect(saved.params['vat_rate_id'], 'vat-red');
        expect(saved.params['supply_class'], 'general');
        expect(saved.params['price_rounding'], '0.05');
        expect(saved.params['target_margin_bps'], 3550);
      });

      testWidgets('someone without the finances is not shown them and never changes them', (tester) async {
        final w = await _open(tester, size);
        final groups = await w.groups('ws-1');
        final drinks = groups.firstWhere((g) => g.id == 'demo-group-drinks');
        await w.save('ws-1', requestId: 'r-fin', groupId: drinks.id, expectedRevision: drinks.revision, body: ItemGroupDraft(name: drinks.name, parentId: drinks.parentId, parameters: {'vat_rate_id': 'vat-std', 'target_margin_bps': 2500}));
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).invalidate(itemGroupListProvider('ws-1'));
        await _frames(tester);
        expect(find.byKey(const ValueKey('item-group-vat')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('item-group-demo-group-drinks')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('item-group-vat')), findsNothing);
        expect(find.byKey(const ValueKey('item-group-margin')), findsNothing);
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Drinks and more');
        await _tap(tester, 'item-group-save');
        final after = (await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks');
        expect(after.name, 'Drinks and more');
        expect(after.params['vat_rate_id'], 'vat-std', reason: 'a save without the finances leaves them as they were');
        expect(after.params['target_margin_bps'], 2500);
      });

      testWidgets('a margin that is not a percent with two decimals at most is refused', (tester) async {
        await _open(tester, size, finance: true);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Margins');
        for (final bad in ['12.345', '1001', '1.2.3']) {
          await tester.enterText(find.byKey(const ValueKey('item-group-margin')), bad);
          await _tap(tester, 'item-group-save');
          expect(find.text(_en.stockReasonOutOfRange), findsOneWidget, reason: bad);
        }
      });

      testWidgets('a name another group of the same level has is refused in the words of a group (#4402)', (tester) async {
        await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'homeware');
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.stockReasonGroupNameDuplicate), findsOneWidget);
        expect(find.text(_en.stockReasonNameDuplicate), findsNothing, reason: 'the words of a variant are not the words of a group');
      });

      testWidgets('an empty group is created, then deleted', (tester) async {
        final w = await _open(tester, size);
        await _tap(tester, 'item-group-add');
        await tester.enterText(find.byKey(const ValueKey('item-group-name')), 'Gift baskets');
        await _tap(tester, 'item-group-save');
        expect((await w.groups('ws-1')).map((g) => g.name), contains('Gift baskets'));
        final id = (await w.groups('ws-1')).firstWhere((g) => g.name == 'Gift baskets').id;
        await tester.tap(find.byKey(ValueKey('item-group-$id')));
        await _frames(tester);
        await _tap(tester, 'item-group-delete');
        expect((await w.groups('ws-1')).map((g) => g.name), isNot(contains('Gift baskets')));
      });

      testWidgets('the tag mode of an item comes from its group, is overridden on the item and goes back; a tag per piece needs tracking by piece', (tester) async {
        final w = await _open(
          tester,
          size,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showItemGroupAssign(context, workspaceId: 'ws-1', itemId: 'demo-item-milk', itemName: 'Milk'),
                child: const Text('open'),
              ),
            ),
          ),
        );
        final drinks = (await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks');
        await w.save('ws-1', requestId: 'r-1', groupId: drinks.id, expectedRevision: drinks.revision, body: ItemGroupDraft(name: drinks.name, parentId: drinks.parentId, parameters: {'tag_mode': 'per_batch'}));
        await tester.tap(find.byKey(const ValueKey('open')));
        await _frames(tester);
        final row = find.byKey(const ValueKey('item-group-param-tag_mode'));
        expect(find.descendant(of: row, matching: find.textContaining('Drinks')), findsOneWidget, reason: 'inherited from the group, and said where from');
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        // a tag per piece is refused for an item tracked by lot, in words, and nothing changes
        await _choose(tester, 'item-group-tag-mode', _en.itemGroupTagUnit);
        expect(find.text(_en.itemGroupReasonNeedsSerial), findsOneWidget);
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        expect(tester.widget<AppDropdownField<String?>>(find.byKey(const ValueKey('item-group-tag-mode'))).value, 'per_batch', reason: 'the field shows the value in force, not the refused choice');
        // no tag at all is the item's own value, shown inline as its own, and given back to the group
        await _choose(tester, 'item-group-tag-mode', _en.itemGroupTagNone);
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.own, isTrue);
        expect(find.descendant(of: row, matching: find.text(_en.itemGroupOwn)), findsOneWidget);
        await _tap(tester, 'item-group-use-tag_mode');
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        expect(find.descendant(of: row, matching: find.textContaining('Drinks')), findsOneWidget);
      });

      testWidgets('a finance save on a group that moved meanwhile is refused in words, and a fresh sheet saves it', (tester) async {
        final w = await _open(tester, size, finance: true);
        final drinks = (await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks');
        await tester.tap(find.byKey(const ValueKey('item-group-demo-group-drinks')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('item-group-margin')), '40');
        await w.save('ws-1', requestId: 'r-moved', groupId: drinks.id, expectedRevision: drinks.revision, body: ItemGroupDraft(name: drinks.name, parentId: drinks.parentId, parameters: {'target_margin_bps': 1000}));
        await _tap(tester, 'item-group-save');
        expect(find.text(_en.stockEditStale), findsOneWidget);
        expect((await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks').params['target_margin_bps'], 1000, reason: 'a refused save changes nothing');
        Navigator.of(tester.element(find.byKey(const ValueKey('item-group-name')))).pop();
        await _frames(tester);
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).invalidate(itemGroupListProvider('ws-1'));
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('item-group-demo-group-drinks')));
        await _frames(tester);
        await tester.enterText(find.byKey(const ValueKey('item-group-margin')), '40');
        await _tap(tester, 'item-group-save');
        expect((await w.groups('ws-1')).firstWhere((g) => g.id == 'demo-group-drinks').params['target_margin_bps'], 4000);
      });

      testWidgets('the item editor marks a setting the item keeps of its own against its group, and only that one', (tester) async {
        final w = await _open(
          tester,
          size,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showStockItemEditor(context, ref.read(stockConfigCommandsProvider), workspaceId: 'ws-1', itemId: 'demo-item-milk', itemName: 'Milk', options: (lots: true, keep: false, groups: ref.read(itemGroupsProvider))),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-item-own-tracking')), findsNothing, reason: 'the milk follows its group');
        Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
        await _frames(tester);
        final config = await ProviderScope.containerOf(tester.element(find.byType(Scaffold).first)).read(stockConfigCommandsProvider).item('ws-1', 'demo-item-milk');
        await w.setOverride('ws-1', 'r-own', (itemId: 'demo-item-milk', expectedRevision: config!.revision, parameter: 'tracking', mode: 'set', value: 'lot'));
        await tester.tap(find.byKey(const ValueKey('open')));
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-item-own-tracking')), findsOneWidget);
        expect(find.text(_en.itemGroupOwn), findsOneWidget);
      });

      testWidgets('an item shows where each setting comes from, an own value goes back to the group, a move is previewed', (tester) async {
        final w = await _open(
          tester,
          size,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => showItemGroupAssign(context, workspaceId: 'ws-1', itemId: 'demo-item-syrup', itemName: 'Syrup'),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open')));
        await _frames(tester);
        final shelf = find.byKey(const ValueKey('item-group-param-shelf_life_days'));
        expect(find.descendant(of: shelf, matching: find.text(_en.itemGroupOwn)), findsOneWidget, reason: 'the syrup keeps its own shelf life');
        await _tap(tester, 'item-group-use-shelf_life_days');
        expect(find.descendant(of: shelf, matching: find.textContaining('Drinks')), findsOneWidget);
        expect((await w.effective('ws-1', 'demo-item-syrup')).params['shelf_life_days']!.own, isFalse);
        await _choose(tester, 'item-group-assign-field-demo-group-drinks', 'Homeware');
        await _tap(tester, 'item-group-move');
        expect(find.byKey(const ValueKey('item-group-move-reaches')), findsOneWidget);
        expect((await w.effective('ws-1', 'demo-item-syrup')).groupId, 'demo-group-drinks', reason: 'a preview moves nothing');
        await _tap(tester, 'item-group-move');
        expect((await w.effective('ws-1', 'demo-item-syrup')).groupId, 'demo-group-home');
      });
    });
  }
}
