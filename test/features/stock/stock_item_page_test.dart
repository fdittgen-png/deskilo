// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4480 -- an item of Stock › Items on a phone and at the desk, light and dark: the item opens at its address
// (beside the grid at 1024 and 1440, a page of its own at 390); each section's worded action opens the editor the
// business already has, and a save shows the new value back on the item; the rights decide the actions.
// #4483 -- how the list itself reads per form factor is stock_items_form_factor_test.dart.
import 'package:deskilo/app/theme.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/stock/domain/item_groups.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/presentation/stock_item_page.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/screens/stock_items_app.dart';
import 'stock_items_fakes.dart';

final _en = AppLocalizationsEn();

/// A name long enough to wrap: it must keep its two lines, never one letter per line.
const _longName =
    'Organic fair-trade single-origin Ethiopian Yirgacheffe coffee beans, whole, light roast, 1 kg bag';

final _longRow = StockRegistryRow(
  itemId: 'i-Coffee',
  itemName: _longName,
  unit: 'piece',
  priceCents: 2490,
  onHand: ExactQuantity.parse('7'),
);

/// The item groups as the server answers them: Wine is in Drinks.
class _Groups implements ItemGroups {
  @override
  Future<List<ItemGroup>> groups(String workspaceId) async => const [
    ItemGroup(
      id: 'g-drinks',
      parentId: null,
      name: 'Drinks',
      revision: 1,
      params: {},
      items: 1,
    ),
  ];

  @override
  Future<ItemEffective> effective(String workspaceId, String itemId) async =>
      ItemEffective(
        itemId: itemId,
        groupId: itemId == 'i-Wine' ? 'g-drinks' : null,
        params: const {},
        problems: const [],
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _manage = {
  WorkspacePermission.viewStock,
  WorkspacePermission.manageStock,
};

Future<void> _open(
  WidgetTester tester,
  double width, {
  required bool dark,
  Set<WorkspacePermission> held = const {
    ..._manage,
    WorkspacePermission.manageServices,
  },
  FakeMoneyRepository? money,
  FakeItemRegistry? registry,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final services =
      money ??
      (FakeMoneyRepository()
        ..services.addAll(const [
          ServiceItem(
            id: 'i-Wine',
            workspaceId: 'ws-1',
            name: 'Wine',
            priceCents: 1250,
            active: true,
          ),
          ServiceItem(
            id: 'i-Tea',
            workspaceId: 'ws-1',
            name: 'Tea',
            priceCents: 300,
            active: true,
          ),
        ]));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: services),
        stockQueriesProvider.overrideWithValue(FakeItemQueries()),
        stockConfigCommandsProvider.overrideWithValue(FakeItemConfig()),
        stockRegistryProvider.overrideWithValue(
          registry ?? FakeItemRegistry(money: services, extra: [_longRow]),
        ),
        stockCodeResolverProvider.overrideWithValue(FakeItemResolver()),
        itemGroupsProvider.overrideWithValue(_Groups()),
        stockTagsStoreProvider.overrideWithValue(DemoStockTags()),
        myPermissionsProvider.overrideWithValue(held),
        enabledFeaturesSyncProvider.overrideWithValue({
          WorkspaceFeature.stockManagement,
          WorkspaceFeature.stockItemGroups,
          WorkspaceFeature.stockTags,
        }),
      ],
      child: MaterialApp.router(
        theme: DeskiloTheme.light(animations: false),
        darkTheme: DeskiloTheme.dark(animations: false),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: stockItemsRouter(),
      ),
    ),
  );
  await settleStock(tester);
}

Finder _inPage(Finder f) =>
    find.descendant(of: find.byType(StockItemPage), matching: f);

