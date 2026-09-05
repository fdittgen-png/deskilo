// SPDX-License-Identifier: 0BSD
//
// #454/#470: the banded invoice reporting tool — Liquid bands (header /
// body with the lines / footer), the line markup, the fallback contract
// (a broken template never blocks an invoice), the editor, and the
// promise that the XML stays untouched (structural: the CII/UBL
// builders take no template at all).
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

const _data = <String, Object?>{
  'number': 'INV-1',
  'member': 'Ada',
  'total': '42,00 €',
  'voided': false,
  'proforma': false,
  'has_vat': true,
  'lines': [
    {'label': 'Subscription', 'amount': '40,00 €', 'negative': false},
    {'label': 'Locker', 'amount': '2,00 €', 'negative': false},
  ],
  'vat': [
    {'rate': '20 %', 'net': '35,00 €', 'amount': '7,00 €'},
  ],
};

void main() {
  group('invoice report engine (#470)', () {
    test('Liquid loops render the detail band — one table row per line',
        () {
      final report = renderInvoiceReport(
        template: const InvoicePdfTemplate(
          body: '{% for line in lines %}{{ line.label }} | '
              '{{ line.amount }}\n{% endfor %}= Total | {{ total }}',
        ),
        data: Map.of(_data),
      );
      final rows = report!.body.whereType<ReportTableRow>().toList();
      expect(rows, hasLength(3));
      expect(rows[0].cells, ['Subscription', '40,00 €']);
      expect(rows[1].cells, ['Locker', '2,00 €']);
      expect(rows[2].cells, ['Total', '42,00 €']);
      expect(rows[2].bold, isTrue, reason: '= prefix bolds a row');
    });

    test('Liquid conditions branch on the invoice flags', () {
      final report = renderInvoiceReport(
        template: const InvoicePdfTemplate(
          header: '# {% if proforma %}Proforma{% else %}Invoice '
              '{{ number }}{% endif %}',
        ),
        data: Map.of(_data),
      );
      expect((report!.header.single as ReportHeading).text, 'Invoice INV-1');

      final proforma = renderInvoiceReport(
        template: const InvoicePdfTemplate(
          header: '# {% if proforma %}Proforma{% else %}Invoice '
              '{{ number }}{% endif %}',
        ),
        data: {..._data, 'proforma': true},
      );
      expect((proforma!.header.single as ReportHeading).text, 'Proforma');
    });

    test('the line markup maps to every block kind', () {
      final blocks = parseReportMarkup(
          '# Title\n## Section\nBody\n> muted\n---\n\na | b | c');
      expect(blocks[0], isA<ReportHeading>());
      expect(blocks[1], isA<ReportSubheading>());
      expect(blocks[2], isA<ReportText>());
      expect(blocks[3], isA<ReportMuted>());
      expect(blocks[4], isA<ReportDivider>());
      expect(blocks[5], isA<ReportSpacer>());
      expect((blocks[6] as ReportTableRow).cells, ['a', 'b', 'c']);
    });

    test('a BROKEN template falls back (null) — an invoice must never '
        'fail on a template', () {
      expect(
        renderInvoiceReport(
          template: const InvoicePdfTemplate(body: '{% if %}broken'),
          data: Map.of(_data),
        ),
        isNull,
      );
      expect(
        renderInvoiceReport(
            template: InvoicePdfTemplate.empty, data: Map.of(_data)),
        isNull,
        reason: 'no bands = built-in layout',
      );
    });

    test('pre-#470 templates keep working: the legacy intro key maps to '
        'the header band and {{placeholder}} is valid Liquid', () {
      final legacy = InvoicePdfTemplate.fromJson(
          const {'intro': 'Dear {{member}},', 'footer': 'Pay in 30 days.'});
      expect(legacy.header, 'Dear {{member}},');
      expect(legacy.footer, 'Pay in 30 days.');
      final report =
          renderInvoiceReport(template: legacy, data: Map.of(_data));
      expect((report!.header.single as ReportText).text, 'Dear Ada,');
    });

    test('pins the data fields — they are part of saved templates', () {
      expect(InvoicePdfTemplate.placeholders, [
        'number', 'member', 'workspace', 'workspace_address', 'period',
        'issued', 'issued_by', 'replaces', 'total', 'charges', 'payments',
        'voided', 'proforma', 'copy', 'has_vat', 'lines', 'vat',
        // #480 — the legal mention variables.
        'net_total', 'vat_total',
        // #508 — the credit-note fields.
        'credit_note', 'refund_total',
        // #871 — the bank block a payable invoice has to print.
        'iban', 'bic', 'bank_name', 'bank_account', 'bank_code',
        'account_holder', 'payment_reference',
        'seller_legal_form',
        'seller_registration', 'seller_vat_id', 'seller_legal_id',
        'exemption_reason', 'vat_exigibility_mention',
        // #886 — the client's identity as the postal standard prints it.
        'client_name', 'client_company', 'client_phone', 'client_email',
        'client_address', 'client_vat_id',
        'client_legal_id',
        // #873 — the consumption report.
        'usage_paid', 'usage_included_half_days', 'usage_used_half_days',
        'usage_remaining_half_days', 'usage_extra_half_days', 'usage_overage',
        'usage_supplements', 'usage_records',
        // #878 — the VAT report.
        'vat_period', 'vat_period_net', 'vat_period_vat', 'vat_period_gross',
        'vat_basis_note',
        'vat_positions', 'vat_rate_totals',
        'payment_terms', 'payment_terms_source',
        'late_penalty', 'recovery_indemnity', 'escompte', 'insurance',
        'special_mentions', //
      ]);
    });

    test('the default template renders the full built-in shape', () {
      final report = renderInvoiceReport(
        template: defaultInvoiceTemplate(null),
        data: {
          ..._data,
          'workspace': 'Pezenas1',
          'workspace_address': '1 rue du Port',
          'period': 'July 2026',
          'issued': 'Aug 4, 2026',
          'issued_by': 'Flo',
          'replaces': '',
        },
      );
      expect(report, isNotNull);
      // #482 — the facture layout opens with the brand/title column row.
      expect(report!.header.first, isA<ReportColumns>());
      expect(report.body.whereType<ReportTableRow>().length,
          greaterThanOrEqualTo(3));
    });
  });

  testWidgets('the owner edits the three bands and saves (#470)',
      (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();

    // Reset hands a WORKING example…
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    // #822 — the designer opens visual; the raw bands live in Markup.
    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();
    // …which the owner then customizes.
    await tester.enterText(
      find.byKey(const ValueKey('invoice-template-footer')),
      'Payable within 30 days. {% if voided %}VOID{% endif %}',
    );
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-save')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    expect(money.pdfTemplate.header, contains('{{ number }}'));
    expect(money.pdfTemplate.body, contains('{% for line in lines %}'));
    expect(money.pdfTemplate.footer,
        'Payable within 30 days. {% if voided %}VOID{% endif %}');
    expect(find.text('Invoice template saved.'), findsOneWidget);
  });

  testWidgets('QUICK preview simulates execution with sample data — no '
      'invoice, no PDF (#474)', (tester) async {
    // A fresh workspace: zero invoices — the old preview refused; the
    // quick preview runs on simulated data instead.
    await pumpInvoices(tester, money: FakeMoneyRepository());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-quick-preview')));
    await tester.tap(
        find.byKey(const ValueKey('invoice-template-quick-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('report-quick-preview')),
        findsOneWidget);
    expect(find.text('Quick preview — sample data'), findsOneWidget);
    expect(find.textContaining('INV-2026-0042'), findsWidgets);
    expect(find.textContaining('Alex Sample'), findsWidgets);
  });

  testWidgets('the preset gallery fills the bands with a ready-made '
      'report (#474)', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-presets')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('invoice-template-preset-simple')));
    await tester.pumpAndSettle();
    // #822 — read the bands in Markup.
    await tester.tap(find.text('Markup'));
    await tester.pumpAndSettle();

    final header = tester
        .widget<TextField>(
            find.byKey(const ValueKey('invoice-template-header')))
        .controller!
        .text;
    expect(header, contains('{{ workspace }}'));
    // #480 — even the Simple preset keeps the statutory clauses.
    final footer = tester
        .widget<TextField>(
            find.byKey(const ValueKey('invoice-template-footer')))
        .controller!
        .text;
    expect(footer, contains('{{ late_penalty }}'));
  });

  testWidgets('the PDF menu DOWNLOADS to the device — not only share '
      '(#474)', (tester) async {
    final saved = <({String name, Uint8List bytes})>[];
    await pumpInvoices(
      tester,
      money: await seededMoney(),
      saver: ({required bytes, required fileName}) async {
        saved.add((name: fileName, bytes: bytes));
        return 'Download/$fileName';
      },
    );

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-pdf')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-pdf')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(const ValueKey('invoice-template-download')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(String.fromCharCodes(saved.single.bytes.sublist(0, 5)), '%PDF-');
    expect(find.textContaining('Saved to'), findsOneWidget);
  });

  testWidgets('END TO END: a custom banded template renders a real PDF '
      'through the download pipeline (#470)', (tester) async {
    final saved = <({String name, Uint8List bytes})>[];
    final money = await seededMoney();
    money.pdfTemplate = const InvoicePdfTemplate(
      header: '# Invoice {{ number }}\n> {{ workspace }}',
      body: '{% for line in lines %}{{ line.label }} | {{ line.amount }}\n'
          '{% endfor %}= Total | {{ total }}',
      footer: '> Payable within 30 days.',
    );
    await pumpInvoices(
      tester,
      money: money,
      saver: ({required bytes, required fileName}) async {
        saved.add((name: fileName, bytes: bytes));
        return 'Download/$fileName';
      },
    );

    final invoice = money.invoices.single;
    await tester.runAsync(() async {
      await tester
          .tap(find.byKey(ValueKey('invoice-download-row-${invoice.id}')));
      await tester.pump();
    });
    await tester.pumpAndSettle();

    expect(String.fromCharCodes(saved.single.bytes.sublist(0, 5)), '%PDF-');
  });

  test('proforma bands override the invoice bands only when set (#476)',
      () {
    const t = InvoicePdfTemplate(
      header: 'H',
      proforma: ReportBands(header: 'P'),
    );
    expect(t.proformaBands!.header, 'P');
    const untouched = InvoicePdfTemplate(header: 'H');
    expect(untouched.proformaBands, isNull,
        reason: 'empty proforma bands = the invoice template, as before');
    // Round-trip keeps both documents.
    final back = InvoicePdfTemplate.fromJson(
        t.toJson().map((k, v) => MapEntry(k, v)));
    expect(back.proforma.header, 'P');
  });

  testWidgets('the editor lists Proforma and Statement as own documents '
      'and saves them independently (#476)', (tester) async {
    final money = await pumpInvoices(tester, money: await seededMoney());

    await tester.tap(find.byKey(const ValueKey('invoice-template-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-template-doc-proforma')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('invoice-template-doc-statement')),
        findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('invoice-template-doc-statement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-template-reset')));
    await tester.pump();
    await tester.ensureVisible(
        find.byKey(const ValueKey('invoice-template-save')));
    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();

    final stored = money.pdfTemplate;
    expect(stored.statementBands, isNotNull);
    expect(stored.statement.body, contains('{% for line in lines %}'));
    expect(stored.invoiceBands.hasBands, isFalse,
        reason: 'the invoice document stayed untouched');
    expect(stored.proformaBands, isNull);
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
