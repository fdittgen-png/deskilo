// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #896 — WHEN the tax falls due. #2355 made it a per-country engine
// (`vat_tax_point_test.dart` holds its rules); this file holds the
// setting, the printed mention and the agreement of declaration and
// report on the receipts basis.
//
// A seller on the CASH basis (« TVA sur les encaissements », § 20 UStG's
// Ist-Versteuerung, IVA per cassa) owes the tax the day the customer
// pays, not the day the document was issued. So a period declares the
// payments received inside it, apportioned across the document's rates;
// the same apportionment feeds the accountant's report, so the two can
// never disagree; and the choice is printed on every invoice, because it
// is a statutory mention where it is asked for.
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/money/domain/vat_compliance.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_regime.dart';
import 'package:deskilo/features/money/domain/vat_report.dart';
import 'package:deskilo/features/money/domain/vat_tax_point.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deskilo/features/money/domain/report_data.dart';

Invoice _invoice(
  String id,
  DateTime issuedAt,
  List<InvoiceLine> lines,
) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-$id',
      issuedAt: issuedAt,
      period: '2026-08',
      title: 'Invoice $id',
      lines: lines,
      totalCents: lines.fold(0, (sum, l) => sum + l.amountCents),
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'pezenas1',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: 'sig',
    );

InvoiceMatch _paid(String id, DateTime on, int cents) => InvoiceMatch(
      invoiceId: id,
      paidCents: cents,
      resolution: 'paid',
      matchedAt: on,
    );

final _august = (DateTime(2026, 8, 1), DateTime(2026, 8, 31));
final _september = (DateTime(2026, 9, 1), DateTime(2026, 9, 30));

/// #2355 — what a payment of [paidCents] declares, rate by rate.
Map<double, int> _shares(Invoice invoice, int paidCents) => {
      for (final a in taxPointsOf(
          invoice, [TaxPointPayment(DateTime(2026, 9, 1), paidCents)],
          basis: VatTaxPointBasis.receipt))
        a.percent: a.grossCents,
    };

/// #2355 — the declaration on the receipts basis, through the engine.
List<VatDeclarationLine> _onPayment({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required DateTime periodStart,
  required DateTime periodEnd,
}) =>
    vatDeclarationLinesOf(
        vatTaxPointLedger(invoices,
            matches: matches, basis: VatTaxPointBasis.receipt),
        periodStart,
        periodEnd);

