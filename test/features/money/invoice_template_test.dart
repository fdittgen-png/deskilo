// SPDX-License-Identifier: 0BSD
//
// #454: the owner-written invoice-PDF template — placeholder engine,
// the editor sheet, and the promise that it never touches the XML
// (enforced structurally: buildInvoiceCii/buildInvoiceUbl take no
// template at all).
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

void main() {
  group('InvoicePdfTemplate (#454)', () {
    test('apply resolves placeholders, tolerates spaces, leaves unknown '
        'names visible', () {
      const values = {'member': 'Ada', 'total': '42,00 €'};
      expect(
        InvoicePdfTemplate.apply(
            'Dear {{member}}, please pay {{ total }}.', values),
        'Dear Ada, please pay 42,00 €.',
      );
      // A typo must show on the document, not silently vanish.
      expect(
        InvoicePdfTemplate.apply('{{membre}}', values),
        '{{membre}}',
      );
    });

    test('pins the placeholder names — they are part of saved templates',
        () {
      expect(InvoicePdfTemplate.placeholders,
          ['workspace', 'member', 'number', 'period', 'issued', 'total']);
    });

    test('round-trips through json; absent keys read empty', () {
      const t = InvoicePdfTemplate(intro: 'Hello', footer: 'Terms');
      expect(InvoicePdfTemplate.fromJson(t.toJson()).intro, 'Hello');
      expect(InvoicePdfTemplate.fromJson(const {}).isEmpty, isTrue);
    });

    test('migration 0088 stores the column the repository reads', () {
      final sql = File('supabase/migrations/0088_invoice_pdf_template.sql')
          .readAsStringSync();
      expect(sql, contains('invoice_pdf_template'));
    });
  });

  testWidgets('the owner edits and saves the template from the invoices '
      'hub (#454)', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('invoice-template-intro')),
      'Dear {{member}},',
    );
    await tester.enterText(
      find.byKey(const ValueKey('invoice-template-footer')),
      'Payable within 30 days.',
    );
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    expect(money.pdfTemplate.intro, 'Dear {{member}},');
    expect(money.pdfTemplate.footer, 'Payable within 30 days.');
    expect(find.text('Invoice template saved.'), findsOneWidget);
  });

  testWidgets('the e-invoice XML builders take no template — structural '
      'guarantee the XML stays untouched (#454)', (tester) async {
    final cii = File('lib/features/money/domain/invoice_cii.dart')
        .readAsStringSync();
    final ubl = File('lib/features/money/domain/invoice_ubl.dart')
        .readAsStringSync();
    expect(cii, isNot(contains('InvoicePdfTemplate')));
    expect(ubl, isNot(contains('InvoicePdfTemplate')));
    expect(FakeMoneyRepository().pdfTemplate.isEmpty, isTrue);
  });
}
