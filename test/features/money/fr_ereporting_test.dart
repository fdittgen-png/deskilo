// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — France e-reporting from the tax-point ledger: B2C sales
// aggregated per day and rate, international B2B per invoice, payment
// data only on receipts, domestic B2B left to its e-invoice, and the
// whole report pinned byte for byte by a golden.
//
// Regenerate ONLY when the file is meant to change:
//   flutter test test/features/money/fr_ereporting_test.dart \
//       --dart-define=WRITE_GOLDEN=true
import 'dart:io';

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');
const _golden = 'test/features/money/goldens/exports/fr_ereporting.xml';

Invoice _invoice(
  String id,
  DateTime day, {
  InvoiceParty? buyer,
  int cents = 12000,
  double vat = 20,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'm-$id',
  number: 'F-$id',
  issuedAt: WorkspaceTime.at(day.year, day.month, day.day, 12).toUtc(),
  period: '2026-09',
  title: id,
  lines: [InvoiceLine(label: 'Desk', amountCents: cents, vatPercent: vat)],
  totalCents: cents,
  currency: 'EUR',
  memberName: 'Ada',
  memberAddress: '',
  workspaceName: 'Space',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  buyerParty: buyer,
);

InvoiceMatch _match(String id, int paid, DateTime on) => InvoiceMatch(
  invoiceId: id,
  paidCents: paid,
  resolution: 'paid',
  matchedAt: WorkspaceTime.at(on.year, on.month, on.day, 12).toUtc(),
);

TaxPointPayment _paid(DateTime on, int cents) => TaxPointPayment(
  WorkspaceTime.at(on.year, on.month, on.day, 12).toUtc(),
  cents,
);

const _b2bFr = InvoiceParty(
  name: 'Acme',
  country: 'FR',
  vatId: 'FR12345678901',
);
const _b2bBe = InvoiceParty(
  name: 'Brussels',
  country: 'BE',
  vatId: 'BE0123456789',
);
const _person = InvoiceParty(name: 'Ada', country: 'FR');

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  final invoices = [
    _invoice('1', DateTime(2026, 9, 2), buyer: _person),
    _invoice('2', DateTime(2026, 9, 2), buyer: _person, cents: 6000),
    _invoice('3', DateTime(2026, 9, 3), buyer: _person, cents: 5000, vat: 0),
    _invoice('4', DateTime(2026, 9, 4), buyer: _b2bBe, cents: 24000),
    _invoice('5', DateTime(2026, 9, 5), buyer: _b2bFr),
    _invoice('6', DateTime(2026, 8, 20), buyer: _person),
  ];
  final matches = {
    '1': _match('1', 12000, DateTime(2026, 9, 12)),
    '2': _match('2', 6000, DateTime(2026, 9, 5)),
    '4': _match('4', 24000, DateTime(2026, 9, 8)),
    '5': _match('5', 12000, DateTime(2026, 9, 6)),
  };
  final instalments = {
    '1': [
      _paid(DateTime(2026, 9, 5), 4000),
      _paid(DateTime(2026, 9, 12), 8000),
    ],
  };
  FrEReport report({bool onReceipts = true}) => frEReport(
    invoices,
    start: DateTime(2026, 9),
    end: DateTime(2026, 9, 30),
    matches: matches,
    instalments: instalments,
    onReceipts: onReceipts,
  );

  test('B2C sales are aggregated per day, category and rate', () {
    final t = report().b2cTransactions;
    expect(t.map((x) => (x.on.day, x.category, x.count, x.netCents)), [
      (2, 'TPS1', 2, 15000),
      (3, 'TNT1', 1, 5000),
    ]);
    expect(t.first.vatCents, 3000);
  });

  test('a sale abroad to a business is reported per invoice', () {
    final t = report().internationalTransactions.single;
    expect(
      (t.invoiceNumber, t.buyerCountry, t.buyerVatId),
      ('F-4', 'BE', 'BE0123456789'),
    );
    expect((t.netCents, t.vatCents), (20000, 4000));
  });

  test('a domestic B2B sale and sales out of the period are left out', () {
    final r = report();
    final all = [
      ...r.b2cTransactions,
      ...r.internationalTransactions,
    ].map((t) => t.invoiceNumber);
    expect(all.contains('F-5'), isFalse);
    expect(r.b2cTransactions.fold(0, (s, t) => s + t.count), 3);
  });

  test('payment data follows the money, one line per instalment', () {
    final r = report();
    expect(r.b2cPayments.map((p) => (p.on.day, p.grossCents, p.vatCents)), [
      (5, 10000, 1667),
      (12, 8000, 1333),
    ]);
    expect(r.b2cPayments.fold(0, (s, p) => s + p.grossCents), 18000);
    expect(r.internationalPayments.single.grossCents, 24000);
    expect(r.internationalPayments.single.invoiceNumber, 'F-4');
  });

  test('on the débits no payment data is owed', () {
    final r = report(onReceipts: false);
    expect(r.b2cPayments, isEmpty);
    expect(r.internationalPayments, isEmpty);
    expect(r.b2cTransactions, isNotEmpty);
  });

  test('the XML is the golden, byte for byte, and well formed', () {
    final xml = report().toXml();
    XmlDocument.parse(xml);
    if (_write) File(_golden).writeAsStringSync(xml);
    expect(xml, File(_golden).readAsStringSync());
  });
}
