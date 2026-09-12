// SPDX-License-Identifier: 0BSD
//
// #1061 / #1048 task 3.1 — the acceptance test of the ReportStrings seam:
// "every rendered document is byte-identical before and after. Assert it
// on a fixture, do not eyeball it."
//
// The goldens under goldens/ were written by the PRE-seam builders (the
// ones that took a BuildContext), from this very fixture, in English and
// in French. The builders now take a ReportStrings and must produce the
// same bytes. Regenerate ONLY when a document is meant to change:
//
//   flutter test test/features/money/report_data_golden_test.dart \
//       --dart-define=WRITE_GOLDEN=true
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/money/domain/report_data.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

final _invoice = Invoice(
  id: 'inv-1',
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-2026-0007',
  issuedAt: DateTime(2026, 7, 31),
  title: '2026-07',
  lines: const [
    InvoiceLine(kind: 'subscription', label: '100', amountCents: 20000),
    InvoiceLine(kind: 'overage', label: '', quantity: 3, amountCents: 4500),
    InvoiceLine(kind: 'accessories', label: '', amountCents: 1200),
    InvoiceLine(kind: 'level', label: '', amountCents: 800),
    InvoiceLine(kind: 'office', label: '', amountCents: 900),
    InvoiceLine(kind: 'desk', label: '', amountCents: 300),
    InvoiceLine(kind: 'adjustment', label: '', amountCents: -500),
    InvoiceLine(kind: 'adjustment', label: 'Goodwill', amountCents: -200),
    InvoiceLine(kind: 'payment', label: 'PayPal', amountCents: -10000),
    InvoiceLine(kind: 'payment', label: '', amountCents: -1000),
    InvoiceLine(kind: 'expense', label: 'Taxi', amountCents: -2500),
    InvoiceLine(kind: 'service', label: 'Coffee ×3', amountCents: 450),
  ],
  totalCents: 13950,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '1 Rue Test, 34120 Pezenas',
  workspaceName: 'Test Space',
  workspaceAddress: '2 Place du Marche, 34120 Pezenas',
  issuerName: 'Flo',
  signature: 'f' * 64,
  replacesNumber: 'INV-2026-0003',
  detailed: true,
  detailLedger: const [
    InvoiceDetailEntry(
        on: '2026-07-02', category: 'subscription', label: '', amountCents: 20000),
    InvoiceDetailEntry(
        on: '2026-07-05', category: 'overage', label: 'Fri', amountCents: 1500),
    InvoiceDetailEntry(
        on: '2026-07-09', category: 'expense', label: 'Taxi', amountCents: -2500),
    InvoiceDetailEntry(
        on: '2026-07-12', category: 'payment', label: 'PayPal', amountCents: -10000),
    InvoiceDetailEntry(
        on: '2026-07-15', category: 'adjustment', label: '', amountCents: -500),
    InvoiceDetailEntry(
        on: '2026-07-20', category: 'service', label: 'Coffee', amountCents: 450),
    InvoiceDetailEntry(
        on: '2026-07-22', category: 'other', label: 'Key', amountCents: 100),
  ],
  buyerParty: const InvoiceParty(
    name: 'Ana Martin',
    company: 'Martin SARL',
    courtesy: 'mrs',
    person: 'Ana Martin',
    street: '1 Rue Test',
    city: 'Pezenas',
    postalCode: '34120',
  ),
  sellerParty: const InvoiceParty(
    name: 'Test Space',
    company: 'Test Space SAS',
    street: '2 Place du Marche',
    city: 'Pezenas',
    postalCode: '34120',
  ),
);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Test Space',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'CODE123456',
  invoiceLegal: {'is_association': false},
);

Future<Map<String, Object?>> _build(
    WidgetTester tester, Locale locale, bool proforma) async {
  late Map<String, Object?> data;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) {
      data = invoiceReportData(
        reportStringsFor(context),
        _invoice,
        proforma: proforma,
        copy: false,
        workspace: _workspace,
        dueAt: DateTime(2026, 8, 30),
      );
      return const SizedBox();
    }),
  ));
  return data;
}

void main() {
  for (final locale in const [Locale('en'), Locale('fr'), Locale('de')]) {
    for (final proforma in const [false, true]) {
      final name =
          'invoice_report_data_${locale.languageCode}${proforma ? '_proforma' : ''}';
      testWidgets('$name is byte-identical to the pre-seam golden',
          (tester) async {
        final data = await _build(tester, locale, proforma);
        final encoded = const JsonEncoder.withIndent('  ').convert(data);
        final file = File('test/features/money/goldens/$name.json');
        if (_write) {
          file.writeAsStringSync('$encoded\n');
          return;
        }
        expect(encoded, file.readAsStringSync().trimRight(),
            reason: 'the document changed — if that is intended, '
                'regenerate with --dart-define=WRITE_GOLDEN=true');
      });
    }
  }
}
