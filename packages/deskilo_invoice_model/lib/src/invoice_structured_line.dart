// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 (X1.B) -- what the structured invoice (CII, UBL) states for a line
// that carries the commercial contract: the exact quantity with its reviewed
// UN/ECE unit code, the entered net unit price with the quantity it is quoted
// for, and the net the server froze. A legacy line is not asked about: its
// writers are unchanged.
//
// What cannot be stated exactly is refused, never defaulted: a line the reader
// cannot interpret, a unit without its UN/ECE code, a source kind not acted
// on, a correction or a credit note (they cite their source line, which is
// another checkpoint's), and a price entered gross (the structured price is
// net, and no rule derives it from a gross one yet).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'commercial_line_snapshot.dart';
import 'invoice.dart';
import 'invoice_line_commercial.dart';

/// The facts a structured writer states for one commercial line.
class StructuredCommercialLine {
  const StructuredCommercialLine({
    required this.quantity,
    required this.unitCode,
    required this.netCents,
    required this.unitPrice,
    required this.baseQuantity,
    required this.baseUnitCode,
  });

  /// Exact decimal text of the quantity.
  final String quantity;

  /// The reviewed UN/ECE code of the unit.
  final String unitCode;

  /// The line's tax-exclusive amount, frozen by the server (BT-131).
  final int netCents;

  /// The entered net price (BT-146) as exact decimal text, at least as many
  /// places as the currency has.
  final String unitPrice;

  /// The quantity the price is quoted for (BT-149), or null when it is one.
  final String? baseQuantity;
  final String baseUnitCode;
}

/// The structured facts of [line], null for a legacy line; throws
/// [CommercialOutputBlocked] for a commercial line that cannot be stated.
StructuredCommercialLine? structuredCommercialLine(
  InvoiceLine line, {
  required bool creditNote,
  required String currency,
}) {
  final commercial = line.commercial;
  if (commercial == null) return null;
  if (commercial is! CommercialLineV1 ||
      creditNote ||
      commercial.isCorrection ||
      !commercial.exportable ||
      commercial.unitPrice.gross ||
      commercial.amounts.netMinor < 0 ||
      commercial.amounts.currency != currency.trim().toUpperCase() ||
      commercial.unitPrice.currency != commercial.amounts.currency) {
    throw const CommercialOutputBlocked();
  }
  final base = commercial.unitPrice.baseQuantity;
  return StructuredCommercialLine(
    quantity: commercial.quantity.text,
    unitCode: commercial.unit.unEceCode,
    netCents: commercial.amounts.netMinor,
    unitPrice: _atLeastCurrencyPlaces(
      commercial.unitPrice.amount.text,
      exponentOf(currency),
    ),
    baseQuantity: base.text == '1' ? null : base.text,
    baseUnitCode: commercial.unit.unEceCode,
  );
}

String _atLeastCurrencyPlaces(String text, int places) {
  if (places == 0) return text;
  final dot = text.indexOf('.');
  final have = dot < 0 ? 0 : text.length - dot - 1;
  if (have >= places) return text;
  return '${dot < 0 ? '$text.' : text}${'0' * (places - have)}';
}
