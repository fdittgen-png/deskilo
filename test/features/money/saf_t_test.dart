// SPDX-License-Identifier: 0BSD
//
// SAF-T (0074) — the OECD's Standard Audit File for Tax, the industry XML
// for handing a period of accounting data to an accountant. The invoicing
// subset: Header, MasterFiles, SourceDocuments. What it deliberately does
// NOT contain is as important as what it does — no invented chart of
// accounts, because every wrong account code has to be unbooked by hand.
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/presentation/invoice_line_text.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _company = InvoiceParty(
  name: 'pezenas1',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812345678',
  taxExemptionReason: 'Prestations hors du champ de la TVA',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue du Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR99887766554',
);

Invoice _invoice({
  required String number,
  required DateTime issuedAt,
  String memberId = 'member-1',
  int subscription = 25000,
  int payment = 0,
  DateTime? voidedAt,
}) =>
    Invoice(
      id: 'inv-$number',
      workspaceId: 'ws-1',
      memberId: memberId,
      number: number,
      issuedAt: issuedAt,
      period: '${issuedAt.year}-${issuedAt.month.toString().padLeft(2, '0')}',
      title: 'period',
      lines: [
        InvoiceLine(
            kind: 'subscription', label: '100', amountCents: subscription),
        const InvoiceLine(
            kind: 'overage', label: '', quantity: 2, amountCents: 1600),
        if (payment > 0)
          InvoiceLine(
              kind: 'payment', label: 'Virement', amountCents: -payment),
      ],
      totalCents: subscription + 1600 - payment,
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue du Test',
      workspaceName: 'pezenas1',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      voidedAt: voidedAt,
      voidedByName: voidedAt == null ? '' : 'Flo',
      sellerParty: _company,
      buyerParty: _buyer,
    );

XmlDocument _file({
  List<Invoice>? invoices,
  Map<String, InvoiceMatch> matches = const {},
}) =>
    XmlDocument.parse(buildSafTFile(
      invoices: invoices ??
          [
            _invoice(number: 'INV-2026-0001', issuedAt: DateTime(2026, 6, 3)),
            _invoice(
                number: 'INV-2026-0002',
                issuedAt: DateTime(2026, 7, 2),
                payment: 20000),
          ],
      matches: matches,
      company: _company,
      currency: 'EUR',
      softwareVersion: safTSoftwareVersion,
      createdAt: DateTime(2026, 7, 27),
      lineText: (line) => invoiceLineText(null, line),
    ));

String _text(XmlElement parent, String name) =>
    parent.findElements(name).single.innerText;

