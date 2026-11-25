// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4405 -- a commercial document as the server would freeze it, previewed
// before anything is issued: the facts it cannot accept (named by stable
// keys), or the lines, the per-rate tax and the total. ONE shape for the
// standalone invoice and for the invoice an accepted quote would become.
// Never partial: a document with a missing fact has no lines and no total.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// The key a preview names when the lines it shows do not add up to the total
/// it was told: the document is refused, never shown with one of the two.
const String totalMismatchKey = 'total_mismatch';

class PreviewedDocument {
  const PreviewedDocument({
    required this.missing,
    this.lines = const [],
    this.totalCents = 0,
    this.currency = '',
    this.vatTotals = const [],
  });

  /// Reads `preview_standalone_invoice_v1`.
  factory PreviewedDocument.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'preview_standalone_invoice_v1');
    final missing = r.strings('missing');
    final p = r.objectOrNull('preview');
    if (p == null || missing.isNotEmpty) return PreviewedDocument(missing: missing);
    return PreviewedDocument(
      missing: const [],
      lines: p.objects('lines', (row) => invoiceLineFromSnapshot(row.json)),
      totalCents: p.integer('total_cents'),
      currency: p.stringOr('currency'),
      vatTotals: p.objects(
        'vat_totals',
        (v) => InvoiceVatTotal(
          percent: v.number('percent'),
          category: v.stringOr('category'),
          grossCents: v.integer('gross_cents'),
          netCents: v.integer('net_cents'),
          vatCents: v.integer('vat_cents'),
        ),
      ),
    );
  }

  /// The facts the server cannot accept, as it named them (`line_1_quantity`,
  /// `due_on`, `draft_stale`, [totalMismatchKey]...). Empty when it can be issued.
  final List<String> missing;
  final List<InvoiceLine> lines;
  final int totalCents;
  final String currency;
  final List<InvoiceVatTotal> vatTotals;

  bool get ready => missing.isEmpty && lines.isNotEmpty;
}

/// What the frozen [lines] come to per rate, the highest rate first: the sums
/// of each line's own frozen amounts, never recomputed from a price.
List<InvoiceVatTotal> vatTotalsOfLines(List<InvoiceLine> lines) {
  final byRate = <double, ({int gross, int net, int tax, String category})>{};
  for (final line in lines) {
    final facts = line.commercial;
    if (facts is! CommercialLineV1) continue;
    final before = byRate[line.vatPercent] ?? (gross: 0, net: 0, tax: 0, category: '');
    byRate[line.vatPercent] = (
      gross: before.gross + facts.amounts.grossMinor,
      net: before.net + facts.amounts.netMinor,
      tax: before.tax + facts.amounts.taxMinor,
      category: before.category.isEmpty ? line.vatCategory : before.category,
    );
  }
  final rates = byRate.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final rate in rates)
      InvoiceVatTotal(
        percent: rate,
        category: byRate[rate]!.category,
        grossCents: byRate[rate]!.gross,
        netCents: byRate[rate]!.net,
        vatCents: byRate[rate]!.tax,
      ),
  ];
}

/// The gross total of frozen [lines], the sum of their own frozen amounts.
int grossOfLines(List<InvoiceLine> lines) => lines.fold(0, (sum, l) {
  final facts = l.commercial;
  return sum + (facts is CommercialLineV1 ? facts.amounts.grossMinor : 0);
});
