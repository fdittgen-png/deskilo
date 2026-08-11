// SPDX-License-Identifier: 0BSD
//
// VAT management (0072). The whole feature rests on ONE decision: prices
// in DesKilo are VAT-inclusive, so turning VAT on never changes what a
// member owes — the tax is extracted from the price and shown. These tests
// pin that arithmetic, pin it against the SQL that has to agree with it,
// and then check that every document says the same thing.
import 'dart:io';

import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_cii.dart';
import 'package:deskilo/features/money/domain/invoice_ubl.dart';
import 'package:deskilo/features/money/domain/invoice_ubl_check.dart';
import 'package:deskilo/features/money/domain/saf_t.dart';
import 'package:deskilo/features/money/domain/vat_catalogue.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _seller = InvoiceParty(
  name: 'pezenas1',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  vatId: 'FR12812345678',
  legalId: '812345678',
  vatRegime: 'vat_registered',
);

const _buyer = InvoiceParty(
  name: 'Ana Martin',
  street: '1 Rue du Test',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
);

/// An invoice as `create_invoice` v9 stores one: gross lines, and the
/// breakdown the server computed from them.
Invoice _invoice({
  List<InvoiceLine> lines = const [
    InvoiceLine(
        kind: 'subscription',
        label: '100',
        amountCents: 24000,
        vatPercent: 20),
  ],
  List<InvoiceVatTotal> vatTotals = const [
    InvoiceVatTotal(
      percent: 20,
      category: 'S',
      grossCents: 24000,
      netCents: 20000,
      vatCents: 4000,
    ),
  ],
  int? totalCents,
}) =>
    Invoice(
      id: 'inv-1',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 7, 2),
      period: '2026-06',
      title: '2026-06',
      lines: lines,
      totalCents: totalCents ??
          lines.fold(0, (sum, line) => sum + line.amountCents),
      currency: 'EUR',
      memberName: 'Ana Martin',
      memberAddress: '1 Rue du Test',
      workspaceName: 'pezenas1',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      sellerParty: _seller,
      buyerParty: _buyer,
      vatTotals: vatTotals,
    );

String _lineText(InvoiceLine line) =>
    line.label.isEmpty ? line.kind : '${line.kind} ${line.label}';

