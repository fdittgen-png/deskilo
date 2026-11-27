// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4433 -- a line of an invoice may sell an item kept in stock: choosing it makes the line a goods line (its unit is the
// item's and cannot be changed, an empty description takes the item's name), an item tracked piece by piece asks for
// the tags of the pieces, and choosing "no goods" gives the line back to the free text. The line editor stays whole on
// a phone and on a desktop window.
import 'package:deskilo/features/money/domain/invoice_goods.dart';
import 'package:deskilo/features/money/domain/line_unit.dart';
import 'package:deskilo/features/money/presentation/standalone/standalone_line_form.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/pickable_units_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _coffee = InvoiceGoodsItem(id: 'item-coffee', name: 'Coffee beans', unit: 'kg');
const _phone = InvoiceGoodsItem(id: 'item-phone', name: 'Phone', unit: 'piece', byPiece: true);

/// Pumps a line editor over [form] offering [_coffee] and [_phone], and hands back the context to save with.
Future<BuildContext> _pump(WidgetTester tester, StandaloneLineForm form, {required Size size, List<Override> overrides = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext context;
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (c, setState) {
              context = c;
              return StandaloneLineEditor(
                index: 0,
                form: form,
                rates: const [],
                goods: const [_coffee, _phone],
                pieces: true,
                workspaceId: 'ws',
                onChanged: () => setState(() {}),
                onRemove: null,
              );
            },
          ),
        ),
      ),
    ),
    ),
  );
  return context;
}

Future<void> _choose(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('standalone-line-0-goods')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [('390 wide', const Size(390, 900)), ('1440 wide', const Size(1440, 900))]) {
    group(label, () {
      testWidgets('an item in kilograms makes a goods line: its unit is the item\'s, the name fills an empty description', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        expect(find.byKey(const ValueKey('standalone-line-0-unit')), findsOneWidget, reason: 'a free line picks its unit');

        await _choose(tester, 'Coffee beans');
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('standalone-line-0-goods-unit')), findsOneWidget);
        expect(find.byKey(const ValueKey('standalone-line-0-unit')), findsNothing, reason: 'the item fixes the unit');
        expect(find.byKey(const ValueKey('standalone-line-0-pieces')), findsNothing, reason: 'a bulk item names no pieces');

        final wire = form.toLine(context).toWire();
        expect(wire['item_id'], 'item-coffee');
        expect(wire['description'], 'Coffee beans');
        expect((wire['unit'] as Map)['code'], 'kg');
        expect(wire['supply'], 'goods');
        expect(wire.containsKey('units'), isFalse);
      });

      testWidgets('an item tracked piece by piece asks for the tags and sends each once, in order', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);

        await _choose(tester, 'Phone');
        expect(find.byKey(const ValueKey('standalone-line-0-pieces')), findsOneWidget);
        await tester.enterText(find.byKey(const ValueKey('standalone-line-0-pieces')), 'SN-2, SN-1 SN-2');
        await tester.pump();

        final wire = form.toLine(context).toWire();
        expect(wire['item_id'], 'item-phone');
        expect(wire['units'], [
          {'tag': 'SN-2'},
          {'tag': 'SN-1'},
        ]);
      });

      testWidgets('choosing no goods gives the line back to the free text: no item, no tags, a unit to pick', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final context = await _pump(tester, form, size: size);
        await _choose(tester, 'Phone');
        await tester.enterText(find.byKey(const ValueKey('standalone-line-0-pieces')), 'SN-1');
        await tester.pump();

        await _choose(tester, 'Nothing from stock (a service)');
        expect(find.byKey(const ValueKey('standalone-line-0-unit')), findsOneWidget);
        expect(find.byKey(const ValueKey('standalone-line-0-pieces')), findsNothing);
        final wire = form.toLine(context).toWire();
        expect(wire.containsKey('item_id'), isFalse);
        expect(wire.containsKey('units'), isFalse);
      });
    });
  }

  testWidgets('a goods line sells any unit its item converts from, starts in the sale unit at that unit\'s price, and keeps a price the member typed', (tester) async {
    final form = StandaloneLineForm();
    addTearDown(form.dispose);
    final context = await _pump(
      tester,
      form,
      size: const Size(390, 900),
      overrides: [
        itemOrderUnitsProvider.overrideWith(
          (ref, key) async => const ItemOrderUnits(units: [LineUnit(code: 'piece'), LineUnit(code: 'carton', label: 'Carton')], saleUnit: 'carton'),
        ),
        itemUnitPriceProvider.overrideWith((ref, key) async => key.unit == 'carton' ? 1100 : 100),
        invoicingBusinessProvider.overrideWithValue((id: 'ws', currency: 'EUR', country: 'FR', dayOf: (d) => d)),
      ],
    );
    await _choose(tester, 'Phone');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(form.goodsUnit?.code, 'carton', reason: 'the item\'s sale unit');
    expect(form.price.text, '11.00', reason: 'the carton\'s own price, not twelve pieces');

    await tester.tap(find.byKey(const ValueKey('standalone-line-0-goods-unit-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('piece').last);
    await tester.pumpAndSettle();
    expect(form.goodsUnit?.code, 'piece');
    expect(form.price.text, '1.00', reason: 'the price filled in follows the unit');
    expect((form.toLine(context).toWire()['unit'] as Map)['code'], 'piece');

    form.price.text = '0.90';
    await tester.tap(find.byKey(const ValueKey('standalone-line-0-goods-unit-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carton').last);
    await tester.pumpAndSettle();
    expect(form.goodsUnit?.code, 'carton');
    expect(form.price.text, '0.90', reason: 'a price the member typed is never replaced');
  });
}
