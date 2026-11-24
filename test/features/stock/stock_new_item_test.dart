// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350: a NEW item from the Stock page, at a phone and a desk width: one sheet with a name, a price, a VAT
// rate, a unit, a barcode and a home place; saving makes the service once and then its stock settings and its
// home place, one request id each, so a retry after a step succeeded goes on from there and never makes a second
// service. The mistakes the screen can see are said under their field and nothing is made.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_registry.dart';
import 'package:deskilo/features/stock/domain/stock_service_creator.dart';
import 'package:deskilo/features/stock/presentation/stock_item_new_sheet.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Creator implements StockServiceCreator {
  final created = <({String name, int price, String? vat})>[];

  /// What the server remembers (#4376): a request id answers the service it first made.
  final answers = <String, String>{};
  final requests = <String?>[];

  /// The answer of the next call is lost after the service was made.
  bool loseNextAnswer = false;

  @override
  Future<List<StockVatChoice>> vatChoices(String workspaceId) async => const [(id: 'vat-std', label: 'Standard'), (id: 'vat-red', label: 'Reduced')];

  @override
  Future<String> create(String workspaceId, {required String name, required int priceCents, String? vatRateId, String? requestId}) async {
    requests.add(requestId);
    final known = requestId == null ? null : answers[requestId];
    if (known != null) return known;
    created.add((name: name, price: priceCents, vat: vatRateId));
    if (requestId != null) answers[requestId] = 'svc-1';
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw StateError('the answer was lost');
    }
    return 'svc-1';
  }
}

class _Commands implements StockConfigCommands {
  bool failFirstSave = false;
  final saved = <({StockItemConfig config, String request})>[];

  @override
  Future<StockItemConfig?> item(String workspaceId, String itemId) async => const StockItemConfig(
    itemId: 'svc-1', revision: 1, stockable: false, purchasable: true, sellable: true, inventoryUnit: 'piece', tracking: 'none', shelfLifeDays: null, units: [], codes: [],
  );

  @override
  Future<StockSaved> saveItem(String workspaceId, StockItemConfig config, String requestId) async {
    if (failFirstSave) {
      failFirstSave = false;
      throw const StockConfigRefused('inventory_unit', StockRefusal.unitUnknown);
    }
    saved.add((config: config, request: requestId));
    return (id: config.itemId, revision: 2, replayed: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Registry implements StockRegistry {
  final homes = <({String item, String? place, String request})>[];

  @override
  Future<void> setHome(String workspaceId, {required String itemId, required String? variantId, required String? placeId, required String requestId}) async =>
      homes.add((item: itemId, place: placeId, request: requestId));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<(_Creator, _Commands, _Registry)> _open(WidgetTester tester, Size size, {bool weighed = false}) async {
  final creator = _Creator();
  final commands = _Commands();
  final registry = _Registry();
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => showNewStockItemSheet(
            context,
            (creator: creator, commands: commands, registry: registry),
            workspaceId: 'ws-1',
            choices: (
              vat: const [(id: 'vat-std', label: 'Standard'), (id: 'vat-red', label: 'Reduced')],
              places: const [
                StockPlaceConfig(id: 'p-main', revision: 1, kind: 'warehouse', code: 'MAIN', name: 'Main', barcode: null, parentId: null, active: true, virtual: false, addressPath: 'MAIN'),
              ],
              separator: '-',
              currency: 'EUR',
              unit: weighed ? 'kg' : 'piece',
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
    size: size,
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await _frames(tester);
  return (creator, commands, registry);
}

/// Frames enough for a sheet or an answer to arrive (bounded: no settling loop).
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('nothing is made without a name, and a price that is no number is said under its field', (tester) async {
        final (creator, commands, _) = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(find.text(_en.stockItemNewNameRequired), findsOneWidget);
        expect(creator.created, isEmpty);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-price')), '1.2.3');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(find.text(_en.stockItemNewPriceInvalid), findsOneWidget);
        expect(creator.created, isEmpty);
        expect(commands.saved, isEmpty);
      });

      testWidgets('a business that sells by weight is proposed kilograms, any other pieces', (tester) async {
        final (creator, commands, _) = await _open(tester, size, weighed: true);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Ham');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.created.single.name, 'Ham');
        expect(commands.saved.single.config.inventoryUnit, 'kg');
      });

      testWidgets('saving makes the service, its stock settings and its home once, each with its own request id', (tester) async {
        final (creator, commands, registry) = await _open(tester, size);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-price')), '2,50');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-barcode')), '7612345678900');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-home')));
        await _frames(tester);
        await tester.tap(find.text('MAIN').last);
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.created.single.name, 'Oat bar');
        expect(creator.created.single.price, 250, reason: 'a price with a decimal comma, in minor units');
        expect(creator.created.single.vat, 'vat-std', reason: 'the default rate comes first');
        final config = commands.saved.single.config;
        expect((config.itemId, config.stockable, config.purchasable, config.sellable, config.inventoryUnit), ('svc-1', true, true, true, 'piece'));
        expect(config.codes.single.code, '7612345678900');
        expect(registry.homes.single.place, 'p-main');
        expect(commands.saved.single.request, isNot(registry.homes.single.request), reason: 'one request id per step');
      });

      testWidgets('a refusal of the stock settings is said and a retry does not make a second service', (tester) async {
        final (creator, commands, _) = await _open(tester, size);
        commands.failFirstSave = true;
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.created, hasLength(1), reason: 'the service was made by the first try');
        expect(commands.saved, isEmpty);
        expect(find.byKey(const ValueKey('stock-new-item-save')), findsOneWidget, reason: 'the sheet stays open');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.created, hasLength(1), reason: 'the retry goes on from the settings: no second service');
        expect(commands.saved, hasLength(1));
      });
      testWidgets('a lost answer followed by a retry leaves one service: both calls carry the sheet\'s one request id (#4376)', (tester) async {
        final (creator, _, _) = await _open(tester, size);
        creator.loseNextAnswer = true;
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.created, hasLength(1), reason: 'the service was made, the answer was lost');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(creator.requests, hasLength(2));
        expect(creator.requests.first, isNotNull);
        expect(creator.requests.last, creator.requests.first, reason: 'the retry is the same request');
        expect(creator.created, hasLength(1), reason: 'and the server made no second service');
      });
    });
  }
}
