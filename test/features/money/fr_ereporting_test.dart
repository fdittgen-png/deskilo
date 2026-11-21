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
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/domain/fr_ereporting.dart';
import 'package:deskilo/features/money/domain/fr_ereporting_capacity.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
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
  Map<String, Object?>? frozen,
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
  legalSnapshot: frozen,
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

/// What the document froze at issue: the capacity the customer stated and
/// the country (`legal_snapshot`, #1916).
Map<String, Object?> _frozen(String capacity, String country, {String source = 'member'}) => {
  'schema': 1,
  'buyer_capacity': capacity,
  'capacity_source': source,
  'buyer_country': country,
};
final _asPerson = _frozen('consumer', 'FR');
final _asBusinessFr = _frozen('business', 'FR');
final _asBusinessBe = _frozen('business', 'BE');

void main() {
  setUp(() => WorkspaceTime.install('Europe/Paris'));
  tearDown(WorkspaceTime.reset);

  final invoices = [
    _invoice('1', DateTime(2026, 9, 2), buyer: _person, frozen: _asPerson),
    _invoice('2', DateTime(2026, 9, 2), buyer: _person, cents: 6000, frozen: _asPerson),
    _invoice('3', DateTime(2026, 9, 3), buyer: _person, cents: 5000, vat: 0, frozen: _asPerson),
    _invoice('4', DateTime(2026, 9, 4), buyer: _b2bBe, cents: 24000, frozen: _asBusinessBe),
    _invoice('5', DateTime(2026, 9, 5), buyer: _b2bFr, frozen: _asBusinessFr),
    _invoice('6', DateTime(2026, 8, 20), buyer: _person, frozen: _asPerson),
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
    basis: EReportingBasis(homeCountry: eReportingCountry, onReceipts: onReceipts), dayOf: WorkspaceTime.dateOf, reference: ActiveTaxReference.current,);

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

  group('the buyer is sorted from what the document froze (#4163)', () {
    FrEReport run(List<Invoice> docs, {Map<String, InvoiceMatch> paid = const {}}) => frEReport(
      docs,
      start: DateTime(2026, 9),
      end: DateTime(2026, 9, 30),
      matches: paid,
      basis: EReportingBasis(homeCountry: eReportingCountry),
      dayOf: WorkspaceTime.dateOf,
      reference: ActiveTaxReference.current,
    );
    final day = DateTime(2026, 9, 10);

    test('a French business with no VAT number is a domestic business, not a consumer', () {
      final r = run([
        _invoice('a', day, buyer: const InvoiceParty(name: 'Martin SAS', country: 'FR'), frozen: _asBusinessFr),
      ]);
      expect(r.isComplete, isTrue);
      expect(r.b2cTransactions, isEmpty, reason: 'its e-invoice reports it');
      expect(r.isEmpty, isTrue);
    });

    test('a consumer carrying a stray VAT-like value stays a consumer', () {
      final r = run([
        _invoice('b', day, buyer: const InvoiceParty(name: 'Ada', country: 'FR', vatId: 'FR99'), frozen: _asPerson),
      ]);
      expect(r.b2cTransactions.single.count, 1);
    });

    test('a business abroad is reported per invoice, and needs its VAT number', () {
      final ok = run([_invoice('c', day, buyer: _b2bBe, frozen: _asBusinessBe)]);
      expect(ok.internationalTransactions.single.invoiceNumber, 'F-c');
      final bare = run([
        _invoice('d', day, buyer: const InvoiceParty(name: 'Brussels', country: 'BE'), frozen: _asBusinessBe),
      ]);
      expect(bare.unresolved.single.reasons, [FrUnresolvedReason.buyerVatIdMissing]);
    });

    test('legacy_without_capacity: an invoice with no frozen capacity is unresolved, never guessed', () {
      final r = run([
        _invoice('e', day, buyer: _person),
        _invoice('f', day, buyer: _b2bFr),
      ]);
      expect(r.unresolved.map((u) => (u.number, u.reasons.single)), [
        ('F-e', FrUnresolvedReason.noFrozenCapacity),
        ('F-f', FrUnresolvedReason.noFrozenCapacity),
      ]);
      expect(r.isComplete, isFalse);
      expect(r.b2cTransactions, isEmpty, reason: 'nothing is sorted by default');
      expect(r.toXml, throwsStateError);
    });

    test('an unstated capacity, a missing country and two countries are unresolved', () {
      final r = run([
        _invoice('g', day, buyer: _person, frozen: _frozen('unknown', 'FR', source: 'none')),
        _invoice('h', day, buyer: const InvoiceParty(name: 'X'), frozen: _frozen('business', '')),
        _invoice('i', day, buyer: _b2bBe, frozen: _asBusinessFr),
      ]);
      expect({for (final u in r.unresolved) u.number: u.reasons.single}, {
        'F-g': FrUnresolvedReason.capacityUnknown,
        'F-h': FrUnresolvedReason.buyerCountryMissing,
        'F-i': FrUnresolvedReason.buyerCountryConflict,
      });
    });

    test('an unresolved document outside the period does not block the month', () {
      final r = run([_invoice('j', DateTime(2026, 7, 3), buyer: _person)]);
      expect(r.isComplete, isTrue);
    });

    test('the live profile never reclassifies: the same frozen facts, a changed buyer name, VAT number and company', () {
      final before = run([_invoice('k', day, buyer: _person, frozen: _asPerson)]);
      final after = run([
        _invoice('k', day,
          buyer: const InvoiceParty(name: 'Ada SAS', company: 'Ada SAS', country: 'FR', vatId: 'FR12345678901'),
          frozen: _asPerson),
      ]);
      expect(after.b2cTransactions.single.netCents, before.b2cTransactions.single.netCents);
      expect(after.b2cTransactions.length, before.b2cTransactions.length);
      expect(after.internationalTransactions, isEmpty);
    });

    test('a document in an earlier month with its money in the month still blocks (receipts)', () {
      final old = _invoice('l', DateTime(2026, 8, 20), buyer: _person);
      final r = run([old], paid: {'l': _match('l', 12000, DateTime(2026, 9, 3))});
      expect(r.unresolved.single.number, 'F-l');
    });
  });

  test('the XML is the golden, byte for byte, and well formed', () {
    final xml = report().toXml();
    XmlDocument.parse(xml);
    if (_write) File(_golden).writeAsStringSync(xml);
    expect(xml, File(_golden).readAsStringSync());
  });
}
