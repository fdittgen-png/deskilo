// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 (DATEV 3b) — DATEV derives the tax from the revenue account, so each
// rate books to its own automatic account (SKR03 8400 for 19 %, 8300 for
// 7 %), never the gross of two rates on one.
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';

/// The automatic revenue account of the rate [percent] in [reference]'s
/// German chart: [base] for the standard rate and wherever the chart names
/// no account for the rate's group.
String datevRevenueAt(TaxReferenceSet reference, double percent, String base) {
  final group = reference.groupOfRate('DE', percent, 'S');
  if (group.isEmpty || group == 'standard') return base;
  final row = reference
      .resolved(null)
      .lookup(TaxDomain.accountMap, 'DE', 'datev/revenue:$group');
  return (row?.value as AccountMapValue?)?.account ?? base;
}

/// #2365 — [cents] of [invoice] per automatic revenue account of its rates:
/// the positions of the document's sign summed per account, the last
/// account taking what the sum leaves so the parts add up to [cents]. One
/// account, one part: the document as before.
List<(String, int)> datevRevenueParts(
  Invoice invoice,
  int cents,
  String Function(double percent) revenueAt,
) {
  final parts = <String, int>{};
  for (final line in invoice.lines) {
    // A credit note's positions are negative, an invoice's charges positive.
    final ofSign = invoice.isCreditNote
        ? line.amountCents < 0
        : line.amountCents > 0;
    if (!ofSign) continue;
    final account = revenueAt(line.vatPercent);
    parts[account] = (parts[account] ?? 0) + line.amountCents.abs();
  }
  if (parts.length <= 1) {
    return [(parts.keys.firstOrNull ?? revenueAt(0), cents)];
  }
  final out = <(String, int)>[];
  var left = cents;
  for (final (k, MapEntry(key: account, value: part))
      in parts.entries.indexed) {
    final take = k == parts.length - 1 ? left : part;
    out.add((account, take));
    left -= take;
  }
  return out;
}
