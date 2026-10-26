// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2373 — Sage 50 UK/IE's audit trail: the 18 columns of its template, one
// code per treatment (T22 for an EU business customer's service, T0, T2 and
// T9 at home, T20 for a domestic reverse charge), the Account Reference a
// member or supplier number of at most eight capitals and digits, and every
// refusal named with nothing written: a party Sage cannot key, output tax
// waiting on its tax point, another currency, a rate group Sage has no code
// for, a reference longer than its column. The seeded year's goldens are
// seeded_year_goldens_test.dart's.
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/accounting_amount.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/sage.dart';
import 'package:deskilo/features/money/domain/sage_documents.dart';
import 'package:deskilo/features/money/domain/sage_postings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

const _gbp = 'GBP';

Invoice _invoice(
  String id, {
  required List<InvoiceVatTotal> vat,
  String buyerCountry = 'GB',
  String memberNumber = 'C-0042',
  String currency = _gbp,
  String number = '',
}) {
  final total = vat.fold(0, (s, t) => s + t.grossCents);
  return Invoice(
    id: id,
    workspaceId: 'ws',
    memberId: 'member-$id',
    number: number.isEmpty ? 'INV-$id' : number,
    issuedAt: DateTime(2026, 3, 4),
    title: 'Desk $id',
    lines: [InvoiceLine(label: 'Desk', amountCents: total)],
    totalCents: total,
    currency: currency,
    memberName: 'Member $id',
    memberAddress: '',
    workspaceName: 'Hub',
    workspaceAddress: '',
    issuerName: 'Owner',
    signature: '',
    sellerParty: const InvoiceParty(name: 'Hub', country: 'GB'),
    buyerParty: InvoiceParty(
      name: 'Member $id',
      country: buyerCountry,
      memberNumber: memberNumber,
    ),
    vatTotals: vat,
  );
}

InvoiceVatTotal _untaxed(String category, int net) => InvoiceVatTotal(
  percent: 0,
  category: category,
  grossCents: net,
  netCents: net,
  vatCents: 0,
);

SageAuditTrail _documents(List<Invoice> invoices) => sageRowsOfInvoices(
  invoices: invoices,
  matches: const {},
  accounts: const SageAccounts(),
  customers: const SageCustomers(memberNumbers: {}, sellerCountry: 'GB'),
  baseCurrency: _gbp,
  groupOf: (t) =>
      ActiveTaxReference.current.groupOfRate('GB', t.percent, t.category),
);

List<String> _cells(SageRow row) =>
    sageFile([row]).split('\r\n')[1].split(',');

PostingLine _line(
  BookRole role,
  String code,
  int cents, {
  required bool debit,
  String? qualifier,
  String currency = _gbp,
}) => PostingLine(
  role: role,
  qualifier: qualifier,
  accountCode: code,
  debit: AccountingAmount(currency, debit ? cents : 0),
  credit: AccountingAmount(currency, debit ? 0 : cents),
);

Posting _posting(
  PostingKind kind,
  List<PostingLine> lines, {
  String document = 'd1',
  String number = 'INV-1',
}) => Posting(
  journal: PostingJournal.sales,
  date: DateTime(2026, 3, 4),
  kind: kind,
  documentId: document,
  documentNumber: number,
  lines: lines,
);

/// A sale of 100.00 at the standard rate, on the book's own chart.
Posting _sale({String currency = _gbp, BookRole tax = BookRole.vatOutput}) =>
    _posting(PostingKind.invoice, [
      _line(BookRole.customers, '1100', 12000, debit: true, currency: currency),
      _line(
        BookRole.revenue,
        '4000',
        10000,
        debit: false,
        qualifier: 'standard',
        currency: currency,
      ),
      _line(
        tax,
        '2200',
        2000,
        debit: false,
        qualifier: tax == BookRole.vatOutput ? 'standard' : null,
        currency: currency,
      ),
    ]);

SageAuditTrail _posted(
  List<Posting> postings, {
  Map<String, PostingParty> parties = const {
    'd1': PostingParty(kind: 'member', number: 'C-0042', name: 'Ana'),
  },
  Map<String, Invoice> documents = const {},
}) => sageRowsOfPostings(
  postings,
  accounts: const SageAccounts(),
  parties: parties,
  documents: documents,
  customers: const SageCustomers(memberNumbers: {}, sellerCountry: 'GB'),
  baseCurrency: _gbp,
  kindText: (kind) => kind.wire,
);

