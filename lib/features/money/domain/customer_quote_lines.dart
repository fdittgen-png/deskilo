// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 -- the lines of a SENT quote revision as the server froze them: the
// invoice line snapshot, read for what the customer was offered (its words and
// exact facts) and for what each line comes to (its frozen amounts and rate).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import 'standalone_invoice.dart';

/// A line of a sent revision as the server froze it: the invoice line
/// snapshot, whose words are `label` and whose quantity, unit and price are the
/// exact facts of its `commercial` member. A line without one reads as what it
/// has, never as a failure.
StandaloneLine frozenQuoteLine(JsonReader r) {
  final facts = r.objectOrNull('commercial');
  final unit = facts?.objectOrNull('unit');
  final price = facts?.objectOrNull('unit_price');
  return StandaloneLine(
    lineId: facts?.stringOrNull('line_id'),
    description: r.stringOr('label'),
    quantity: facts?.stringOr('quantity') ?? '',
    unitCode: unit?.stringOr('code') ?? '',
    unitLabel: unit?.stringOr('label') ?? '',
    unEceCode: unit?.stringOr('un_ece_code') ?? '',
    unitPrice: price?.stringOr('amount') ?? '',
    grossPrice: price?.stringOr('basis') == 'gross',
    baseQuantity: price?.stringOr('base_quantity', '1') ?? '1',
    supply: r.stringOr('supply', 'general'),
    // #4433 -- a goods line keeps the item it sells beside the frozen facts
    itemId: r.objectOrNull('stock')?.stringOrNull('item_id'),
  );
}

/// What a sent line comes to, as the issuer froze it: the amounts of the
/// line's `commercial.amounts` in minor units and the rate it was taxed at.
@immutable
class QuoteLineAmounts {
  const QuoteLineAmounts({
    required this.netCents,
    required this.taxCents,
    required this.grossCents,
    required this.vatPercent,
  });

  factory QuoteLineAmounts.fromJson(JsonReader r) {
    final amounts = r.objectOrNull('commercial')?.objectOrNull('amounts');
    int minor(String key) => int.tryParse(amounts?.stringOr(key) ?? '') ?? 0;
    return QuoteLineAmounts(
      netCents: minor('net_minor'),
      taxCents: minor('tax_minor'),
      grossCents: minor('gross_minor'),
      vatPercent: r.doubleOrNull('vat_percent') ?? 0,
    );
  }

  final int netCents;
  final int taxCents;
  final int grossCents;
  final double vatPercent;
}
