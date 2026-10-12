// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — FRANCE E-REPORTING, generated from the tax-point engine.
//
// From the French reform a seller reports to the DGFiP, through its
// plateforme agréée, what an e-invoice does not carry:
//
//  * TRANSACTION data of the sales that are not a domestic B2B invoice:
//    sales to private persons (B2C, aggregated per day, category and
//    rate) and sales to a business abroad (B2B international, one line
//    per invoice);
//  * PAYMENT data of services whose VAT falls due on receipt: the money
//    received per day and rate (B2C aggregated, B2B international per
//    invoice). A seller that opted for the débits owes no payment data.
//
// A coworking sells services, so the transaction category is TPS1
// (taxable services) or TNT1 (not taxable in France: a zero rate).
//
// Both flows are read from [vatTaxPointLedger], so the e-reporting, the
// VAT return and the FEC cannot disagree about one cent: the
// transactions from the ledger on the INVOICE date (the day the sale is
// made), the payments from the ledger on RECEIPTS (the day the money
// arrives). A domestic B2B sale (a buyer with a French VAT id) is
// reported by its e-invoice and is left out here.
//
// Pure Dart. [FrEReport.toXml] writes the report in the structure of
// the DGFiP external specification's flows 10.1-10.4; the field names a
// given plateforme agréée maps from it are its own, and the live
// round-trip waits on a PA sandbox.
import 'package:xml/xml.dart';

import '../../../core/money/money_text.dart';
import '../../../core/text/number_text.dart';
import '../../../core/time/date_text.dart';
import 'invoice.dart';
import 'vat_tax_point.dart';

/// Who bought, as e-reporting sorts it.
enum _Kind {
  /// A private person, in France or abroad: reported per day, aggregated.
  b2c,

  /// A business with a VAT id outside France: reported per invoice.
  b2bInternational,

  /// A French business: its e-invoice reports it, nothing here.
  b2bDomestic;

  /// The kind of the sale [invoice] made.
  static _Kind of(Invoice invoice) {
    final buyer = invoice.buyerParty;
    final vatId = (buyer?.vatId ?? '').trim();
    if (vatId.isEmpty) return b2c;
    final country = (buyer?.country ?? '').trim().toUpperCase();
    final prefix = vatId.length >= 2 ? vatId.substring(0, 2).toUpperCase() : '';
    final abroad = country.isNotEmpty ? country != 'FR' : prefix != 'FR';
    return abroad ? b2bInternational : b2bDomestic;
  }
}

/// The transaction category of the flow: TPS1 services taxed in France,
/// TNT1 not taxable in France.
String _category(double percent) => percent > 0 ? 'TPS1' : 'TNT1';

/// One transaction line: a day, a category and a rate — and, for the
/// international B2B flow, the invoice behind it.
class FrTransaction {
  const FrTransaction({
    required this.on,
    required this.category,
    required this.percent,
    required this.netCents,
    required this.vatCents,
    this.count = 1,
    this.invoiceNumber = '',
    this.buyerCountry = '',
    this.buyerVatId = '',
  });

  final DateTime on;
  final String category;
  final double percent;
  final int netCents;
  final int vatCents;

  /// The documents folded into an aggregated line.
  final int count;
  final String invoiceNumber;
  final String buyerCountry;
  final String buyerVatId;
}

/// Money received on a service, per day and rate.
class FrPayment {
  const FrPayment({
    required this.on,
    required this.percent,
    required this.grossCents,
    required this.vatCents,
    this.invoiceNumber = '',
    this.buyerCountry = '',
    this.buyerVatId = '',
  });

  final DateTime on;
  final double percent;
  final int grossCents;
  final int vatCents;
  final String invoiceNumber;
  final String buyerCountry;
  final String buyerVatId;
}

/// The e-reporting of one period.
class FrEReport {
  const FrEReport({
    required this.start,
    required this.end,
    required this.currency,
    required this.b2cTransactions,
    required this.internationalTransactions,
    required this.b2cPayments,
    required this.internationalPayments,
  });

  final DateTime start;
  final DateTime end;
  final String currency;

  /// Flux 10.3 — aggregated per day, category and rate.
  final List<FrTransaction> b2cTransactions;

  /// Flux 10.1 — one line per invoice and rate.
  final List<FrTransaction> internationalTransactions;

  /// Flux 10.4 — aggregated per day and rate.
  final List<FrPayment> b2cPayments;

  /// Flux 10.2 — one line per invoice, day and rate.
  final List<FrPayment> internationalPayments;

  bool get isEmpty =>
      b2cTransactions.isEmpty &&
      internationalTransactions.isEmpty &&
      b2cPayments.isEmpty &&
      internationalPayments.isEmpty;

