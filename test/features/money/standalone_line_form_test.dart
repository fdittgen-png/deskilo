// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4394 -- opening a saved line and saving it again changes only what the person changed: the supply kind and the base
// quantity stay, a unit the composer does not list is shown by its stored label and saved unchanged, and a quantity or
// a price typed with a decimal comma is read by the shared decimal input.
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo/features/money/presentation/standalone/standalone_line_form.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _property = StandaloneLine(
  lineId: 'l-1',
  description: 'Rent of the shop',
  quantity: '1',
  unitCode: 'hour',
  unitLabel: 'hour',
  unEceCode: 'HUR',
  unitPrice: '950.00',
  baseQuantity: '100',
  supply: 'property',
);

/// Pumps a line editor over [form] and hands back the line it would save.
Future<StandaloneLine> _save(WidgetTester tester, StandaloneLineForm form, {Locale locale = const Locale('en')}) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Builder(
            builder: (c) {
              context = c;
              return StandaloneLineEditor(index: 0, form: form, rates: const [], onChanged: () {}, onRemove: null);
            },
          ),
        ),
      ),
    ),
  );
  return form.toLine(context);
}

void main() {
  testWidgets('a line with another supply kind and a base quantity keeps both when its description is edited', (tester) async {
    final form = StandaloneLineForm(from: _property);
    await _save(tester, form);
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-description')), 'Rent of the shop, November');
    final saved = await _save(tester, form);
    expect(saved.description, 'Rent of the shop, November');
    expect(
      saved.toWire(),
      _property.copyWith(description: 'Rent of the shop, November').toWire(),
      reason: 'the saved line is the opened one but for its description',
    );
    expect(saved.supply, 'property');
    expect(saved.baseQuantity, '100');
    expect(saved.lineId, 'l-1');
  });

  testWidgets('a unit the composer does not list still opens, by its stored label, and is saved unchanged', (tester) async {
    final form = StandaloneLineForm(
      from: const StandaloneLine(description: 'Tonnage', quantity: '2', unitCode: 'tonne', unitLabel: 'tonne (stored)', unEceCode: 'TNE', unitPrice: '10'),
    );
    final saved = await _save(tester, form);
    expect(find.text('tonne (stored)'), findsOneWidget);
    expect(saved.toWire(), form.toLine(tester.element(find.byType(StandaloneLineEditor))).toWire());
    expect(saved.toWire()['unit'], {'code': 'tonne', 'label': 'tonne (stored)', 'un_ece_code': 'TNE'});
    expect(saved.toWire()['quantity'], '2');
    expect(saved.toWire()['unit_price'], '10');
  });

  testWidgets('a listed unit is saved as it was stored: a label written in another language is not rewritten', (tester) async {
    final form = StandaloneLineForm(
      from: const StandaloneLine(description: 'Beratung', quantity: '2', unitCode: 'hour', unitLabel: 'Stunde', unEceCode: 'HUR', unitPrice: '80'),
    );
    final saved = await _save(tester, form);
    expect(saved.unitLabel, 'Stunde', reason: 'opened under en, saved as written');
    expect(saved.unEceCode, 'HUR');
    // Only a unit the person changes is read from the table.
    tester.widget<DropdownButtonFormField<String>>(find.byKey(const ValueKey('standalone-line-0-unit'))).onChanged!('day');
    final changed = form.toLine(tester.element(find.byType(StandaloneLineEditor)));
    expect(changed.unitCode, 'day');
    expect(changed.unitLabel, 'day');
    expect(changed.unEceCode, 'DAY');
  });

  testWidgets('a quantity and a price typed with a decimal comma are read through the shared input', (tester) async {
    final form = StandaloneLineForm();
    await _save(tester, form, locale: const Locale('de'));
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-quantity')), '1,5');
    await tester.enterText(find.byKey(const ValueKey('standalone-line-0-price')), '1.234,50');
    final saved = await _save(tester, form, locale: const Locale('de'));
    expect(saved.quantity, '1.5');
    expect(saved.unitPrice, '1234.50');
  });

  group('the ids the server gave are attached by position, and only to an answer that lines up', () {
    List<StandaloneLineForm> forms() => [StandaloneLineForm(), StandaloneLineForm()];
    StandaloneLine answered(String id) => StandaloneLine(lineId: id, description: '', quantity: '1', unitCode: 'hour', unitLabel: 'hour', unitPrice: '1');

    test('an answer with as many lines attaches each id to its form (both screens call this)', () {
      final f = forms();
      expect(attachLineIds(f, [answered('a'), answered('b')]), isTrue);
      expect(f.map((x) => x.lineId), ['a', 'b']);
    });

    test('an answer with another number of lines attaches nothing', () {
      final f = forms();
      expect(attachLineIds(f, [answered('a')]), isFalse);
      expect(attachLineIds(f, [answered('a'), answered('b'), answered('c')]), isFalse);
      expect(f.map((x) => x.lineId), [null, null]);
    });
  });

  testWidgets('a new line starts from one default: hour, general supply, base quantity one', (tester) async {
    final saved = await _save(tester, StandaloneLineForm());
    expect(saved.unitCode, 'hour');
    expect(saved.supply, 'general');
    expect(saved.baseQuantity, '1');
  });
}