void main() {
  group('the setting', () {
    // #2355 — this used to read "a workspace that never chose is on the
    // invoice basis", for every country. The default is the country's.
    test('a workspace that never chose is on its country\'s default: '
        'receipts in France, the service month in Germany, earlier-of in '
        'the United Kingdom', () {
      const legal = InvoiceLegal();
      expect(legal.vatTaxPoint, isNull);
      expect(legal.taxPointBasis('FR').rule, VatTaxPointRule.receipt);
      expect(legal.taxPointBasis('DE').rule, VatTaxPointRule.servicePeriod);
      expect(legal.taxPointBasis('GB').rule, VatTaxPointRule.earlierOf);
      expect(legal.taxPointBasis('CH').rule, VatTaxPointRule.invoiceDate);
    });

    test('the choice round-trips through the wire key the SQL reads', () {
      const legal = InvoiceLegal(vatTaxPoint: VatTaxPointOption.cash);
      expect(legal.toJson()['vat_exigibility'], 'payment');
      expect(
        InvoiceLegal.fromJson(legal.toJson()).taxPointBasis('DE').onReceipts,
        isTrue,
      );
      expect(legal, isNot(const InvoiceLegal()));
    });
  });

  group('the mention', () {
    test('France names the basis in the words the CGI uses', () {
      expect(
        exigibilityMention(
          regime: VatRegime.vatRegistered,
          sellerCountry: 'fr',
          onPaymentBasis: true,
        ),
        'TVA acquittée sur les encaissements.',
      );
      expect(
        exigibilityMention(
          regime: VatRegime.vatRegistered,
          sellerCountry: 'FR',
          onPaymentBasis: false,
        ),
        "Option pour le paiement de la taxe d'après les débits.",
        reason: 'CGI art. 242 nonies A, I-13°: the option is stated in '
            'these words',
      );
    });

    test('a seller that charges no tax says nothing about when it is due',
        () {
      for (final regime in [VatRegime.notSubject, VatRegime.exempt]) {
        expect(
          exigibilityMention(
            regime: regime,
            sellerCountry: 'FR',
            onPaymentBasis: true,
          ),
          '',
        );
      }
    });

    test('an unlisted country still says it, plainly', () {
      expect(
        exigibilityMention(
          regime: VatRegime.vatRegistered,
          sellerCountry: 'NO',
          onPaymentBasis: true,
        ),
        contains('cash'),
      );
    });
  });

  group('the document says it', () {
    Workspace ws(String? exigibility) => Workspace(
          id: 'ws-1',
          name: 'Demo SARL',
          countryCode: 'FR',
          currencyCode: 'EUR',
          timezone: 'Europe/Paris',
          inviteCode: 'CODE',
          vatRegime: 'vat_registered',
          invoiceLegal: {'vat_exigibility': ?exigibility},
        );

    test('a cash-basis seller prints the encaissements mention', () {
      expect(
        legalMentionData(const ReportStrings(), ws('payment'))['vat_exigibility_mention'],
        'TVA acquittée sur les encaissements.',
      );
    });

    test('and a seller that opted for the debits says so', () {
      expect(
        legalMentionData(const ReportStrings(), ws('invoice'))['vat_exigibility_mention'],
        "Option pour le paiement de la taxe d'après les débits.",
      );
    });

    test('a French seller that never chose is on receipts — the legal rule '
        'for services — and its documents say so (#2355)', () {
      expect(
        legalMentionData(const ReportStrings(), ws(null))['vat_exigibility_mention'],
        'TVA acquittée sur les encaissements.',
      );
    });

    test('a workspace outside the scope of VAT prints nothing', () {
      final outside = ws('payment').copyWith(vatRegime: 'not_subject');
      expect(
        legalMentionData(const ReportStrings(), outside)['vat_exigibility_mention'],
        '',
      );
    });
  });

  group('the payment, rate by rate', () {
    final mixed = _invoice('m', DateTime(2026, 8, 10), const [
      InvoiceLine(kind: 'service', label: 'Salle', amountCents: 6000,
          vatPercent: 20),
      InvoiceLine(kind: 'service', label: 'Café', amountCents: 4000,
          vatPercent: 10),
    ]);

    test('a full payment is the whole document, rate by rate', () {
      expect(_shares(mixed, 10000), {20.0: 6000, 10.0: 4000});
    });

    test('a part payment carries part of every rate', () {
      expect(_shares(mixed, 5000), {20.0: 3000, 10.0: 2000});
    });

    test('the rounding remainder goes to the widest rate — the shares '
        'always add up to what was received', () {
      for (final paid in [1, 7, 33, 999, 3333, 9999]) {
        final shares = _shares(mixed, paid);
        expect(
          shares.values.fold(0, (s, c) => s + c),
          paid,
          reason: 'a $paid ct payment must be fully apportioned',
        );
      }
    });

    test('nothing paid, or nothing owed, splits into nothing', () {
      expect(_shares(mixed, 0), isEmpty);
      final free = _invoice('f', DateTime(2026, 8, 10), const [
        InvoiceLine(kind: 'service', label: 'Offert', amountCents: 0),
      ]);
      expect(_shares(free, 1000), isEmpty);
    });
  });

  group('the declaration', () {
    // Issued in August, paid in September: the two bases put it in two
    // different periods, which is the whole point of the setting.
    final invoice = _invoice('a', DateTime(2026, 8, 10), const [
      InvoiceLine(kind: 'service', label: 'Salle', amountCents: 12000,
          vatPercent: 20),
    ]);
    final matches = {
      'a': _paid('a', DateTime(2026, 9, 3), 12000),
    };

    test('on the invoice basis the tax is due in the month of issue', () {
      expect(
        computeVatDeclarationLines([invoice], _august.$1, _august.$2)
            .single
            .grossCents,
        12000,
      );
      expect(
        computeVatDeclarationLines([invoice], _september.$1, _september.$2),
        isEmpty,
      );
    });

    test('on the cash basis it is due in the month of payment', () {
      expect(
        _onPayment(
          invoices: [invoice],
          matches: matches,
          periodStart: _august.$1,
          periodEnd: _august.$2,
        ),
        isEmpty,
      );
      final september = _onPayment(
        invoices: [invoice],
        matches: matches,
        periodStart: _september.$1,
        periodEnd: _september.$2,
      ).single;
      expect(september.percent, 20);
      expect(september.grossCents, 12000);
      expect(september.netCents, 10000);
      expect(september.vatCents, 2000);
      expect(september.invoiceCount, 1);
    });

    test('an instalment declares only what it settled', () {
      final half = {'a': _paid('a', DateTime(2026, 9, 3), 6000)};
      final line = _onPayment(
        invoices: [invoice],
        matches: half,
        periodStart: _september.$1,
        periodEnd: _september.$2,
      ).single;
      expect(line.grossCents, 6000);
      expect(line.vatCents, 1000);
    });

    test('a voided document is never due, whoever paid it', () {
      final voided = invoice.copyWith(voidedAt: DateTime(2026, 9, 4));
      expect(
        _onPayment(
          invoices: [voided],
          matches: matches,
          periodStart: _september.$1,
          periodEnd: _september.$2,
        ),
        isEmpty,
      );
    });

    test('a payment for a document nobody loaded is skipped, not crashed',
        () {
      expect(
        _onPayment(
          invoices: const [],
          matches: matches,
          periodStart: _september.$1,
          periodEnd: _september.$2,
        ),
        isEmpty,
      );
    });
  });

  group('the report follows the same basis', () {
    final invoice = _invoice('a', DateTime(2026, 8, 10), const [
      InvoiceLine(kind: 'service', label: 'Salle', amountCents: 12000,
          vatPercent: 20),
    ]);
    final matches = {'a': _paid('a', DateTime(2026, 9, 3), 12000)};

    test('given the matches, a position is a payment, dated the day it '
        'was received', () {
      final report = buildVatReport(
        [invoice],
        start: _september.$1,
        end: _september.$2,
        zeroCategory: 'S',
        matches: matches,
        basis: VatTaxPointBasis.receipt,
      );
      expect(report.positions, hasLength(1));
      expect(report.positions.single.issuedAt, DateTime(2026, 9, 3));
      expect(report.positions.single.number, 'INV-a');
      expect(report.grossCents, 12000);
      expect(report.vatCents, 2000);
    });

    test('and the report totals equal the declaration for the same '
        'period — they share one apportionment', () {
      for (final period in [_august, _september]) {
        final report = buildVatReport(
          [invoice],
          start: period.$1,
          end: period.$2,
          zeroCategory: 'S',
          matches: matches,
          basis: VatTaxPointBasis.receipt,
        );
        final declared = _onPayment(
          invoices: [invoice],
          matches: matches,
          periodStart: period.$1,
          periodEnd: period.$2,
        );
        expect(report.vatCents, declared.fold(0, (s, l) => s + l.vatCents));
        expect(report.netCents, declared.fold(0, (s, l) => s + l.netCents));
      }
    });

    test('without matches the report stays on the issue dates', () {
      final report = buildVatReport(
        [invoice],
        start: _august.$1,
        end: _august.$2,
        zeroCategory: 'S',
      );
      expect(report.positions.single.issuedAt, DateTime(2026, 8, 10));
    });
  });
}