  /// The report in the flows' structure, amounts with a dot, dates ISO.
  String toXml() {
    String amount(int cents) => minorToText(cents, currency);
    final builder = XmlBuilder()
      ..processing('xml', 'version="1.0" encoding="UTF-8"');
    void leaf(String name, String text) => builder.element(name, nest: text);
    builder.element(
      'Report',
      nest: () {
        builder.element(
          'Period',
          nest: () {
            builder.element('Start', nest: isoDay(start));
            leaf('End', isoDay(end));
            leaf('Currency', currency);
          },
        );
        void transactions(String name, List<FrTransaction> list) {
          if (list.isEmpty) return;
          builder.element(
            name,
            nest: () {
              for (final t in list) {
                builder.element(
                  'Transaction',
                  nest: () {
                    builder.element('Date', nest: isoDay(t.on));
                    leaf('Category', t.category);
                    leaf('VatRate', percentText(t.percent));
                    leaf('TaxableAmount', amount(t.netCents));
                    leaf('TaxAmount', amount(t.vatCents));
                    if (t.invoiceNumber.isEmpty) {
                      leaf('Count', '${t.count}');
                    } else {
                      leaf('InvoiceNumber', t.invoiceNumber);
                      leaf('BuyerCountry', t.buyerCountry);
                      leaf('BuyerVatId', t.buyerVatId);
                    }
                  },
                );
              }
            },
          );
        }

        void payments(String name, List<FrPayment> list) {
          if (list.isEmpty) return;
          builder.element(
            name,
            nest: () {
              for (final p in list) {
                builder.element(
                  'Payment',
                  nest: () {
                    builder.element('Date', nest: isoDay(p.on));
                    leaf('VatRate', percentText(p.percent));
                    leaf('Amount', amount(p.grossCents));
                    leaf('TaxAmount', amount(p.vatCents));
                    if (p.invoiceNumber.isNotEmpty) {
                      leaf('InvoiceNumber', p.invoiceNumber);
                      leaf('BuyerCountry', p.buyerCountry);
                      leaf('BuyerVatId', p.buyerVatId);
                    }
                  },
                );
              }
            },
          );
        }

        transactions('InternationalB2BTransactions', internationalTransactions);
        transactions('B2CTransactions', b2cTransactions);
        payments('InternationalB2BPayments', internationalPayments);
        payments('B2CPayments', b2cPayments);
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }
}

/// The e-reporting of [start]..[end] (both inclusive days) for a French
/// seller, from the accounting view's [invoices], [matches] and
/// [instalments] — the arguments of [vatTaxPointLedger].
///
/// [onReceipts] is whether the seller's VAT on services falls due on
/// receipt (the French default; false after the option for the débits),
/// which is what makes the payment data owed.
FrEReport frEReport(
  Iterable<Invoice> invoices, {
  required DateTime start,
  required DateTime end,
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  bool onReceipts = true,
  String currency = 'EUR',
}) {
  final byId = {for (final i in invoices) i.id: i};
  _Kind kindOf(String id) => _Kind.of(byId[id]!);
  final reportable = [
    for (final i in invoices)
      if (_Kind.of(i) != _Kind.b2bDomestic) i,
  ];

  final sales = vatTaxPointLedger(reportable)
      .where((a) => a.within(start, end));
  final b2cSales = <(DateTime, String, double), FrTransaction>{};
  final intlSales = <FrTransaction>[];
  for (final a in sales) {
    final category = _category(a.percent);
    if (kindOf(a.invoiceId) == _Kind.b2c) {
      final key = (a.on, category, a.percent);
      final seen = b2cSales[key];
      b2cSales[key] = FrTransaction(
        on: a.on,
        category: category,
        percent: a.percent,
        netCents: (seen?.netCents ?? 0) + a.netCents,
        vatCents: (seen?.vatCents ?? 0) + a.vatCents,
        count: (seen?.count ?? 0) + 1,
      );
    } else {
      final invoice = byId[a.invoiceId]!;
      intlSales.add(
        FrTransaction(
          on: a.on,
          category: category,
          percent: a.percent,
          netCents: a.netCents,
          vatCents: a.vatCents,
          invoiceNumber: invoice.number,
          buyerCountry: invoice.buyerParty?.country ?? '',
          buyerVatId: invoice.buyerParty?.vatId ?? '',
        ),
      );
    }
  }

  final b2cMoney = <(DateTime, double), FrPayment>{};
  final intlMoney = <FrPayment>[];
  if (onReceipts) {
    final receipts = vatTaxPointLedger(
      reportable,
      matches: matches,
      instalments: instalments,
      basis: VatTaxPointBasis.receipt,
    ).where((a) => a.within(start, end));
    for (final a in receipts) {
      if (kindOf(a.invoiceId) == _Kind.b2c) {
        final key = (a.on, a.percent);
        final seen = b2cMoney[key];
        b2cMoney[key] = FrPayment(
          on: a.on,
          percent: a.percent,
          grossCents: (seen?.grossCents ?? 0) + a.grossCents,
          vatCents: (seen?.vatCents ?? 0) + a.vatCents,
        );
      } else {
        final invoice = byId[a.invoiceId]!;
        intlMoney.add(
          FrPayment(
            on: a.on,
            percent: a.percent,
            grossCents: a.grossCents,
            vatCents: a.vatCents,
            invoiceNumber: invoice.number,
            buyerCountry: invoice.buyerParty?.country ?? '',
            buyerVatId: invoice.buyerParty?.vatId ?? '',
          ),
        );
      }
    }
  }

  int byDate(DateTime a, DateTime b) => a.compareTo(b);
  return FrEReport(
    start: start,
    end: end,
    currency: currency,
    b2cTransactions: b2cSales.values.toList()
      ..sort((a, b) {
        final d = byDate(a.on, b.on);
        return d != 0 ? d : b.percent.compareTo(a.percent);
      }),
    internationalTransactions: intlSales
      ..sort((a, b) {
        final d = byDate(a.on, b.on);
        return d != 0 ? d : a.invoiceNumber.compareTo(b.invoiceNumber);
      }),
    b2cPayments: b2cMoney.values.toList()
      ..sort((a, b) {
        final d = byDate(a.on, b.on);
        return d != 0 ? d : b.percent.compareTo(a.percent);
      }),
    internationalPayments: intlMoney
      ..sort((a, b) {
        final d = byDate(a.on, b.on);
        return d != 0 ? d : a.invoiceNumber.compareTo(b.invoiceNumber);
      }),
  );
}
