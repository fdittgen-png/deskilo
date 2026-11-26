// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4483 -- Stock › Items per form factor, light and dark, at 390, 820, 1024, 1440 and 1920. Nothing overflows and the
// name keeps its width on at most two lines. On a phone (390, 820) each item is a card whose worded chips open the
// item's editors, only those the member may use; a reader's cards carry none. At the desk (1024 and wider) a click
// selects one row of the grid, the toolbar above it enables the row's actions by the member's rights and opens the
// selected row's editor, the selection survives the save that reads the list again, the arrows move the selection,
// Enter and a double click open the item beside the grid, and a heading sorts.
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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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
const _all = {..._manage, WorkspacePermission.manageServices};

FakeMoneyRepository _money() => FakeMoneyRepository()
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
  ]);

Future<void> _open(
  WidgetTester tester,
  double width, {
  required bool dark,
  Set<WorkspacePermission> held = _all,
  FakeMoneyRepository? money,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final services = money ?? _money();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: services),
        stockQueriesProvider.overrideWithValue(FakeItemQueries()),
        stockConfigCommandsProvider.overrideWithValue(FakeItemConfig()),
        stockRegistryProvider.overrideWithValue(
          FakeItemRegistry(money: services, extra: [_longRow]),
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

Finder _row(String key) => find.byKey(ValueKey('stock-item-$key'));

/// The toolbar's button [key] (at the desk the item's page carries the same keys).
Finder _tool(String key) => find.descendant(
  of: find.byKey(const ValueKey('stock-items-toolbar')),
  matching: find.byKey(ValueKey(key)),
);

bool _enabled(WidgetTester tester, Finder button) =>
    tester.widget<ButtonStyleButton>(button).onPressed != null;

Future<void> _click(WidgetTester tester, String key) async {
  await tester.tap(_row(key));
  await settleStock(tester);
}

void main() {
  for (final width in [390.0, 820.0, 1024.0, 1440.0, 1920.0]) {
    final desk = width >= 1000;
    for (final dark in [false, true]) {
      group('at $width px, ${dark ? 'dark' : 'light'}', () {
        testWidgets(
          'an item reads at a glance: its name keeps its width on at most two lines, its facts, its badge',
          (tester) async {
            await _open(tester, width, dark: dark);
            final list = find.byKey(
              ValueKey(desk ? 'stock-items-grid-rows' : 'stock-items-list'),
            );
            expect(
              list,
              findsOneWidget,
              reason: desk ? 'a grid at the desk' : 'cards on a phone',
            );
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('stock-item-name-i-Coffee')),
              200,
              scrollable: find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            );
            await tester.pumpAndSettle();
            final title = find.byKey(
              const ValueKey('stock-item-name-i-Coffee'),
            );
            expect(
              tester.getSize(title).width,
              greaterThanOrEqualTo(120),
              reason: 'the name keeps its width, never a letter per line',
            );
            final lines = tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: title, matching: find.byType(RichText)),
                )
                .getBoxesForSelection(
                  const TextSelection(
                    baseOffset: 0,
                    extentOffset: _longName.length,
                  ),
                )
                .map((b) => b.top.round())
                .toSet();
            expect(
              lines.length,
              lessThanOrEqualTo(2),
              reason: 'the name is on one or two lines',
            );
            expect(
              find.descendant(
                of: _row('i-Coffee'),
                matching: find.text(_en.stockItemAttentionNoPlace),
              ),
              findsOneWidget,
              reason: 'the badge says what it needs',
            );
            final said = tester
                .widgetList<Text>(
                  find.descendant(
                    of: _row('i-Coffee'),
                    matching: find.byType(Text),
                  ),
                )
                .map((t) => t.data ?? '')
                .join(' · ');
            expect(said, contains('€24.90'));
            expect(said, contains(_en.stockQuantityWithUnit('7', 'piece')));
            if (desk) {
              expect(
                find.byKey(const ValueKey('stock-items-select-hint')),
                findsOneWidget,
                reason: 'nothing selected yet',
              );
              expect(
                _tool('stock-item-add'),
                findsOneWidget,
                reason: 'what acts on the list',
              );
              expect(
                _tool('stock-registry-search'),
                findsOneWidget,
                reason: 'the filters sit in the toolbar',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );

        if (!desk) {
          testWidgets(
            'a card carries the actions the member may use, as worded chips of a finger\'s size',
            (tester) async {
              await _open(tester, width, dark: dark);
              final chips = find.byKey(
                const ValueKey('stock-item-chips-i-Wine'),
              );
              for (final key in [
                'stock-item-edit-i-Wine',
                'stock-home-i-Wine',
                'stock-item-group-i-Wine',
                'stock-tags-i-Wine',
                'stock-edit-item-i-Wine',
                'stock-edit-variants-i-Wine',
                'stock-edit-mappings-i-Wine',
              ]) {
                final chip = find.descendant(
                  of: chips,
                  matching: find.byKey(ValueKey(key)),
                );
                expect(chip, findsOneWidget, reason: key);
                expect(
                  tester.getSize(chip).height,
                  greaterThanOrEqualTo(48),
                  reason: '$key: a finger\'s target',
                );
                expect(
                  find.descendant(of: chip, matching: find.byType(Text)),
                  findsOneWidget,
                  reason: '$key: no icon without a word',
                );
              }
              expect(tester.takeException(), isNull);
            },
          );

          testWidgets(
            'a chip opens its editor, and the card shows what was saved',
            (tester) async {
              await _open(tester, width, dark: dark);
              await tester.tap(
                find.byKey(const ValueKey('stock-item-edit-i-Tea')),
              );
              await settleStock(tester);
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
                tester
                    .widget<Text>(
                      find.byKey(const ValueKey('stock-item-facts-i-Tea')),
                    )
                    .data,
                contains('€4.00'),
                reason: 'the card shows the new price',
              );
              expect(
                find.byType(StockItemPage),
                findsNothing,
                reason: 'the chip acted from the list',
              );
            },
          );

          testWidgets('the card opens the item as a page of its own', (
            tester,
          ) async {
            await _open(tester, width, dark: dark);
            await openStockItem(tester, 'i-Wine');
            expect(
              find.byKey(const ValueKey('stock-item-page-i-Wine')),
              findsOneWidget,
            );
          });

          testWidgets(
            'who manages the stock but not the services has no price chip; a reader has no chips',
            (tester) async {
              await _open(tester, width, dark: dark, held: _manage);
              expect(
                find.byKey(const ValueKey('stock-item-edit-i-Wine')),
                findsNothing,
              );
              expect(
                find.byKey(const ValueKey('stock-home-i-Wine')),
                findsOneWidget,
              );
              await tester.pumpWidget(const SizedBox.shrink());
              await _open(
                tester,
                width,
                dark: dark,
                held: {WorkspacePermission.viewStock},
              );
              expect(
                find.byKey(const ValueKey('stock-item-chips-i-Wine')),
                findsNothing,
                reason: 'a reader acts on nothing',
              );
              expect(
                find.byKey(const ValueKey('stock-item-i-Wine')),
                findsOneWidget,
                reason: 'and reads the item',
              );
            },
          );
        } else {
          testWidgets(
            'a click selects a row, and the toolbar enables its actions by the rights',
            (tester) async {
              await _open(tester, width, dark: dark, held: _manage);
              await _click(tester, 'i-Wine');
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Wine')),
                findsOneWidget,
                reason: 'the row is marked',
              );
              expect(
                find.byKey(const ValueKey('stock-items-select-hint')),
                findsNothing,
              );
              expect(
                tester
                    .widget<Text>(
                      find.byKey(const ValueKey('stock-items-selected-name')),
                    )
                    .data,
                'Wine',
                reason: 'the toolbar names what it acts on',
              );
              expect(
                _enabled(tester, _tool('stock-item-edit-i-Wine')),
                isFalse,
                reason: 'no right to the services',
              );
              for (final key in [
                'stock-home-i-Wine',
                'stock-item-group-i-Wine',
                'stock-tags-i-Wine',
                'stock-edit-item-i-Wine',
                'stock-edit-variants-i-Wine',
                'stock-edit-mappings-i-Wine',
                'stock-items-open',
              ]) {
                expect(_enabled(tester, _tool(key)), isTrue, reason: key);
              }
              expect(
                find.byType(StockItemPage),
                findsNothing,
                reason: 'a click selects, it does not open',
              );
              await tester.tap(
                find.byKey(const ValueKey('stock-items-clear-selection')),
              );
              await settleStock(tester);
              expect(
                find.byKey(const ValueKey('stock-items-select-hint')),
                findsOneWidget,
              );
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Wine')),
                findsNothing,
              );
              expect(tester.takeException(), isNull);
            },
          );

          testWidgets(
            'a reader may select and open, and no action is enabled',
            (tester) async {
              await _open(
                tester,
                width,
                dark: dark,
                held: {WorkspacePermission.viewStock},
              );
              expect(
                _tool('stock-item-add'),
                findsNothing,
                reason: 'a reader adds nothing',
              );
              await _click(tester, 'i-Wine');
              for (final key in [
                'stock-item-edit-i-Wine',
                'stock-home-i-Wine',
                'stock-edit-item-i-Wine',
              ]) {
                expect(_enabled(tester, _tool(key)), isFalse, reason: key);
              }
              expect(_enabled(tester, _tool('stock-items-open')), isTrue);
            },
          );

          testWidgets(
            'the toolbar opens the selected row\'s editor, and the row stays selected with its new value',
            (tester) async {
              final money = _money();
              await _open(tester, width, dark: dark, money: money);
              await _click(tester, 'i-Tea');
              await tester.tap(_tool('stock-item-edit-i-Tea'));
              await settleStock(tester);
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
                money.services.singleWhere((s) => s.id == 'i-Tea').priceCents,
                400,
              );
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Tea')),
                findsOneWidget,
                reason: 'still selected',
              );
              expect(
                find.descendant(
                  of: _row('i-Tea'),
                  matching: find.text('€4.00'),
                ),
                findsOneWidget,
                reason: 'its new value',
              );
              expect(
                tester
                    .widget<Text>(
                      find.byKey(const ValueKey('stock-items-selected-name')),
                    )
                    .data,
                'Tea',
              );
            },
          );

          testWidgets(
            'the arrows move the selection, Enter and a double click open the item beside the grid',
            (tester) async {
              await _open(tester, width, dark: dark);
              await _click(tester, 'i-Wine');
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await settleStock(tester);
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Tea')),
                findsOneWidget,
                reason: 'down: the next row',
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
              await settleStock(tester);
              expect(
                find.byKey(const ValueKey('stock-item-check-i-Wine')),
                findsOneWidget,
                reason: 'up: back',
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await settleStock(tester);
              expect(
                find.byKey(const ValueKey('stock-item-page-i-Wine')),
                findsOneWidget,
                reason: 'Enter opens',
              );
              expect(
                find.byKey(const ValueKey('stock-items-grid')),
                findsOneWidget,
                reason: 'beside the grid',
              );
              await tester.tap(find.byKey(const ValueKey('stock-item-close')));
              await settleStock(tester);
              expect(
                find.byType(StockItemPage),
                findsNothing,
                reason: 'closable',
              );
              await tester.tap(_row('i-Tea'));
              await tester.pump();
              await tester.tap(_row('i-Tea'));
              await settleStock(tester);
              expect(
                find.byKey(const ValueKey('stock-item-page-i-Tea')),
                findsOneWidget,
                reason: 'a double click opens',
              );
              expect(tester.takeException(), isNull);
            },
          );

          testWidgets(
            'a click on the price heading sorts by price, a second reverses it',
            (tester) async {
              await _open(tester, width, dark: dark);
              double top(String key) => tester.getTopLeft(_row(key)).dy;
              await tester.tap(
                find.byKey(const ValueKey('records-sort-price')),
              );
              await settleStock(tester);
              expect(
                top('i-Tea') < top('i-Wine') && top('i-Wine') < top('i-Coffee'),
                isTrue,
                reason: 'cheapest first',
              );
              await tester.tap(
                find.byKey(const ValueKey('records-sort-price')),
              );
              await settleStock(tester);
              expect(
                top('i-Coffee') < top('i-Wine') && top('i-Wine') < top('i-Tea'),
                isTrue,
                reason: 'dearest first',
              );
            },
          );
        }
      });
    }
  }
}
