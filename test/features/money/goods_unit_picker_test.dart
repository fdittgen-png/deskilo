// SPDX-License-Identifier: AGPL-3.0-or-later
// #4516 -- the unit of a goods line is a picker over the business's units, the ones the item converts from first. A unit the item cannot
// convert to asks "1 box = [n] pieces" and is saved as the item's conversion, then the line takes the unit at its converted price;
// cancelling, a refusal and a number that is not one leave the line as it was; "New unit…" opens the units editor and comes back to the draft.
import 'package:deskilo/features/money/domain/invoice_goods.dart';
import 'package:deskilo/features/money/domain/line_unit.dart';
import 'package:deskilo/features/money/presentation/standalone/standalone_line_form.dart';
import 'package:deskilo/features/money/providers/credit_providers.dart';
import 'package:deskilo/features/money/providers/pickable_units_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mugs = InvoiceGoodsItem(id: 'item-mugs', name: 'Mugs', unit: 'piece');
const _piece = LineUnit(code: 'piece', label: 'Piece');
const _box = LineUnit(code: 'box', label: 'Box');
const _kg = LineUnit(code: 'kg', label: 'Kilogram');

class _World {
  final List<({String unit, int num, int den})> saved = [];
  bool refuse = false;
  int opened = 0;
  List<LineUnit> converts = [_piece];
}

Future<_World> _pump(WidgetTester tester, StandaloneLineForm form, Size size, {bool canAddUnits = true, bool canSave = true}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = _World();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        invoicingBusinessProvider.overrideWithValue((id: 'ws', currency: 'EUR', country: 'FR', dayOf: (d) => d)),
        pickableUnitsProvider.overrideWith((ref, ws) => [_piece, _box, _kg]),
        itemOrderUnitsProvider.overrideWith(
          (ref, key) async => ItemOrderUnits(units: w.converts, saleUnit: 'piece', inventoryUnit: 'piece'),
        ),
        itemUnitPriceProvider.overrideWith((ref, key) async => switch (key.unit) {
          'box' => 1200,
          _ => 100,
        }),
        if (canSave)
          itemConversionSaverProvider.overrideWith(
            (ref) => ({required workspaceId, required itemId, required unit, required factorNum, required factorDen}) async {
              if (w.refuse) return false;
              w.saved.add((unit: unit, num: factorNum, den: factorDen));
              w.converts = [...w.converts, if (unit == 'box') _box];
              return true;
            },
          ),
        if (canAddUnits) newUnitOpenerProvider.overrideWith((ref) => (context, ws) async => w.opened++),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (c, setState) => StandaloneLineEditor(
                index: 0,
                form: form,
                rates: const [],
                goods: const [_mugs],
                workspaceId: 'ws',
                onChanged: () => setState(() {}),
                onRemove: null,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('standalone-line-0-goods')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mugs').last);
  await tester.pumpAndSettle();
  return w;
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('standalone-line-0-goods-unit-pick')));
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size) in [('390 wide', const Size(390, 900)), ('1440 wide', const Size(1440, 900))]) {
    group(label, () {
      testWidgets('an item with no conversion offers every unit: its own first, the others to define, then New unit…', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        await _pump(tester, form, size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('standalone-line-0-goods-unit-pick')), findsOneWidget, reason: 'not locked on the item\'s own unit');
        await _openPicker(tester);
        expect(find.text('Box (set a conversion)'), findsOneWidget);
        expect(find.text('Kilogram (set a conversion)'), findsOneWidget);
        expect(find.text('New unit…'), findsOneWidget);
        final shown = [for (final t in tester.widgetList<Text>(find.byType(Text))) t.data ?? ''];
        expect(shown.indexOf('Piece'), lessThan(shown.indexOf('Box (set a conversion)')), reason: 'the units the item converts from come first');
      });

      testWidgets('a unit with no conversion asks "1 box = ? piece", saves 12, and the line takes the box at its converted price', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final w = await _pump(tester, form, size);
        await _openPicker(tester);
        await tester.tap(find.text('Box (set a conversion)').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('goods-conversion-dialog')), findsOneWidget);
        await tester.enterText(find.descendant(of: find.byKey(const ValueKey('goods-conversion-factor')), matching: find.byType(EditableText)), '12');
        await tester.tap(find.byKey(const ValueKey('goods-conversion-save')));
        await tester.pumpAndSettle();
        expect(w.saved, [(unit: 'box', num: 12, den: 1)]);
        expect(form.goodsUnit?.code, 'box');
        expect(form.price.text, '12.00', reason: 'the box\'s price follows the conversion');
      });

      testWidgets('cancelling the step leaves the line in pieces and saves nothing', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final w = await _pump(tester, form, size);
        await _openPicker(tester);
        await tester.tap(find.text('Box (set a conversion)').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('goods-conversion-cancel')));
        await tester.pumpAndSettle();
        expect(w.saved, isEmpty);
        expect(form.goodsUnit?.code, 'piece');
      });

      testWidgets('a number that is not one is said and nothing is saved; a refused save keeps the unit', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final w = await _pump(tester, form, size);
        await _openPicker(tester);
        await tester.tap(find.text('Box (set a conversion)').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.descendant(of: find.byKey(const ValueKey('goods-conversion-factor')), matching: find.byType(EditableText)), '0');
        await tester.tap(find.byKey(const ValueKey('goods-conversion-save')));
        await tester.pumpAndSettle();
        expect(find.text('Enter a number above 0, with at most three decimals.'), findsOneWidget);
        expect(w.saved, isEmpty);

        w.refuse = true;
        await tester.enterText(find.descendant(of: find.byKey(const ValueKey('goods-conversion-factor')), matching: find.byType(EditableText)), '12');
        await tester.tap(find.byKey(const ValueKey('goods-conversion-save')));
        await tester.pumpAndSettle();
        expect(find.text('The conversion was not saved. The line keeps its unit.'), findsOneWidget);
        expect(form.goodsUnit?.code, 'piece');
      });

      testWidgets('New unit… opens the units editor', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        final w = await _pump(tester, form, size);
        await _openPicker(tester);
        await tester.tap(find.text('New unit…').last);
        await tester.pumpAndSettle();
        expect(w.opened, 1);
        expect(form.goodsUnit?.code, 'piece');
      });

      testWidgets('without the right to edit units there is no New unit…, and nothing to save a conversion with offers the item\'s own unit alone', (tester) async {
        final form = StandaloneLineForm();
        addTearDown(form.dispose);
        await _pump(tester, form, size, canAddUnits: false, canSave: false);
        expect(find.byKey(const ValueKey('standalone-line-0-goods-unit')), findsOneWidget);
        expect(find.byKey(const ValueKey('standalone-line-0-goods-unit-pick')), findsNothing);
      });
    });
  }
}
