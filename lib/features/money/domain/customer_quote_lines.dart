// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 -- the lines of a SENT quote revision as the server froze them: the
// invoice line snapshot, decoded ONCE by the package's own decoder
// (`invoiceLineFromSnapshot`), then read for what the customer was offered
// (its words and exact facts) and for what each line comes to (its frozen
// amounts and rate). No second reader of the snapshot lives here.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:meta/meta.dart';

import 'standalone_invoice.dart';

/// A line of a sent revision as the server froze it: its words are `label`,
/// and its quantity, unit and price are the exact facts of its `commercial`
/// member. A line the decoder cannot interpret reads as its label alone,
/// never as a failure and never with a guessed quantity.
StandaloneLine frozenQuoteLine(InvoiceLine line) {
  final facts = line.commercial;
  if (facts is! CommercialLineV1) {
    return StandaloneLine(
      description: line.label,
      quantity: '',
      unitCode: '',
      unitLabel: '',
      unitPrice: '',
    );
  }
  return StandaloneLine(
    lineId: facts.lineId.isEmpty ? null : facts.lineId,
    description: line.label,
    quantity: facts.quantity.text,
    unitCode: facts.unit.code,
    unitLabel: facts.unit.label,
    unEceCode: facts.unit.unEceCode,
    unitPrice: facts.unitPrice.amount.text,
    grossPrice: facts.unitPrice.gross,
    baseQuantity: facts.unitPrice.baseQuantity.text,
    supply: facts.supply.wire,
    // #4433 -- a goods line keeps the item it sells beside the frozen facts
    itemId: facts.itemId.isEmpty ? null : facts.itemId,
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

  factory QuoteLineAmounts.of(InvoiceLine line) {
    final facts = line.commercial;
    final amounts = facts is CommercialLineV1 ? facts.amounts : null;
    return QuoteLineAmounts(
      netCents: amounts?.netMinor ?? 0,
      taxCents: amounts?.taxMinor ?? 0,
      grossCents: amounts?.grossMinor ?? 0,
      vatPercent: line.vatPercent,
    );
  }

  final int netCents;
  final int taxCents;
  final int grossCents;
  final double vatPercent;
}