void main() {
  test('the software version it claims is the app\'s real one', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final version = pubspec
        .firstWhere((line) => line.startsWith('version:'))
        .split(':')[1]
        .trim()
        .split('+')
        .first;

    expect(safTSoftwareVersion, version,
        reason: 'an audit file naming the wrong version lies about its own '
            'provenance');
  });

  test('the header identifies the company, the currency and the period', () {
    final header = _file().findAllElements('Header').single;

    expect(_text(header, 'AuditFileVersion'), '2.00');
    expect(_text(header, 'AuditFileCountry'), 'FR');
    expect(_text(header, 'AuditFileDateCreated'), '2026-07-27');
    expect(_text(header, 'SoftwareID'), 'DesKilo');
    expect(_text(header, 'DefaultCurrencyCode'), 'EUR');

    final company = header.findElements('Company').single;
    expect(_text(company, 'RegistrationNumber'), '812345678');
    expect(_text(company, 'Name'), 'pezenas1');
    expect(
      _text(company.findElements('Address').single, 'PostalCode'),
      '34120',
    );
    // Category O forbids a seller tax registration, and the export must
    // not invent one either.
    expect(company.findAllElements('TaxRegistration'), isEmpty);

    final criteria = header.findElements('SelectionCriteria').single;
    expect(_text(criteria, 'SelectionStartDate'), '2026-06-03',
        reason: 'the period is the span the file actually covers');
    expect(_text(criteria, 'SelectionEndDate'), '2026-07-02');
  });

  test('the namespace is the OECD one — national variants restrict it', () {
    expect(
      _file().rootElement.getAttribute('xmlns'),
      'urn:OECD:StandardAuditFile-Tax:2.00',
    );
  });

  test('customers are the invoice SNAPSHOTS, deduplicated by member', () {
    final doc = _file(invoices: [
      _invoice(number: 'INV-1', issuedAt: DateTime(2026, 5, 3)),
      _invoice(number: 'INV-2', issuedAt: DateTime(2026, 6, 3)),
      _invoice(
          number: 'INV-3', issuedAt: DateTime(2026, 7, 3), memberId: 'm-2'),
    ]);

    final customers = doc.findAllElements('Customer').toList();
    expect(customers, hasLength(2), reason: 'two members, three invoices');
    expect(_text(customers.first, 'CustomerID'), 'member-1');
    expect(
      _text(customers.first.findElements('TaxRegistration').single,
          'TaxRegistrationNumber'),
      'FR99887766554',
      reason: 'a business member carries their VAT id into the export',
    );
  });

  test('NO chart of accounts is invented: no ledger entries, no account ids',
      () {
    final doc = _file();

    expect(doc.findAllElements('GeneralLedgerEntries'), isEmpty);
    expect(doc.findAllElements('AccountID'), isEmpty);
    expect(doc.findAllElements('HeaderComment').single.innerText,
        contains('chart of accounts'),
        reason: 'the file says out loud what it is not');
  });

  test('every invoice is a source document with its lines and totals', () {
    final sales = _file().findAllElements('SalesInvoices').single;

    expect(_text(sales, 'NumberOfEntries'), '2');
    // 266.00 + 66.00 — the soldes, which is what is owed.
    expect(_text(sales, 'TotalCredit'), '332.00');

    final second = sales.findElements('Invoice').last;
    expect(_text(second, 'InvoiceNo'), 'INV-2026-0002');
    expect(_text(second, 'InvoiceDate'), '2026-07-02');
    expect(_text(second, 'CustomerID'), 'member-1');
    expect(_text(second, 'Period'), '2026-07');

    final lines = second.findElements('Line').toList();
    expect(lines, hasLength(2),
        reason: 'the payment is not a line — it lands in the solde');
    expect(_text(lines.first, 'LineNumber'), '1');
    expect(_text(lines.first, 'CreditAmount'), '250.00');
    expect(_text(lines.last, 'Quantity'), '2');
    expect(_text(lines.last, 'UnitPrice'), '8.00');
    expect(
      _text(lines.first.findElements('TaxInformation').single, 'TaxCode'),
      'O',
    );

    final totals = second.findElements('DocumentTotals').single;
    expect(_text(totals, 'TaxPayable'), '0.00');
    expect(_text(totals, 'NetTotal'), '266.00');
    expect(_text(totals, 'GrossTotal'), '66.00',
        reason: 'the solde: charges minus the month\'s payments');
  });

  test('an ERRONEOUS invoice stays in the file, marked annulled and worth '
      'nothing', () {
    final doc = _file(invoices: [
      _invoice(number: 'INV-1', issuedAt: DateTime(2026, 6, 3)),
      _invoice(
        number: 'INV-2',
        issuedAt: DateTime(2026, 6, 4),
        voidedAt: DateTime(2026, 6, 5),
      ),
    ]);
    final sales = doc.findAllElements('SalesInvoices').single;

    expect(_text(sales, 'NumberOfEntries'), '2',
        reason: 'an audit file never deletes what happened');
    expect(_text(sales, 'TotalCredit'), '266.00',
        reason: 'the annulled one adds nothing to the total');
    final voided = sales.findElements('Invoice').last;
    final status = voided.findElements('DocumentStatus').single;
    expect(_text(status, 'InvoiceStatus'), 'A');
    expect(_text(status, 'InvoiceStatusDate'), '2026-06-05');
    expect(_text(status, 'SourceID'), 'Flo');
  });

  test('a matched invoice produces a Payment pointing back at it', () {
    final invoice =
        _invoice(number: 'INV-2026-0009', issuedAt: DateTime(2026, 6, 3));
    final doc = _file(invoices: [invoice], matches: {
      invoice.id: InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 26600,
        resolution: 'exact',
        matchedAt: DateTime(2026, 7, 5),
        byName: 'Flo',
      ),
    });

    final payments = doc.findAllElements('Payments').single;
    expect(_text(payments, 'NumberOfEntries'), '1');
    expect(_text(payments, 'TotalDebit'), '266.00');
    final payment = payments.findElements('Payment').single;
    expect(_text(payment, 'TransactionDate'), '2026-07-05');
    expect(
      _text(payment.findAllElements('SourceDocumentID').single,
          'OriginatingON'),
      'INV-2026-0009',
      reason: 'the payment names the invoice it settled',
    );
  });

  test('a PENDING match is not a payment yet', () {
    final invoice = _invoice(number: 'INV-1', issuedAt: DateTime(2026, 6, 3));
    final doc = _file(invoices: [invoice], matches: {
      invoice.id: InvoiceMatch(
        invoiceId: invoice.id,
        paidCents: 26600,
        resolution: 'exact',
        status: 'pending',
        matchedAt: DateTime(2026, 7, 5),
      ),
    });

    expect(
      _text(doc.findAllElements('Payments').single, 'NumberOfEntries'),
      '0',
      reason: 'a quorum has not decided — nothing is booked',
    );
  });
}