void main() {
  for (final width in [390.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      group('at $width px, ${dark ? 'dark' : 'light'}', () {
        testWidgets(
          'a row opens its item: ${width < 1000 ? 'a page of its own' : 'beside the list'}',
          (tester) async {
            await _open(tester, width, dark: dark);
            await openStockItem(tester, 'i-Wine');
            expect(find.byType(StockItemPage), findsOneWidget);
            expect(
              _inPage(find.text('Wine')),
              findsWidgets,
              reason: 'the item names itself',
            );
            for (final section in [
              'overview',
              'stock',
              'group',
              'variants',
              'suppliers',
            ]) {
              expect(
                find.byKey(ValueKey('stock-item-section-$section')),
                findsOneWidget,
                reason: section,
              );
            }
            if (width < 1000) {
              expect(
                find.byKey(const ValueKey('stock-items-list')),
                findsNothing,
                reason: 'on a phone the item is a page over the list',
              );
            } else {
              expect(
                find.byKey(const ValueKey('stock-items-grid')),
                findsOneWidget,
                reason: 'at the desk the grid stays beside the item',
              );
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Wine')),
                findsOneWidget,
                reason: 'its row stays selected',
              );
              await tester.tap(find.byKey(const ValueKey('stock-item-close')));
              await settleStock(tester);
              expect(
                find.byType(StockItemPage),
                findsNothing,
                reason: 'closed: the list alone',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'the price is edited from the overview, and the item shows the new price',
          (tester) async {
            final money = FakeMoneyRepository()
              ..services.add(
                const ServiceItem(
                  id: 'i-Tea',
                  workspaceId: 'ws-1',
                  name: 'Tea',
                  priceCents: 300,
                  active: true,
                ),
              );
            await _open(
              tester,
              width,
              dark: dark,
              money: money,
              registry: FakeItemRegistry(money: money),
            );
            await openStockItem(tester, 'i-Tea');
            await tapItemAction(tester, 'stock-item-edit-i-Tea');
            await tester.enterText(
              find.byKey(const ValueKey('services-price')),
              '4',
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('services-save')),
            );
            await tester.tap(find.byKey(const ValueKey('services-save')));
            await settleStock(tester);
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('stock-item-section-overview')),
                matching: find.text('€4.00'),
              ),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'the home place is changed from the stock section, and the item shows it',
          (tester) async {
            await _open(tester, width, dark: dark);
            await openStockItem(tester, 'i-Tea');
            expect(
              _inPage(
                find.byKey(const ValueKey('stock-item-attention-noPlace')),
              ),
              findsOneWidget,
            );
            await tapItemAction(tester, 'stock-home-i-Tea');
            await tester.tap(find.byKey(const ValueKey('stock-home-place')));
            await settleStock(tester);
            await tester.tap(find.text('MAIN-SALES-A03-B02-S4').last);
            await settleStock(tester);
            await tester.tap(find.byKey(const ValueKey('stock-home-save')));
            await settleStock(tester);
            expect(
              _inPage(
                find.text(_en.stockRegistryHome('MAIN-SALES-A03-B02-S4')),
              ),
              findsOneWidget,
            );
            expect(
              _inPage(
                find.byKey(const ValueKey('stock-item-attention-noPlace')),
              ),
              findsNothing,
              reason: 'nothing is missing any more',
            );
          },
        );

        testWidgets(
          'the stock settings, the group and the tags open their editors from their sections',
          (tester) async {
            await _open(tester, width, dark: dark);
            await openStockItem(tester, 'i-Wine');
            expect(
              _inPage(find.text('S4')),
              findsOneWidget,
              reason: 'where it is: its shelf',
            );
            expect(
              _inPage(find.text('Drinks')),
              findsOneWidget,
              reason: 'its group',
            );
            await tapItemAction(tester, 'stock-edit-item-i-Wine');
            expect(
              find.byKey(const ValueKey('stock-item-save')),
              findsOneWidget,
              reason: 'the stock settings editor',
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('stock-item-save')),
            );
            await tester.tap(find.byKey(const ValueKey('stock-item-save')));
            await settleStock(tester);
            expect(
              find.byKey(const ValueKey('stock-item-save')),
              findsNothing,
              reason: 'saved: back on the item',
            );
            expect(find.byType(StockItemPage), findsOneWidget);
            await tapItemAction(tester, 'stock-tags-i-Wine');
            expect(
              find.byKey(const ValueKey('stock-tags-dialog')),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const ValueKey('stock-tags-close')));
            await settleStock(tester);
            await tapItemAction(tester, 'stock-item-group-i-Wine');
            expect(
              find.byType(Dialog),
              findsOneWidget,
              reason: 'the group and inherited settings',
            );
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'a member who manages the stock but not the services has every edit but the price',
          (tester) async {
            await _open(tester, width, dark: dark, held: _manage);
            await openStockItem(tester, 'i-Wine');
            expect(
              itemAction('stock-item-edit-i-Wine'),
              findsNothing,
            );
            for (final key in [
              'stock-edit-item-i-Wine',
              'stock-home-i-Wine',
              'stock-edit-variants-i-Wine',
              'stock-edit-mappings-i-Wine',
              'stock-item-group-i-Wine',
              'stock-tags-i-Wine',
            ]) {
              expect(itemAction(key), findsOneWidget, reason: key);
            }
          },
        );

        testWidgets('a reader sees the item and no edit', (tester) async {
          await _open(
            tester,
            width,
            dark: dark,
            held: {WorkspacePermission.viewStock},
          );
          await openStockItem(tester, 'i-Wine');
          expect(
            find.byKey(const ValueKey('stock-item-section-overview')),
            findsOneWidget,
          );
          expect(
            _inPage(find.byType(FilledButton)),
            findsNothing,
            reason: 'no section action',
          );
          expect(itemAction('stock-home-i-Wine'), findsNothing);
          expect(
            find.byKey(const ValueKey('stock-item-section-suppliers')),
            findsNothing,
          );
        });
      });
    }
  }
}