void main() {
  group('the split', () {
    test('extracts the tax from a VAT-INCLUSIVE price', () {
      // 240,00 at 20 % = 200,00 + 40,00 — and the two still make 240,00.
      final split = vatSplit(24000, 20);

      expect(split.netCents, 20000);
      expect(split.vatCents, 4000);
      expect(split.netCents + split.vatCents, 24000);
    });

    test('every rate rounds to the cent, and the parts always rebuild the '
        'whole', () {
      const cases = [
        (gross: 24000, percent: 20.0, net: 20000),
        (gross: 1000, percent: 20.0, net: 833),
        (gross: 150, percent: 5.5, net: 142),
        (gross: 1, percent: 20.0, net: 1),
        (gross: 999, percent: 19.0, net: 839),
        (gross: 12345, percent: 7.0, net: 11537),
      ];

      for (final c in cases) {
        final split = vatSplit(c.gross, c.percent);
        expect(split.netCents, c.net,
            reason: '${c.gross} at ${c.percent}%');
        expect(split.netCents + split.vatCents, c.gross,
            reason: 'a cent may never be lost in the rounding');
      }
    });

    test('a zero rate leaves the amount alone — no tax, no net to compute',
        () {
      expect(vatSplit(24000, 0), (netCents: 24000, vatCents: 0));
    });

    test('the SQL computes it the SAME way — the two must never drift', () {
      final sql =
          File('supabase/migrations/0072_vat_management.sql').readAsStringSync();

      // create_invoice's own expression, whitespace-collapsed.
      final normalised = sql.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        normalised,
        contains("round((l->>'amount_cents')::int * 100.0 "
            "/ (100 + coalesce((l->>'vat_percent')::numeric, 0)))::int as net"),
        reason: 'vatSplit and create_invoice must agree to the cent, or a '
            'preview and its invoice disagree about the tax',
      );
      expect(normalised, contains("'vat_cents', gross - net"));
    });
  });

  group('the breakdown', () {
    test('groups charges by rate, highest first, and ignores credits', () {
      final totals = vatTotalsOf(
        const [
          (amountCents: 24000, vatPercent: 20),
          (amountCents: 1200, vatPercent: 20),
          (amountCents: 1000, vatPercent: 5.5),
          (amountCents: -5000, vatPercent: 20),
        ],
        zeroCategory: 'O',
      );

      expect(totals.map((t) => t.percent), [20, 5.5]);
      expect(totals.first.grossCents, 25200,
          reason: 'the two 20 % lines, and not the payment');
      expect(totals.first.netCents, 20000 + 1000);
      expect(totals.first.vatCents, 4000 + 200);
      expect(totals.last.vatCents, 52);
    });

    test('grouping rounds per LINE, exactly like the server', () {
      // Two lines of 0,05 at 20 %: per line net 4, so 8 — grouping the
      // gross first would have given 9.
      final totals = vatTotalsOf(
        const [
          (amountCents: 5, vatPercent: 20),
          (amountCents: 5, vatPercent: 20),
        ],
        zeroCategory: 'O',
      );

      expect(totals.single.netCents, 8);
      expect(totals.single.vatCents, 2);
    });

    test('a zero rate takes its CATEGORY from the workspace regime', () {
      expect(
        vatTotalsOf(const [(amountCents: 1000, vatPercent: 0)],
                zeroCategory: 'E')
            .single
            .category,
        'E',
      );
    });

    test('the invoice prefers its own SNAPSHOT over anything derived', () {
      // A snapshot that disagrees with the lines still wins: it is what
      // the signature covers.
      final invoice = _invoice(vatTotals: const [
        InvoiceVatTotal(
          percent: 10,
          category: 'S',
          grossCents: 24000,
          netCents: 21818,
          vatCents: 2182,
        ),
      ]);

      expect(invoice.vatBreakdown(zeroCategory: 'O').single.percent, 10);
      expect(invoice.vatCents, 2182);
      expect(invoice.netCents, 21818);
    });

    test('the snapshot and the LINES agree — the documents read both', () {
      // The XML puts the snapshot in the totals and the per-line split in
      // the lines (BR-CO-10 makes the sum of the lines fatal), so the two
      // have to describe the same money. create_invoice computes them from
      // the same rows; this pins that they can be checked.
      final invoice = _invoice();
      final derived = invoice.lines
          .where((line) => line.amountCents > 0)
          .fold(0, (sum, line) => sum + vatSplit(line.amountCents, line.vatPercent).netCents);

      expect(derived, invoice.netCents);
    });

    test('a PRE-0072 invoice derives a single zero-rated entry', () {
      // No snapshot AND no rate on the lines: exactly what an invoice
      // issued before 0072 looks like.
      final invoice = _invoice(
        lines: const [
          InvoiceLine(kind: 'subscription', label: '100', amountCents: 24000),
        ],
        vatTotals: const [],
      );

      final breakdown = invoice.vatBreakdown(zeroCategory: 'O');
      expect(breakdown.single.percent, 0);
      expect(breakdown.single.category, 'O');
      expect(breakdown.single.netCents, 24000,
          reason: 'no tax was ever charged, so the net IS the gross');
      expect(invoice.hasVat, isFalse);
    });
  });

  group('the catalogue', () {
    test('offers a country its usual rates, standard first and default', () {
      final rates = vatCatalogueFor('FR');

      expect(rates.map((r) => r.percent), [20, 10, 5.5, 2.1]);
      expect(rates.first.isDefault, isTrue);
      expect(rates.where((r) => r.isDefault), hasLength(1),
          reason: 'set_vat_rates accepts exactly one default');
      expect(rates.every((r) => r.category == 'S'), isTrue);
    });

    test('says nothing about a country it does not know', () {
      expect(hasVatCatalogue('FR'), isTrue);
      expect(hasVatCatalogue('JP'), isFalse);
      expect(vatCatalogueFor('JP'), isEmpty);
    });
  });

  group('e-invoice readiness', () {
    test('a VAT-charging seller WITH a breakdown is ready — that is the '
        'point of 0072', () {
      final readiness = checkEInvoiceReadiness(
        invoice: _invoice(),
        seller: _seller,
        buyer: _buyer,
      );

      expect(readiness.gaps, isEmpty);
      expect(readiness.ready, isTrue);
    });

    test('a VAT-charging seller with NO breakdown is still refused', () {
      final readiness = checkEInvoiceReadiness(
        invoice: _invoice(vatTotals: const []),
        seller: _seller,
        buyer: _buyer,
      );

      expect(readiness.blocking, contains(EInvoiceGap.vatNotSupported),
          reason: 'declaring a zero tax the seller does owe is worse than '
              'refusing the file');
    });

    test('BR-S-02: a VAT-charging seller needs its VAT identifier', () {
      final readiness = checkEInvoiceReadiness(
        invoice: _invoice(),
        seller: _seller.copyWith(vatId: ''),
        buyer: _buyer,
      );

      expect(readiness.blocking, contains(EInvoiceGap.missingVatId));
      expect(VatRegime.vatRegistered.requiresVatId, isTrue);
      expect(VatRegime.vatRegistered.forbidsVatId, isFalse);
    });
  });

  group('UBL', () {
    XmlDocument doc({Invoice? invoice}) => XmlDocument.parse(buildInvoiceUbl(
          invoice: invoice ?? _invoice(),
          seller: _seller,
          buyer: _buyer,
          lineText: _lineText,
        ));

    String text(XmlElement parent, String name) =>
        parent.findElements(name).single.innerText;

    test('the amounts the norm wants tax-EXCLUSIVE are the extracted nets',
        () {
      final totals =
          doc().findAllElements('cac:LegalMonetaryTotal').single;

      expect(text(totals, 'cbc:LineExtensionAmount'), '200.00');
      expect(text(totals, 'cbc:TaxExclusiveAmount'), '200.00');
      // BR-CO-15 — and the gross is what the member always paid.
      expect(text(totals, 'cbc:TaxInclusiveAmount'), '240.00');
      expect(text(totals, 'cbc:PayableAmount'), '240.00');
    });

    test('one TaxSubtotal per rate, each with its percentage (BR-S-05)', () {
      final invoice = _invoice(
        lines: const [
          InvoiceLine(
              kind: 'subscription',
              label: '100',
              amountCents: 24000,
              vatPercent: 20),
          InvoiceLine(
              kind: 'service',
              label: 'Coffee',
              amountCents: 1000,
              vatPercent: 5.5),
        ],
        vatTotals: const [
          InvoiceVatTotal(
              percent: 20,
              category: 'S',
              grossCents: 24000,
              netCents: 20000,
              vatCents: 4000),
          InvoiceVatTotal(
              percent: 5.5,
              category: 'S',
              grossCents: 1000,
              netCents: 948,
              vatCents: 52),
        ],
      );
      final tax = doc(invoice: invoice).findAllElements('cac:TaxTotal').single;

      expect(tax.findElements('cbc:TaxAmount').single.innerText, '40.52',
          reason: 'the header tax is the sum of the subtotals');
      final subtotals = tax.findElements('cac:TaxSubtotal').toList();
      expect(subtotals, hasLength(2));
      expect(text(subtotals.first, 'cbc:TaxableAmount'), '200.00');
      expect(text(subtotals.first, 'cbc:TaxAmount'), '40.00');
      expect(
        text(subtotals.first.findElements('cac:TaxCategory').single,
            'cbc:Percent'),
        '20',
        reason: 'never 20.0 — national validators have tripped on that',
      );
      expect(
        text(subtotals.last.findElements('cac:TaxCategory').single,
            'cbc:Percent'),
        '5.5',
      );
      expect(
        subtotals
            .expand((s) => s.findAllElements('cbc:TaxExemptionReasonCode')),
        isEmpty,
        reason: 'a taxed category has nothing to be exempt from',
      );
    });

    test('a line carries its own rate and its net amount', () {
      final line = doc().findAllElements('cac:InvoiceLine').single;

      expect(text(line, 'cbc:LineExtensionAmount'), '200.00');
      final category =
          line.findAllElements('cac:ClassifiedTaxCategory').single;
      expect(text(category, 'cbc:ID'), 'S');
      expect(text(category, 'cbc:Percent'), '20');
      expect(
        text(line.findElements('cac:Price').single, 'cbc:PriceAmount'),
        '200.00',
      );
    });

    test('a VAT-charging seller DOES carry its VAT identifier', () {
      expect(
        doc()
            .findAllElements('cac:AccountingSupplierParty')
            .single
            .findAllElements('cbc:CompanyID')
            .map((e) => e.innerText),
        contains('FR12812345678'),
      );
    });
  });

  group('CII', () {
    XmlDocument doc({Invoice? invoice}) => XmlDocument.parse(buildInvoiceCii(
          invoice: invoice ?? _invoice(),
          seller: _seller,
          buyer: _buyer,
          lineText: _lineText,
        ));

    test('the settlement summation ties net + tax = gross', () {
      final summation = doc()
          .findAllElements('ram:SpecifiedTradeSettlementHeaderMonetarySummation')
          .single;
      String text(String name) =>
          summation.findElements('ram:$name').single.innerText;

      expect(text('LineTotalAmount'), '200.00');
      expect(text('TaxBasisTotalAmount'), '200.00');
      expect(text('TaxTotalAmount'), '40.00');
      expect(text('GrandTotalAmount'), '240.00');
      expect(text('DuePayableAmount'), '240.00');
    });

    test('the header carries one ApplicableTradeTax per rate', () {
      final settlement = doc()
          .findAllElements('ram:ApplicableHeaderTradeSettlement')
          .single;
      final taxes = settlement.findElements('ram:ApplicableTradeTax').toList();

      expect(taxes, hasLength(1));
      expect(taxes.single.findElements('ram:CalculatedAmount').single.innerText,
          '40.00');
      expect(taxes.single.findElements('ram:BasisAmount').single.innerText,
          '200.00');
      expect(taxes.single.findElements('ram:CategoryCode').single.innerText,
          'S');
      expect(
        taxes.single
            .findElements('ram:RateApplicablePercent')
            .single
            .innerText,
        '20',
      );
    });

    test('the line total is the net, and the line names its rate', () {
      final line =
          doc().findAllElements('ram:IncludedSupplyChainTradeLineItem').single;

      expect(
        line
            .findAllElements('ram:SpecifiedTradeSettlementLineMonetarySummation')
            .single
            .findElements('ram:LineTotalAmount')
            .single
            .innerText,
        '200.00',
      );
      final tax = line.findAllElements('ram:ApplicableTradeTax').single;
      expect(tax.findElements('ram:CategoryCode').single.innerText, 'S');
      expect(tax.findElements('ram:RateApplicablePercent').single.innerText,
          '20');
    });
  });

  group('SAF-T', () {
    XmlDocument file({Invoice? invoice}) => XmlDocument.parse(buildSafTFile(
          invoices: [invoice ?? _invoice()],
          matches: const {},
          company: _seller,
          currency: 'EUR',
          softwareVersion: safTSoftwareVersion,
          createdAt: DateTime(2026, 7, 27),
          lineText: _lineText,
        ));

    test('the tax table declares the rates the file actually uses', () {
      final entries = file().findAllElements('TaxTableEntry').toList();

      expect(entries, hasLength(1));
      expect(entries.single.findElements('TaxCode').single.innerText, 'S20',
          reason: 'a code has to be unique per rate');
      expect(
        entries.single.findElements('TaxPercentage').single.innerText,
        '20.00',
      );
    });

    test('a line is booked net, with its tax beside it', () {
      final line = file().findAllElements('Line').single;

      expect(line.findElements('CreditAmount').single.innerText, '200.00');
      expect(line.findElements('UnitPrice').single.innerText, '200.00');
      final tax = line.findElements('TaxInformation').single;
      expect(tax.findElements('TaxCode').single.innerText, 'S20');
      expect(tax.findElements('TaxAmount').single.innerText, '40.00');
      expect(line.findElements('TaxExemptionReason'), isEmpty,
          reason: 'nothing is exempt on a taxed line');
    });

    test('the document totals declare the tax payable', () {
      final totals = file().findAllElements('DocumentTotals').first;

      expect(totals.findElements('TaxPayable').single.innerText, '40.00');
      expect(totals.findElements('NetTotal').single.innerText, '200.00');
    });
  });

  group('FEC', () {
    List<Map<String, String>> rows({
      Invoice? invoice,
      FecAccounts accounts = const FecAccounts(),
    }) {
      final file = buildFecFile(
        invoices: [invoice ?? _invoice()],
        matches: const {},
        company: _seller,
        accounts: accounts,
        lineText: _lineText,
      );
      final lines = file.split('\r\n');
      final header = lines.first.split('\t');
      return [
        for (final line in lines.skip(1))
          Map.fromIterables(header, line.split('\t')),
      ];
    }

    test('the receivable is gross, the revenue net, and the tax has its own '
        'account', () {
      final entries = rows();

      expect(entries, hasLength(3));
      expect(entries[0]['CompteNum'], '411000');
      expect(entries[0]['Debit'], '240,00', reason: 'what the member owes');
      expect(entries[1]['CompteNum'], '706000');
      expect(entries[1]['Credit'], '200,00', reason: 'what was earned');
      expect(entries[2]['CompteNum'], '445710');
      expect(entries[2]['Credit'], '40,00',
          reason: 'tax collected for the state, not revenue');
      expect(entries[2]['CompteLib'], 'TVA collectée');
      // Double entry: one debit, two credits, same entry, balanced.
      expect(entries.map((r) => r['EcritureNum']).toSet(), {'VE0001'});
      expect(entries[1]['EcritureLib'], contains('20 %'));
    });

    test('each rate books its own pair of lines', () {
      final entries = rows(
        invoice: _invoice(
          lines: const [
            InvoiceLine(
                kind: 'subscription',
                label: '100',
                amountCents: 24000,
                vatPercent: 20),
            InvoiceLine(
                kind: 'service',
                label: 'Coffee',
                amountCents: 1000,
                vatPercent: 5.5),
          ],
          vatTotals: const [
            InvoiceVatTotal(
                percent: 20,
                category: 'S',
                grossCents: 24000,
                netCents: 20000,
                vatCents: 4000),
            InvoiceVatTotal(
                percent: 5.5,
                category: 'S',
                grossCents: 1000,
                netCents: 948,
                vatCents: 52),
          ],
        ),
      );

      expect(entries, hasLength(5),
          reason: 'one receivable, two revenue lines, two tax lines');
      expect(entries[3]['Credit'], '9,48');
      expect(entries[4]['Credit'], '0,52');
      expect(entries[4]['EcritureLib'], contains('5,5 %'),
          reason: 'a French journal writes 5,5, not 5.5');
      final debit = entries
          .fold<int>(0, (sum, r) => sum + _cents(r['Debit'] ?? '0'));
      final credit = entries
          .fold<int>(0, (sum, r) => sum + _cents(r['Credit'] ?? '0'));
      expect(debit, credit, reason: 'an unbalanced FEC is not a FEC');
    });

    test('the VAT account is the owner\'s, like every other account', () {
      final entries = rows(accounts: const FecAccounts(vat: '445711'));

      expect(entries[2]['CompteNum'], '445711');
    });

    test('without VAT the entry is the plain two lines it always was', () {
      final entries = rows(
        invoice: _invoice(
          lines: const [
            InvoiceLine(
                kind: 'subscription', label: '100', amountCents: 24000),
          ],
          vatTotals: const [],
        ),
      );

      expect(entries, hasLength(2));
      expect(entries.last['CompteNum'], '706000');
      expect(entries.last['Credit'], '240,00');
    });
  });
}

/// '240,00' → 24000, so a test can check a journal balances.
int _cents(String amount) =>
    (double.parse(amount.replaceAll(',', '.')) * 100).round();
