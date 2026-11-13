// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3851 -- a printed document names its currency: the ISO code is a
// placeholder, and two currencies that share a symbol are never confused.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquify/liquify.dart';

Invoice _invoice(String currency) => Invoice(
  id: 'inv-$currency',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-1',
  issuedAt: DateTime(2026, 7, 31),
  title: '2026-07',
  lines: const [
    InvoiceLine(kind: 'subscription', label: '100', amountCents: 12000),
  ],
  totalCents: 12000,
  currency: currency,
  memberName: 'Ana',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
);

Map<String, Object?> _data(String currency, {String? locale}) =>
    invoiceReportData(
      ReportStrings(formatLocale: locale),
      _invoice(currency),
      proforma: false,
      copy: false,
      reference: ActiveTaxReference.current,
    );

String _line(Map<String, Object?> data) => Template.parse(
      '{{ total }}{% unless total contains currency %}'
      "{{ ' ' | append: currency }}{% endunless %}",
      data: data,
    ).render();

void main() {
  setUpAll(initializeDateFormatting);

  test('the total line carries the code once, whatever the symbol', () {
    expect(_line({'total': '120,00 €', 'currency': 'EUR'}), '120,00 € EUR');
    expect(_line({'total': 'CAD 120.00', 'currency': 'CAD'}), 'CAD 120.00');
    expect(_line({'total': '120,00 €', 'currency': ''}), '120,00 €');
  });

  test('the document names its ISO code', () {
    expect(_data('CAD')['currency'], 'CAD');
    expect(_data('USD')['currency'], 'USD');
    expect(_data('EUR')['currency'], 'EUR');
  });

  for (final locale in const ['en_US', 'en_CA', 'fr_CA', 'de_DE']) {
    test('CAD and USD side by side are never the same text ($locale)', () {
      final cad = _data('CAD', locale: locale);
      final usd = _data('USD', locale: locale);
      for (final key in const ['total', 'charges', 'net_total']) {
        expect(cad[key], isNot(usd[key]), reason: key);
      }
      // A bare dollar sign is never printed: it carries the code.
      final bare = RegExp(r'^[^A-Za-z]*\$[^A-Za-z]*$');
      for (final d in [cad, usd]) {
        expect(bare.hasMatch(d['total']! as String), isFalse,
            reason: '${d['total']}');
      }
    });
  }

  test('a currency with its own symbol keeps it; the layout prints the code',
      () {
    expect(_data('EUR', locale: 'fr_FR')['total'], contains('€'));
    final xml = defaultLetterLayoutXml('invoice', const LetterStrings());
    expect(xml, contains('append: currency'));
  });
}
