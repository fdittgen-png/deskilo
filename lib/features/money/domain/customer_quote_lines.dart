// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 -- the lines of a SENT quote revision as the server froze them: the
// invoice line snapshot, decoded ONCE by the package's own decoder
// (`invoiceLineFromSnapshot`), then read for what the customer was offered
// (its words and exact facts) and for what each line comes to (its frozen
// amounts and rate). No second reader of the snapshot lives here.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import 'standalone_invoice.dart';

/// Reads one frozen line of a sent revision, or refuses it: a line whose
/// `commercial` member the package cannot interpret is a read failure
/// ([JsonShapeException], worded by the screen's read-failure path), never a
/// line worth nothing. Only a text line (no member, no amount) stands as its
/// label.
InvoiceLine requireFrozenLine(InvoiceLine line, int index) {
  final facts = line.commercial;
  if (facts is CommercialLineV1) return line;
  if (facts == null && line.amountCents == 0 && line.netCents == null) return line;
  throw JsonShapeException(
    'customer_quote_v1',
    'lines[$index].commercial',
    'a version 1 line',
    switch (facts) {
      CommercialLineUnsupported(:final reason, :final field) =>
        field.isEmpty ? reason.name : '${reason.name}:$field',
      _ => 'a line with amounts and no frozen facts',
    },
  );
}

/// A line of a sent revision as the server froze it: its words are `label`,
/// and its quantity, unit and price are the exact facts of its `commercial`
/// member (see [requireFrozenLine]); a text line reads as its label alone.
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
