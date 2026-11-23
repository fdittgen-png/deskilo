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
    expect(saved.supply, 'property');
    expect(saved.baseQuantity, '100');
    expect(saved.lineId, 'l-1');
    expect(saved.toWire()['supply'], 'property');
  });

  testWidgets('a unit the composer does not list still opens, by its stored label, and is saved unchanged', (tester) async {
    final form = StandaloneLineForm(
      from: const StandaloneLine(description: 'Tonnage', quantity: '2', unitCode: 'tonne', unitLabel: 'tonne (stored)', unEceCode: 'TNE', unitPrice: '10'),
    );
    final saved = await _save(tester, form);
    expect(find.text('tonne (stored)'), findsOneWidget);
    expect(saved.unitCode, 'tonne');
    expect(saved.unitLabel, 'tonne (stored)');
    expect(saved.unEceCode, 'TNE');
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

  testWidgets('a new line starts from one default: hour, general supply, base quantity one', (tester) async {
    final saved = await _save(tester, StandaloneLineForm());
    expect(saved.unitCode, 'hour');
    expect(saved.supply, 'general');
    expect(saved.baseQuantity, '1');
  });
}
