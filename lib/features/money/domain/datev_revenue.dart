// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 (DATEV 3b) — DATEV derives the tax from the revenue account, so each
// rate books to its own automatic account (SKR03 8400 for 19 %, 8300 for
// 7 %; SKR04 4400 and 4300), never the gross of two rates on one. The
// SKR04 plan's defaults are rows of their own (`datev/<role>@SKR04`).
import '../../../core/vat/tax_reference.dart';
import '../../../core/vat/tax_reference_active.dart';
import 'invoice.dart';

/// The automatic revenue account of the rate [percent] in [reference]'s
/// German [chart]: [base] for the standard rate and wherever the chart names
/// no account for the rate's group.
String datevRevenueAt(
  TaxReferenceSet reference,
  double percent,
  String base, {
  String chart = 'SKR03',
}) {
  final group = reference.groupOfRate('DE', percent, 'S');
  if (group.isEmpty || group == 'standard') return base;
  return datevChartAccount(reference, chart, 'revenue:$group') ?? base;
}

/// The DATEV row of [role] in [chart]: `datev/<role>@SKR04` in the SKR04
/// plan, `datev/<role>` in SKR03; null where the reference has none.
String? datevChartAccount(
  TaxReferenceSet reference,
  String chart,
  String role,
) {
  final skr04 = chart.trim().toUpperCase() == 'SKR04';
  final row = reference
      .resolved(null)
      .lookup(
        TaxDomain.accountMap,
        'DE',
        skr04 ? 'datev/$role@SKR04' : 'datev/$role',
      );
  return (row?.value as AccountMapValue?)?.account;
}

/// The automatic revenue account of the rate group [group] in [chart]: the
/// chart's own revenue account [standard] for the standard rate (and for a
/// rate the reference puts in no group), the chart's `revenue:<group>` row
/// otherwise; null where the chart names none.
String? datevAutomaticRevenue(
  TaxReferenceSet reference,
  String chart,
  String group,
  String standard,
) => group.isEmpty || group == 'standard'
    ? standard
    : datevChartAccount(reference, chart, 'revenue:$group');

/// The BU-Schlüssel of the rate group [group]: the `datev/tax:<group>` row's
/// tax code; null where the reference holds none.
String? datevGroupTaxKey(TaxReferenceSet reference, String group) {
  final row = reference
      .resolved(null)
      .lookup(TaxDomain.accountMap, 'DE', 'datev/tax:$group');
  final code = (row?.value as AccountMapValue?)?.taxCode ?? '';
  return code.isEmpty ? null : code;
}

/// Where one position of a rate is booked: the revenue account and the
/// BU-Schlüssel the row carries ('' on an automatic account).
typedef DatevRevenueTarget = ({String account, String taxKey});

/// One part of a document's sale: [cents] on [account] with [taxKey].
typedef DatevRevenuePart = ({String account, String taxKey, int cents});

/// #2365 — [cents] of [invoice] per revenue account and BU-Schlüssel of its
/// rates: the positions of the document's sign summed per target, the last
/// target taking what the sum leaves so the parts add up to [cents]. One
/// target, one part: the document as before.
List<DatevRevenuePart> datevRevenueParts(
  Invoice invoice,
  int cents,
  DatevRevenueTarget Function(double percent) targetAt,
) {
  final parts = <DatevRevenueTarget, int>{};
  for (final line in invoice.lines) {
    // A credit note's positions are negative, an invoice's charges positive.
    final ofSign = invoice.isCreditNote
        ? line.amountCents < 0
        : line.amountCents > 0;
    if (!ofSign) continue;
    final target = targetAt(line.vatPercent);
    parts[target] = (parts[target] ?? 0) + line.amountCents.abs();
  }
  if (parts.length <= 1) {
    final only = parts.keys.firstOrNull ?? targetAt(0);
    return [(account: only.account, taxKey: only.taxKey, cents: cents)];
  }
  final out = <DatevRevenuePart>[];
  var left = cents;
  for (final (k, MapEntry(key: target, value: part))
      in parts.entries.indexed) {
    final take = k == parts.length - 1 ? left : part;
    out.add((account: target.account, taxKey: target.taxKey, cents: take));
    left -= take;
  }
  return out;
}
