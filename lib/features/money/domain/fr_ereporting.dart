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
// A legacy line is a service: the transaction category is TPS1 (taxable
// services) or TNT1 (not taxable in France: a zero rate). A commercial line
// (#4162) states its supply, and #4163 reports goods as TLB1 from the frozen
// amounts, apart from services at the same rate (fr_ereporting_supply.dart).
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
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;
import 'package:xml/xml.dart';

import 'fr_ereporting_capacity.dart';
import 'fr_ereporting_supply.dart';

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

/// What the reporting is judged by: the country whose businesses an
/// e-invoice already reports (from the installed VAT filing add-on) and
/// whether the seller's VAT on services falls due on receipts.
class EReportingBasis {
  const EReportingBasis({required this.homeCountry, this.onReceipts = true});

  final String homeCountry;
  final bool onReceipts;
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
    this.unresolved = const [],
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

  /// #4163 -- the in-scope documents whose buyer could not be sorted from
  /// their frozen facts. A report with any is not complete: it is a
  /// diagnostic, never a payload.
  final List<FrUnresolved> unresolved;

  bool get isComplete => unresolved.isEmpty;

  bool get isEmpty =>
      b2cTransactions.isEmpty &&
      internationalTransactions.isEmpty &&
      b2cPayments.isEmpty &&
      internationalPayments.isEmpty;

  /// The report in the flows' structure, amounts with a dot, dates ISO.
  String toXml() {
    if (!isComplete) {
      throw StateError(
        'the e-reporting is incomplete: ${unresolved.map((u) => u.number).join(', ')}',
      );
    }
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
/// [basis].onReceipts is whether the seller's VAT on services falls due on
/// receipt (the French default; false after the option for the débits),
/// which is what makes the payment data owed.
FrEReport frEReport(
  Iterable<Invoice> invoices, {
  required DateTime start,
  required DateTime end,
  required TaxReferenceSet reference,
  required DateTime Function(DateTime instant) dayOf,
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  required EReportingBasis basis,
  String currency = 'EUR',
}) {
  final byId = {for (final i in invoices) i.id: i};
  final sorted = sortFrInvoices(
    invoices,
    basis.homeCountry,
    _PeriodReach(
      start: start,
      end: end,
      reference: reference,
      dayOf: dayOf,
      matches: matches,
      instalments: instalments,
    ),
    onReceipts: basis.onReceipts,
  );
  FrBuyerKind? kindOf(String id) => sorted.classes[id];
  final unresolved = sorted.unresolved;
  // #4163 -- goods-bearing documents report their frozen lines; the others
  // keep the tax-point ledger (and, on receipts, are the only ones owed
  // payment data: goods fall due on delivery).
  final plain = sorted.plain;
  final sales = frSales(
    sorted,
    byId,
    reference: reference,
    dayOf: dayOf,
    start: start,
    end: end,
  );
  final b2cSales = <(DateTime, String, double), FrTransaction>{};
  final intlSales = <FrTransaction>[];
  for (final a in sales) {
    final category = a.category;
    if (kindOf(a.invoiceId) == FrBuyerKind.b2c) {
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

  final money = basis.onReceipts
      ? _receipts(
          byId,
          kindOf,
          vatTaxPointLedger(
            plain,
            matches: matches,
            instalments: instalments,
            basis: VatTaxPointBasis.receipt,
            reference: reference,
            dayOf: dayOf,
          ).where((a) => a.within(start, end)),
        )
      : (b2c: <FrPayment>[], international: <FrPayment>[]);

  return FrEReport(
    unresolved: unresolved,
    start: start,
    end: end,
    currency: currency,
    b2cTransactions: b2cSales.values.toList()
      ..sort((a, b) => _byDayThenRate(a.on, b.on, a.percent, b.percent)),
    internationalTransactions: intlSales
      ..sort((a, b) => _byDayThenNumber(a.on, b.on, a.invoiceNumber, b.invoiceNumber)),
    b2cPayments: money.b2c
      ..sort((a, b) => _byDayThenRate(a.on, b.on, a.percent, b.percent)),
    internationalPayments: money.international
      ..sort((a, b) => _byDayThenNumber(a.on, b.on, a.invoiceNumber, b.invoiceNumber)),
  );
}

/// Day first, then the higher rate first.
int _byDayThenRate(DateTime a, DateTime b, double ratea, double rateb) {
  final d = a.compareTo(b);
  return d != 0 ? d : rateb.compareTo(ratea);
}

/// Day first, then the invoice number.
int _byDayThenNumber(DateTime a, DateTime b, String numa, String numb) {
  final d = a.compareTo(b);
  return d != 0 ? d : numa.compareTo(numb);
}

/// Whether a document's sale, or the money for it, falls in the period.
class _PeriodReach implements FrPeriodReach {
  const _PeriodReach({
    required this.start,
    required this.end,
    required this.reference,
    required this.dayOf,
    required this.matches,
    required this.instalments,
  });

  final DateTime start;
  final DateTime end;
  final TaxReferenceSet reference;
  final DateTime Function(DateTime instant) dayOf;
  final Map<String, InvoiceMatch> matches;
  final Map<String, List<TaxPointPayment>> instalments;

  @override
  bool sale(Invoice invoice) =>
      vatTaxPointLedger([invoice], reference: reference, dayOf: dayOf)
          .any((a) => a.within(start, end));

  @override
  bool receipt(Invoice invoice) => vatTaxPointLedger(
    [invoice],
    reference: reference,
    dayOf: dayOf,
    matches: matches,
    instalments: instalments,
    basis: VatTaxPointBasis.receipt,
  ).any((a) => a.within(start, end));
}

/// The money received, from the tax-point [receipts] of the plain invoices:
/// private customers aggregated per day and rate, businesses abroad per
/// invoice.
({List<FrPayment> b2c, List<FrPayment> international}) _receipts(
  Map<String, Invoice> byId,
  FrBuyerKind? Function(String id) kindOf,
  Iterable<VatTaxPointAmount> receipts,
) {
  final b2c = <(DateTime, double), FrPayment>{};
  final international = <FrPayment>[];
  for (final a in receipts) {
    if (kindOf(a.invoiceId) == FrBuyerKind.b2c) {
      final key = (a.on, a.percent);
      final seen = b2c[key];
      b2c[key] = FrPayment(
        on: a.on,
        percent: a.percent,
        grossCents: (seen?.grossCents ?? 0) + a.grossCents,
        vatCents: (seen?.vatCents ?? 0) + a.vatCents,
      );
    } else {
      final invoice = byId[a.invoiceId]!;
      international.add(
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
  return (b2c: b2c.values.toList(), international: international);
}
