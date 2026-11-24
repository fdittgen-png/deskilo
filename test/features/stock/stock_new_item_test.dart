// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350, #4402: a NEW item from the Stock page, at a phone and a desk width: one sheet with a name, a price, a
// VAT rate, a unit, a barcode and a home place; saving is one command with one request id that makes the
// service, its stock settings and its home together or not at all, so a lost answer never makes a second item
// and a refusal leaves nothing. The mistakes the screen can see are said under their field and nothing is sent.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_drafts.dart';
import 'package:deskilo/features/stock/domain/stock_service_creator.dart';
import 'package:deskilo/features/stock/domain/workspace_units.dart';
import 'package:deskilo/features/stock/presentation/stock_item_new_sheet.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Creator implements StockServiceCreator {
  @override
  Future<List<StockVatChoice>> vatChoices(String workspaceId) async => const [(id: 'vat-std', label: 'Standard'), (id: 'vat-red', label: 'Reduced')];
}

/// The server's one command (#4402): the item, its settings and its home together or not at all, answered by
/// request id.
class _Commands implements StockConfigCommands {
  final made = <NewStockItemDraft>[];
  final requests = <String>[];
  final _answers = <String, StockSaved>{};

  /// The next call is refused (nothing is made).
  bool refuseNext = false;

  /// The answer of the next call is lost after the item was made.
  bool loseNextAnswer = false;

  @override
  Future<StockSaved> createItem(String workspaceId, NewStockItemDraft item, String requestId) async {
    requests.add(requestId);
    if (_answers[requestId] case final done?) return (id: done.id, revision: done.revision, replayed: true);
    if (refuseNext) {
      refuseNext = false;
      throw const StockConfigRefused('home_location_id', StockRefusal.homeInvalid);
    }
    made.add(item);
    final saved = _answers[requestId] = (id: 'svc-${made.length}', revision: 2, replayed: false);
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw StateError('the answer was lost');
    }
    return saved;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Commands> _open(WidgetTester tester, Size size, {bool weighed = false}) async {
  final commands = _Commands();
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => showNewStockItemSheet(
            context,
            (creator: _Creator(), commands: commands),
            workspaceId: 'ws-1',
            choices: (
              vat: const [(id: 'vat-std', label: 'Standard'), (id: 'vat-red', label: 'Reduced')],
              places: const [
                StockPlaceConfig(id: 'p-main', revision: 1, kind: 'warehouse', code: 'MAIN', name: 'Main', barcode: null, parentId: null, active: true, virtual: false, addressPath: 'MAIN'),
              ],
              separator: '-',
              currency: 'EUR',
              unit: weighed ? 'kg' : 'piece',
              units: pickableUnits(builtInUnits, unitsOn: false),
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
  return commands;
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
        final commands = await _open(tester, size);
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(find.text(_en.stockItemNewNameRequired), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-price')), '1.2.3');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(find.text(_en.stockItemNewPriceInvalid), findsOneWidget);
        expect(commands.requests, isEmpty, reason: 'nothing is sent');
      });

      testWidgets('a business that sells by weight is proposed kilograms, any other pieces', (tester) async {
        final commands = await _open(tester, size, weighed: true);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Ham');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(commands.made.single.name, 'Ham');
        expect(commands.made.single.inventoryUnit, 'kg');
      });

      testWidgets('saving makes the service, its stock settings and its home in one command with one request id (#4402)', (tester) async {
        final commands = await _open(tester, size);
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-price')), '2,50');
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-barcode')), '7612345678900');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-home')));
        await _frames(tester);
        await tester.tap(find.text('MAIN').last);
        await _frames(tester);
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        final item = commands.made.single;
        expect(item.name, 'Oat bar');
        expect(item.priceCents, 250, reason: 'a price with a decimal comma, in minor units');
        expect(item.vatRateId, 'vat-std', reason: 'the default rate comes first');
        expect((item.inventoryUnit, item.barcode, item.homeLocationId), ('piece', '7612345678900', 'p-main'));
        expect(commands.requests, hasLength(1), reason: 'one command');
        expect(find.byKey(const ValueKey('stock-new-item-save')), findsNothing, reason: 'the sheet closes');
      });

      testWidgets('a refusal is said, nothing is made, and the next try is a new request that makes the item once', (tester) async {
        final commands = await _open(tester, size);
        commands.refuseNext = true;
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(commands.made, isEmpty, reason: 'a refused command leaves nothing');
        expect(find.text(_en.stockReasonHomeInvalid), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-new-item-save')), findsOneWidget, reason: 'the sheet stays open');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(commands.made, hasLength(1));
        expect(commands.requests.last, isNot(commands.requests.first), reason: 'a refusal was an answer: the next try is a new request');
      });

      testWidgets('a lost answer followed by a retry leaves one item: both calls carry the same request id', (tester) async {
        final commands = await _open(tester, size);
        commands.loseNextAnswer = true;
        await tester.enterText(find.byKey(const ValueKey('stock-new-item-name')), 'Oat bar');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(commands.made, hasLength(1), reason: 'the item was made, the answer was lost');
        await tester.tap(find.byKey(const ValueKey('stock-new-item-save')));
        await _frames(tester);
        expect(commands.requests, hasLength(2));
        expect(commands.requests.last, commands.requests.first, reason: 'the retry is the same request');
        expect(commands.made, hasLength(1), reason: 'and the server made no second item');
      });
    });
  }
}
