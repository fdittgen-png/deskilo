// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 -- the small facts a commercial line freezes (version 1): where it
// comes from, its unit, the price it was entered at and its authoritative
// amounts. Read by `commercialLineFromSnapshot`.
import 'commercial_decimal.dart';

/// The source kinds this version can act on. Others stay readable.
const Set<String> _commercialSourceKinds = {'quote', 'commitment', 'invoice'};

/// The commercial commitment or document a line comes from, and its frozen
/// source line: a quote line behind an invoice line, the original line behind
/// a correction.
class CommercialSourceRef {
  const CommercialSourceRef({
    required this.kind,
    required this.id,
    this.revision = '',
    this.lineId = '',
  });

  final String kind;
  final String id;
  final String revision;
  final String lineId;

  bool get known => _commercialSourceKinds.contains(kind);

  Map<String, Object?> toJson() => {
    'kind': kind,
    'id': id,
    if (revision.isNotEmpty) 'revision': revision,
    if (lineId.isNotEmpty) 'line_id': lineId,
  };
}

/// The unit as it was frozen: its registry code, the reviewed UN/ECE code the
/// structured output needs, and the printed label.
class CommercialUnit {
  const CommercialUnit({
    required this.code,
    required this.label,
    this.unEceCode = '',
  });

  final String code;
  final String label;
  final String unEceCode;

  /// Without a reviewed UN/ECE code the structured output is blocked: it is
  /// never defaulted to a generic unit.
  bool get hasStructuredCode => unEceCode.isNotEmpty;

  Map<String, Object?> toJson() => {
    'code': code,
    'un_ece_code': unEceCode,
    'label': label,
  };
}

/// What was entered as the price: the exact amount, its currency, whether it
/// is net or gross and the quantity it is quoted for.
class CommercialUnitPrice {
  const CommercialUnitPrice({
    required this.amount,
    required this.currency,
    required this.gross,
    required this.baseQuantity,
  });

  final CommercialDecimal amount;
  final String currency;
  final bool gross;
  final CommercialDecimal baseQuantity;

  Map<String, Object?> toJson() => {
    'amount': amount.text,
    'currency': currency,
    'basis': gross ? 'gross' : 'net',
    'base_quantity': baseQuantity.text,
  };
}

/// The line's authoritative amounts in minor units of its currency. The
/// server computed them; a reader never recomputes a different total.
class CommercialAmounts {
  const CommercialAmounts({
    required this.currency,
    required this.netMinor,
    required this.taxMinor,
    required this.grossMinor,
    this.rule = '',
  });

  final String currency;
  final int netMinor;
  final int taxMinor;
  final int grossMinor;

  /// The rounding or allocation rule that explains the result.
  final String rule;

  Map<String, Object?> toJson() => {
    'currency': currency,
    'net_minor': '$netMinor',
    'tax_minor': '$taxMinor',
    'gross_minor': '$grossMinor',
    if (rule.isNotEmpty) 'rule': rule,
  };
}

