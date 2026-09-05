// SPDX-License-Identifier: 0BSD
//
// #878 — the VAT REPORT: every taxable position of a period, from the
// invoices' frozen `vat_totals` (one entry per rate, as issued) — the
// accountant's view beside the declaration. Nothing is re-aggregated
// from lines: a pre-0072 invoice derives its single zero-rated entry
// exactly as the documents do (vatBreakdown).
import 'invoice.dart';

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

/// Issued documents of [start]..[end] (inclusive days), voided ones and
/// documents folded into a settlement excluded (the settlement carries
/// them), each split by rate. [zeroCategory] is the seller's category
/// for a zero rate (O or E) on pre-0072 documents.
VatReport buildVatReport(
  Iterable<Invoice> invoices, {
  required DateTime start,
  required DateTime end,
  required String zeroCategory,
}) {
  final endExclusive = DateTime(end.year, end.month, end.day + 1);
  final positions = <VatReportPosition>[];
  for (final invoice in invoices) {
    if (invoice.isVoided || invoice.isFolded) continue;
    if (invoice.issuedAt.isBefore(start) ||
        !invoice.issuedAt.isBefore(endExclusive)) {
      continue;
    }
    final customer = invoice.buyerParty?.name.isNotEmpty == true
        ? invoice.buyerParty!.name
        : invoice.memberName;
    for (final total in invoice.vatBreakdown(zeroCategory: zeroCategory)) {
      positions.add(VatReportPosition(
        invoiceId: invoice.id,
        number: invoice.number,
        issuedAt: invoice.issuedAt,
        customer: customer,
        percent: total.percent,
        category: total.category,
        netCents: total.netCents,
        vatCents: total.vatCents,
        grossCents: total.grossCents,
        reversesNumber: invoice.replacesNumber,
      ));
    }
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
  String money(int cents) =>
      '${cents < 0 ? '-' : ''}${(cents.abs() ~/ 100)},'
      '${(cents.abs() % 100).toString().padLeft(2, '0')}';
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