void main() {
  test('the header is the 18 columns of the template, in order', () {
    final header = sageFile(const []).split('\r\n').first.split(',');
    expect(header, hasLength(18));
    expect(header.first, 'Type');
    expect(header.sublist(10), [
      'Exchange Rate',
      'Extra Reference',
      'User Name',
      'Project Refn',
      'Cost Code Refn',
      'Country of VAT',
      'Report Type',
      'Fund',
    ]);
  });

  test('four treatments, four rows, four codes: T22, T0, T2 and T9', () {
    // An EU business customer's service (reverse charged, #2354), a
    // British customer zero-rated, one exempt, one out of scope.
    final trail = _documents([
      _invoice('eu', vat: [_untaxed('AE', 10000)], buyerCountry: 'FR'),
      _invoice('zero', vat: [_untaxed('Z', 10000)]),
      _invoice('exempt', vat: [_untaxed('E', 10000)]),
      _invoice('outside', vat: [_untaxed('O', 10000)]),
    ]);
    expect(trail.blockers, isEmpty);
    final cells = trail.rows.map(_cells).toList();
    expect(cells.map((c) => c[8]), [
      sageEuServicesCode,
      SageAccounts.zeroRatedCode,
      SageAccounts.exemptCode,
      SageAccounts.noTaxCode,
    ]);
    expect(cells.map((c) => c[8]).toSet(), hasLength(4));
    // The EU customer's member state goes in Country of VAT; nobody
    // else's does.
    expect(cells.map((c) => c[15]), ['FR', '', '', '']);
    // The member number in capitals without separators, never an id.
    expect(cells.map((c) => c[1]).toSet(), {'"C0042"'});
  });

  test('a domestic reverse charge is T20, not the EU code', () {
    final trail = _documents([
      _invoice('rc', vat: [_untaxed('AE', 10000)]),
    ]);
    expect(trail.rows.single.taxCode, sageReverseChargeCode);
    expect(trail.rows.single.countryOfVat, '');
  });

  group('the documents are refused, named, and nothing is written', () {
    test('a member with no number Sage can key', () {
      for (final number in ['', 'TOOLONG123']) {
        final trail = _documents([
          _invoice('a', vat: [_untaxed('O', 100)], memberNumber: number),
        ]);
        expect(trail.rows, isEmpty);
        expect(trail.blockers, [
          const SageBlocker(SageBlock.accountReference, 'Member a'),
        ]);
      }
    });

    test('another currency than the base currency', () {
      final trail = _documents([
        _invoice('a', vat: [_untaxed('O', 100)], currency: 'EUR'),
        _invoice('b', vat: [_untaxed('O', 100)]),
      ]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.currency, 'INV-a (EUR)'),
      ]);
    });

    test('a rate Sage 50 has no code for', () {
      final trail = _documents([
        _invoice(
          'a',
          vat: const [
            InvoiceVatTotal(
              percent: 13.5,
              category: 'S',
              grossCents: 11350,
              netCents: 10000,
              vatCents: 1350,
            ),
          ],
        ),
      ]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.taxCode, 'INV-a (S)'),
      ]);
    });

    test('a reference longer than the column', () {
      final long = 'INV-${'9' * sageReferenceLength}';
      final trail = _documents([
        _invoice('a', vat: [_untaxed('O', 100)], number: long),
      ]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [SageBlocker(SageBlock.fieldTooLong, long)]);
    });
  });

  group('a local book\'s postings', () {
    test('a sale is one SI per revenue line with its tax and code', () {
      final trail = _posted([_sale()]);
      expect(trail.blockers, isEmpty);
      final c = _cells(trail.rows.single);
      expect(c.sublist(0, 3), ['SI', '"C0042"', '4000']);
      expect(c.sublist(7, 10), ['100.00', 'T1', '20.00']);
    });

    test('output tax waiting on its tax point is refused by name', () {
      final trail = _posted([_sale(tax: BookRole.vatPending)]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.deferredTax, 'INV-1'),
      ]);
    });

    test('an entry in another currency than the book\'s is refused', () {
      final trail = _posted([_sale(currency: 'EUR')]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.currency, 'INV-1 (EUR)'),
      ]);
    });

    test('a party with no usable number is refused by name', () {
      final trail = _posted(
        [_sale()],
        parties: const {
          'd1': PostingParty(kind: 'member', number: '', name: 'Ana'),
        },
      );
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.accountReference, 'Ana'),
      ]);
    });

    test('an untaxed line takes the document\'s one category: T22', () {
      final eu = _invoice('d1', vat: [_untaxed('AE', 10000)], buyerCountry: 'DE');
      final sale = _posting(PostingKind.invoice, [
        _line(BookRole.customers, '1100', 10000, debit: true),
        _line(BookRole.revenue, '4000', 10000, debit: false),
      ]);
      final trail = _posted([sale], documents: {'d1': eu});
      expect(trail.rows.single.taxCode, sageEuServicesCode);
      expect(trail.rows.single.countryOfVat, 'DE');
    });

    test('untaxed lines of several categories cannot be told apart', () {
      final mixed = _invoice(
        'd1',
        vat: [_untaxed('AE', 5000), _untaxed('O', 5000)],
        buyerCountry: 'DE',
      );
      final sale = _posting(PostingKind.invoice, [
        _line(BookRole.customers, '1100', 10000, debit: true),
        _line(BookRole.revenue, '4000', 5000, debit: false),
        _line(BookRole.revenue, '4000', 5000, debit: false),
      ]);
      final trail = _posted([sale], documents: {'d1': mixed});
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.taxCode, 'INV-1 (mixed)'),
      ]);
    });

    test('a nominal code longer than Sage\'s is refused', () {
      final sale = _posting(PostingKind.invoice, [
        _line(BookRole.customers, '411000000', 100, debit: true),
        _line(BookRole.revenue, '706000000', 100, debit: false, qualifier: 'zero'),
      ]);
      final trail = _posted([sale]);
      expect(trail.rows, isEmpty);
      expect(trail.blockers, [
        const SageBlocker(SageBlock.fieldTooLong, '706000000'),
      ]);
    });

    test('a journal event is one JD or JC per line, with no customer', () {
      final writeOff = _posting(PostingKind.writeOff, [
        _line(BookRole.writeOff, '8100', 4000, debit: true),
        _line(BookRole.customers, '1100', 4000, debit: false),
      ]);
      final rows = _posted([writeOff]).rows;
      expect(rows.map((r) => r.type), ['JD', 'JC']);
      expect(rows.map((r) => r.account), ['', '']);
      expect(rows.map((r) => r.taxCode).toSet(), {SageAccounts.noTaxCode});
    });
  });
}
