// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- what a reader may say of a line that carries the `commercial`
// contract. The integer [InvoiceLine.quantity] is the legacy field: on such a
// line it is NOT the quantity, so every reader asks here and never prints it.
import 'commercial_line_snapshot.dart';
import 'invoice.dart';
import 'vat_rate.dart';

extension InvoiceLineCommercial on InvoiceLine {
  /// The interpreted facts, or null on a legacy line or one this reader cannot
  /// interpret.
  CommercialLineV1? get exactFacts => switch (commercial) {
    final CommercialLineV1 v1 => v1,
    _ => null,
  };

  /// A commercial line this reader cannot interpret: it authorises no issue,
  /// correction, stock-out or export, and shows no default quantity.
  CommercialLineUnsupported? get unsupportedFacts => switch (commercial) {
    final CommercialLineUnsupported u => u,
    _ => null,
  };

  /// The quantity a reader may print: the exact decimal of a commercial line,
  /// the legacy integer of every other, and null for a commercial line it
  /// cannot read and has no plain text for (never the integer default).
  String? get quantityText => switch (commercial) {
    null => '$quantity',
    final CommercialLineV1 v1 => v1.quantity.text,
    final CommercialLineUnsupported u => u.rawQuantity,
  };

  /// The net the server froze on a commercial line it can interpret, in
  /// minor units; null on a legacy line (and on one this reader cannot
  /// interpret), whose net a reader derives from its gross as it always did.
  /// A reader that has the frozen net never recomputes a different one.
  int? get frozenNetMinor => exactFacts?.amounts.netMinor;

  /// The line's net in minor units: the frozen net of a commercial line,
  /// else the legacy split of its gross at its rate.
  int get authoritativeNetCents =>
      frozenNetMinor ?? vatSplit(amountCents, vatPercent).netCents;
}

extension InvoiceLinePrinted on InvoiceLine {
  /// The tax split of a writer that states an INTEGER quantity (SAF-T): a
  /// commercial line is refused, never stated through the integer default.
  ({int netCents, int vatCents}) get splitForIntegerQuantity =>
      commercial != null
      ? throw const CommercialOutputBlocked()
      : vatSplit(amountCents, vatPercent);

  /// The quantity a document prints: the exact decimal with its unit, the
  /// legacy integer, or nothing for a line this reader cannot read.
  String get printedQuantity => switch (exactFacts) {
    final v1? => '${v1.quantity.text} ${v1.unit.label}',
    null => quantityText ?? '',
  };

  /// The entered unit price of a commercial line as text ('' when it cannot
  /// be read); null on a legacy line, whose price is derived as before.
  String? get printedUnitPrice => switch (commercial) {
    null => null,
    final CommercialLineV1 v1 => v1.unitPrice.amount.text,
    _ => '',
  };
}

extension InvoiceLinesCommercial on Iterable<InvoiceLine> {
  /// The lines this reader cannot interpret.
  List<InvoiceLine> get uninterpretable => [
    for (final l in this)
      if (l.unsupportedFacts != null) l,
  ];

  /// Whether the document can be issued, corrected, exported or stocked out
  /// by this reader: no line is a commercial line it cannot interpret.
  bool get commercialFactsReadable => uninterpretable.isEmpty;
}

/// A structured invoice of a document with commercial lines is refused: its
/// writers cannot state an exact quantity and unit yet (#4162 X1.B), and a
/// rounded or defaulted one would contradict the document.
class CommercialOutputBlocked implements Exception {
  const CommercialOutputBlocked();

  @override
  String toString() => 'CommercialOutputBlocked';
}
