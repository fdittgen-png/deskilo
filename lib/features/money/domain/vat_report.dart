// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #878 — the VAT REPORT: every taxable position of a period, from the
// invoices' frozen `vat_totals` (one entry per rate, as issued) — the
// accountant's view beside the declaration. Nothing is re-aggregated
// from lines: a pre-0072 invoice derives its single zero-rated entry
// exactly as the documents do (vatBreakdown).
import '../../../core/i18n/currencies.dart';
import 'invoice.dart';
import 'vat_tax_point.dart';

/// One invoice × one rate.
class VatReportPosition {
  const VatReportPosition({
    required this.invoiceId,
    required this.number,
    required this.issuedAt,
    required this.customer,
    required this.percent,
    required this.category,
    required this.netCents,
    required this.vatCents,
    required this.grossCents,
    this.reversesNumber = '',
  });

  final String invoiceId;
  final String number;

  /// #2355 — the TAX POINT of this position (the issue date on the
  /// invoice-date rule, the payment's day on receipts…), a calendar date.
  final DateTime issuedAt;
  final String customer;
  final double percent;
  final String category;
  final int netCents;
  final int vatCents;
  final int grossCents;

  /// The original a correcting document reverses (BT-25), when any.
  final String reversesNumber;
}

/// Subtotal per rate (and category — a zero rate is O or E).
class VatRateTotal {
  const VatRateTotal({
    required this.percent,
    required this.category,
    required this.netCents,
    required this.vatCents,
    required this.grossCents,
    required this.documentCount,
  });

  final double percent;
  final String category;
  final int netCents;
  final int vatCents;
  final int grossCents;
  final int documentCount;
}

class VatReport {
  const VatReport({
    required this.periodStart,
    required this.periodEnd,
    required this.positions,
    required this.rateTotals,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<VatReportPosition> positions;
  final List<VatRateTotal> rateTotals;

  int get netCents => rateTotals.fold(0, (s, t) => s + t.netCents);
  int get vatCents => rateTotals.fold(0, (s, t) => s + t.vatCents);
  int get grossCents => rateTotals.fold(0, (s, t) => s + t.grossCents);
  int get documentCount => positions.map((p) => p.invoiceId).toSet().length;
}

/// The tax points of [start]..[end] (inclusive days), one position per
/// document, date and rate, voided documents and settlements excluded
/// (the settlement's sources carry the VAT). [zeroCategory] is the
/// seller's category for a zero rate the document did not freeze.
///
/// #2355 — the positions are the tax-point engine's (`vat_tax_point.dart`)
/// under [basis], the very amounts the declaration sums, so the
/// accountant's list and the return can never disagree: on the invoice
/// date a position is the document; on receipts it is a payment, dated
/// the day it was received; on the service period it is the month the
/// service was performed. [matches] are the accounting view's (a
/// settlement's payment allocated onto its sources) and [instalments]
/// the payments recorded one by one.
VatReport buildVatReport(
  Iterable<Invoice> invoices, {
  required DateTime start,
  required DateTime end,
  required String zeroCategory,
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  VatTaxPointBasis basis = VatTaxPointBasis.invoiceDate,
}) {
  final positions = <VatReportPosition>[];
  String customerOf(Invoice invoice) =>
      invoice.buyerParty?.name.isNotEmpty == true
          ? invoice.buyerParty!.name
          : invoice.memberName;
  final byId = {for (final invoice in invoices) invoice.id: invoice};
  final amounts = vatTaxPointLedger(
    byId.values,
    matches: matches,
    instalments: instalments,
    basis: basis,
  );
  final categories = <String, Map<double, String>>{};
  for (final amount in amounts) {
    if (!amount.within(start, end)) continue;
    final invoice = byId[amount.invoiceId]!;
    // The category the document froze for each rate, so a
    // reverse-charged or exempt supply keeps saying why it bears no tax
    // whenever its tax point falls.
    final frozen = categories.putIfAbsent(invoice.id, () => {
          for (final total in invoice.vatBreakdown(zeroCategory: zeroCategory))
            total.percent: total.category,
        });
    positions.add(VatReportPosition(
      invoiceId: invoice.id,
      number: invoice.number,
      issuedAt: amount.on,
      customer: customerOf(invoice),
      percent: amount.percent,
      category:
          frozen[amount.percent] ?? (amount.percent == 0 ? zeroCategory : 'S'),
      netCents: amount.netCents,
      vatCents: amount.vatCents,
      grossCents: amount.grossCents,
      reversesNumber: invoice.replacesNumber,
    ));
  }
  positions.sort((a, b) {
    final byDate = a.issuedAt.compareTo(b.issuedAt);
    return byDate != 0 ? byDate : a.number.compareTo(b.number);
  });
  final byRate = <String, List<VatReportPosition>>{};
  for (final p in positions) {
    byRate.putIfAbsent('${p.percent}|${p.category}', () => []).add(p);
  }
  final rateTotals = [
    for (final group in byRate.values)
      VatRateTotal(
        percent: group.first.percent,
        category: group.first.category,
        netCents: group.fold(0, (s, p) => s + p.netCents),
        vatCents: group.fold(0, (s, p) => s + p.vatCents),
        grossCents: group.fold(0, (s, p) => s + p.grossCents),
        documentCount: group.map((p) => p.invoiceId).toSet().length,
      ),
  ]..sort((a, b) => b.percent.compareTo(a.percent));
  return VatReport(
    periodStart: start,
    periodEnd: end,
    positions: positions,
    rateTotals: rateTotals,
  );
}

/// The accountant's CSV: one row per position, semicolon-separated
/// (what French and German spreadsheets open without an import
/// dialog), amounts in minor units as decimals with a comma.
String vatReportCsv(VatReport report, {required String currency}) {
  // #1077 — the declared currency's grain, not the euro's. A comma is
  // still the separator: that is what French and German spreadsheets
  // read without an import dialog, whatever the currency.
  final per = Currencies.minorPerMajor(currency);
  final digits = Currencies.minorDigits(currency);
  String money(int minor) {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    if (digits == 0) return '$sign${abs ~/ per}';
    return '$sign${abs ~/ per},'
        '${(abs % per).toString().padLeft(digits, '0')}';
  }
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String cell(String s) => '"${s.replaceAll('"', '""')}"';
  final rows = <String>[
    ['number', 'date', 'customer', 'rate', 'category', 'net', 'vat', 'gross',
      'currency', 'reverses'].join(';'),
    for (final p in report.positions)
      [
        cell(p.number),
        date(p.issuedAt),
        cell(p.customer),
        _percent(p.percent),
        p.category,
        money(p.netCents),
        money(p.vatCents),
        money(p.grossCents),
        currency,
        cell(p.reversesNumber),
      ].join(';'),
  ];
  return '${rows.join('\n')}\n';
}

String _percent(double percent) => percent == percent.roundToDouble()
    ? '${percent.round()}'
    : percent.toStringAsFixed(1).replaceAll('.', ',');
