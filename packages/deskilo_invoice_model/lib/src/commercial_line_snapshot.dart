// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4162 (X1.A) -- the `commercial` member of a new line snapshot, version 1:
// the exact quantity, the unit and the entered price, the supply and tax
// facts and the authoritative amounts the server froze on a line. ONE decoder
// reads it for every consumer; a line without the member is a legacy line and
// keeps its integer semantics (this file is never asked about it).
//
// What a reader cannot interpret is never guessed: an unknown version, supply
// kind or source kind, or a value that is not exact, is kept readable as its
// raw facts in a [CommercialLineUnsupported] and authorises nothing. No value
// goes through a binary float or `toInt()`: quantities and prices are decimal
// text read by the kernel's exact decimal, amounts are minor-unit integers
// read from text.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'commercial_line_facts.dart';
import 'commercial_decimal.dart';

/// The only version this decoder interprets.
const int _commercialLineVersion = 1;

/// The supply kinds this version interprets. A goods line is its own kind: it
/// never inherits the place-of-supply semantics of immovable property.
enum CommercialSupply {
  property('property'),
  general('general'),
  goods('goods');

  const CommercialSupply(this.wire);
  final String wire;

  static CommercialSupply? fromWire(Object? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

/// What a commercial line decodes to.
sealed class CommercialLine {
  const CommercialLine();
}

/// A version 1 line, every fact of it interpreted.
final class CommercialLineV1 extends CommercialLine {
  const CommercialLineV1({
    required this.lineId,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.supply,
    required this.amounts,
    this.source,
    this.itemId = '',
    this.variantId = '',
    this.dimensions = const [],
    this.taxFacts = const {},
    this.discount,
  });

  /// The line's own identity in its document, scoped to the seller.
  final String lineId;
  final CommercialDecimal quantity;
  final CommercialUnit unit;
  final CommercialUnitPrice unitPrice;
  final CommercialSupply supply;
  final CommercialAmounts amounts;
  final CommercialSourceRef? source;
  final String itemId;
  final String variantId;

  /// The printed dimension facts: `{dimension, value}` pairs.
  final List<({String dimension, String value})> dimensions;

  /// The frozen tax treatment, rule evidence and dates, kept as the server
  /// wrote them: interpreting them is the tax rules' job, not the decoder's.
  final Map<String, Object?> taxFacts;

  /// Frozen discount facts, kept as written.
  final Map<String, Object?>? discount;

  /// A correction: it names an invoice line as its source.
  bool get isCorrection => source?.kind == 'invoice';

  /// The structured invoice can state this line only with a reviewed unit
  /// code and a source it understands.
  bool get exportable =>
      unit.hasStructuredCode && (source == null || source!.known);

  Map<String, Object?> toJson() => {
    'version': _commercialLineVersion,
    'line_id': lineId,
    if (source != null) 'source_ref': source!.toJson(),
    'quantity': quantity.text,
    'unit': unit.toJson(),
    'unit_price': unitPrice.toJson(),
    if (itemId.isNotEmpty || variantId.isNotEmpty || dimensions.isNotEmpty)
      'item_ref': {
        if (itemId.isNotEmpty) 'item_id': itemId,
        if (variantId.isNotEmpty) 'variant_id': variantId,
        'dimensions': [
          for (final d in dimensions)
            {'dimension': d.dimension, 'value': d.value},
        ],
      },
    if (discount != null) 'discount': discount,
    'supply': supply.wire,
    'tax_facts': taxFacts,
    'amounts': amounts.toJson(),
  };
}

/// Why a line is kept as raw facts.
enum CommercialRefusal {
  /// A version this decoder does not interpret.
  unknownVersion,

  /// A supply kind it does not know.
  unknownSupply,

  /// A fact that is missing, malformed or not exact (a quantity with too many
  /// decimals, amounts that do not add up, an unsupported currency).
  malformed,
}

/// A line this reader cannot interpret. Its [raw] facts stay readable; it
/// authorises no issue, correction, stock-out or export, and is never shown
/// with a default quantity.
final class CommercialLineUnsupported extends CommercialLine {
  const CommercialLineUnsupported(this.reason, this.raw, [this.field = '']);

  final CommercialRefusal reason;
  final Map<String, Object?> raw;

  /// The first fact that could not be read, when the reason is [malformed].
  final String field;

  /// The entered quantity as the server wrote it, when it is plain text a
  /// person can read; null otherwise. It is a display of a historical fact,
  /// never an input to a calculation.
  String? get rawQuantity => switch (raw['quantity']) {
    final String q when exactDecimalGrammar.hasMatch(q) => q,
    _ => null,
  };
}

/// Reads the `commercial` member of a line snapshot. Null when the line has
/// none (a legacy line); otherwise a [CommercialLineV1] or a
/// [CommercialLineUnsupported]. Never throws.
CommercialLine? commercialLineFromSnapshot(Object? member) {
  if (member == null) return null;
  final raw = _map(member);
  if (raw == null) {
    return const CommercialLineUnsupported(
      CommercialRefusal.malformed,
      {},
      'commercial',
    );
  }
  if (raw['version'] != _commercialLineVersion) {
    return CommercialLineUnsupported(CommercialRefusal.unknownVersion, raw);
  }
  final supply = CommercialSupply.fromWire(raw['supply']);
  if (supply == null) {
    return CommercialLineUnsupported(CommercialRefusal.unknownSupply, raw);
  }
  CommercialLine bad(String field) =>
      CommercialLineUnsupported(CommercialRefusal.malformed, raw, field);

  final lineId = _text(raw['line_id']);
  if (lineId.isEmpty) return bad('line_id');
  final source = _sourceOf(raw['source_ref']);
  if (source.bad) return bad('source_ref');
  final correction = source.value?.kind == 'invoice';
  final quantity = parseCommercialDecimal(
    _text(raw['quantity']),
    allowNegative: correction,
  ).value;
  if (quantity == null) return bad('quantity');
  final unit = _unitOf(raw['unit']);
  if (unit == null) return bad('unit');
  final price = _priceOf(raw['unit_price'], correction);
  if (price == null) return bad('unit_price');
  final amounts = _amountsOf(raw['amounts']);
  if (amounts == null) return bad('amounts');
  final item = _itemOf(raw['item_ref']);
  if (item == null) return bad('item_ref');

  return CommercialLineV1(
    lineId: lineId,
    quantity: quantity,
    unit: unit,
    unitPrice: price,
    supply: supply,
    amounts: amounts,
    source: source.value,
    itemId: item.itemId,
    variantId: item.variantId,
    dimensions: item.dimensions,
    taxFacts: _map(raw['tax_facts']) ?? const {},
    discount: _map(raw['discount']),
  );
}

({CommercialSourceRef? value, bool bad}) _sourceOf(Object? raw) {
  if (raw == null) return (value: null, bad: false);
  final s = _map(raw);
  if (s == null || _text(s['kind']).isEmpty || _text(s['id']).isEmpty) {
    return (value: null, bad: true);
  }
  return (
    value: CommercialSourceRef(
      kind: _text(s['kind']),
      id: _text(s['id']),
      revision: _text(s['revision']),
      lineId: _text(s['line_id']),
    ),
    bad: false,
  );
}

CommercialUnit? _unitOf(Object? raw) {
  final u = _map(raw);
  if (u == null || _text(u['code']).isEmpty || _text(u['label']).isEmpty) {
    return null;
  }
  return CommercialUnit(
    code: _text(u['code']),
    label: _text(u['label']),
    unEceCode: _text(u['un_ece_code']),
  );
}

CommercialUnitPrice? _priceOf(Object? raw, bool correction) {
  final p = _map(raw);
  if (p == null) return null;
  final currency = _text(p['currency']).toUpperCase();
  final basis = p['basis'];
  if (!supportedCurrencies.contains(currency) ||
      (basis != 'net' && basis != 'gross')) {
    return null;
  }
  final amount = parseCommercialDecimal(
    _text(p['amount']),
    positive: false,
    allowNegative: correction,
  ).value;
  final base = parseCommercialDecimal(_text(p['base_quantity'])).value;
  if (amount == null || base == null) return null;
  return CommercialUnitPrice(
    amount: amount,
    currency: currency,
    gross: basis == 'gross',
    baseQuantity: base,
  );
}

CommercialAmounts? _amountsOf(Object? raw) {
  final a = _map(raw);
  if (a == null) return null;
  final net = _minor(a['net_minor']);
  final tax = _minor(a['tax_minor']);
  final gross = _minor(a['gross_minor']);
  final currency = _text(a['currency']).toUpperCase();
  if (net == null ||
      tax == null ||
      gross == null ||
      net + tax != gross ||
      !supportedCurrencies.contains(currency)) {
    return null;
  }
  return CommercialAmounts(
    currency: currency,
    netMinor: net,
    taxMinor: tax,
    grossMinor: gross,
    rule: _text(a['rule']),
  );
}

({String itemId, String variantId, List<({String dimension, String value})> dimensions})?
_itemOf(Object? raw) {
  if (raw == null) return (itemId: '', variantId: '', dimensions: const []);
  final item = _map(raw);
  if (item == null) return null;
  final dimensions = <({String dimension, String value})>[];
  final dims = item['dimensions'];
  if (dims is List) {
    for (final d in dims) {
      final m = _map(d);
      if (m == null || _text(m['dimension']).isEmpty || m['value'] == null) {
        return null;
      }
      dimensions.add((dimension: _text(m['dimension']), value: _text(m['value'])));
    }
  }
  return (
    itemId: _text(item['item_id']),
    variantId: _text(item['variant_id']),
    dimensions: dimensions,
  );
}

String _text(Object? v) => v is String ? v.trim() : '';

Map<String, Object?>? _map(Object? v) =>
    v is Map ? {for (final e in v.entries) '${e.key}': e.value} : null;

/// Minor units travel as text (or a JSON integer); never past what JSON can
/// carry exactly.
int? _minor(Object? v) {
  final text = switch (v) {
    final String s => s.trim(),
    final int i => '$i',
    _ => '',
  };
  if (!RegExp(r'^-?\d{1,16}$').hasMatch(text)) return null;
  final n = BigInt.parse(text);
  final limit = BigInt.from(9007199254740991);
  return n.abs() > limit ? null : n.toInt();
}
