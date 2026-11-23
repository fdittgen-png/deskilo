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
import 'package:deskilo/features/stock/presentation/item_group_assign_dialog.dart';
import 'package:deskilo/features/stock/presentation/item_groups_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
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

Future<DemoItemGroups> _open(WidgetTester tester, Size size, {Widget? home}) async {
  final config = DemoStockConfigCommands('ws-1');
  final groups = DemoItemGroups('ws-1', config, () => DateTime(2026, 11, 22));
  await pumpApp(
    tester,
    home ?? const ItemGroupsScreen(),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      itemGroupsProvider.overrideWithValue(groups),
      stockConfigCommandsProvider.overrideWithValue(config),
      myPermissionsProvider.overrideWithValue({WorkspacePermission.viewStock, WorkspacePermission.manageStock}),
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
        await w.save('ws-1', requestId: 'r-1', groupId: drinks.id, expectedRevision: drinks.revision, body: {'parameters': {'tag_mode': 'per_batch'}});
        await tester.tap(find.byKey(const ValueKey('open')));
        await _frames(tester);
        final row = find.byKey(const ValueKey('item-group-param-tag_mode'));
        expect(find.descendant(of: row, matching: find.textContaining('Drinks')), findsOneWidget, reason: 'inherited from the group, and said where from');
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        // a tag per piece is refused for an item tracked by lot, in words, and nothing changes
        await _choose(tester, 'item-group-tag-mode', _en.itemGroupTagUnit);
        expect(find.text(_en.itemGroupReasonNeedsSerial), findsOneWidget);
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        // no tag at all is the item's own value, shown inline as its own, and given back to the group
        await _choose(tester, 'item-group-tag-mode', _en.itemGroupTagNone);
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.own, isTrue);
        expect(find.descendant(of: row, matching: find.text(_en.itemGroupOwn)), findsOneWidget);
        await _tap(tester, 'item-group-use-tag_mode');
        expect((await w.effective('ws-1', 'demo-item-milk')).params['tag_mode']!.value, 'per_batch');
        expect(find.descendant(of: row, matching: find.textContaining('Drinks')), findsOneWidget);
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
