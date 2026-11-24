// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4184 (CS1) -- the versioned reader of a frozen counter receipt, the app's twin of the server's
// `counter_receipt_decode`. A finalized receipt is an immutable document (`counter_receipts.frozen`): this reader
// reads version 1 and refuses any other version rather than guess it, and it reads only the keys version 1 defines,
// so a later writer's added keys are ignored. The document is shown as the server froze it: the reader prices
// nothing, and a document whose lines, tax breakdown and totals do not agree is said to disagree, never repaired.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../core/failure/app_failure.dart' show TypedRefusal;

import 'counter_till.dart';

/// The frozen document is not one this reader knows: another version, or a version 1 missing what it must carry.
class CounterReceiptUnreadable implements TypedRefusal {
  const CounterReceiptUnreadable(this.why);

  /// `version <n>` for a version this reader does not know, else the missing part.
  final String why;

  @override
  String toString() => 'CounterReceiptUnreadable($why)';
}

/// A minor-unit amount the server froze: a decimal string inside `commercial.amounts` and the totals.
int _minor(JsonReader r, String key) {
  final value = r.raw(key);
  final parsed = value is int ? value : int.tryParse('${value ?? ''}');
  if (parsed == null) throw CounterReceiptUnreadable('${r.context}.$key');
  return parsed;
}

/// One line of the receipt, as frozen (the `commercial` v1 facts of the standalone invoice's lines).
class CounterReceiptLine {
  const CounterReceiptLine({
    required this.label,
    required this.quantity,
    required this.unit,
    required this.vatPercent,
    required this.netMinor,
    required this.taxMinor,
    required this.grossMinor,
  });

  final String label;

  /// The exact quantity, as the server wrote it (`0.35`).
  final String quantity;

  /// The unit's label (`kg`), empty when the line has none.
  final String unit;

  /// The VAT percent as written (`20`, `5.5`).
  final String vatPercent;
  final int netMinor;
  final int taxMinor;
  final int grossMinor;

  factory CounterReceiptLine._read(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt.lines');
    final commercial = r.objectOrAbsent('commercial');
    final amounts = commercial.objectOrAbsent('amounts');
    return CounterReceiptLine(
      label: r.stringOr('label'),
      quantity: commercial.textOrAbsent('quantity') ?? '1',
      unit: commercial.objectOrAbsent('unit').textOrAbsent('label') ?? '',
      vatPercent: '${r.raw('vat_percent') ?? ''}',
      netMinor: _minor(amounts, 'net_minor'),
      taxMinor: _minor(amounts, 'tax_minor'),
      grossMinor: _minor(amounts, 'gross_minor'),
    );
  }
}

/// One rate of the tax breakdown.
class CounterReceiptTax {
  const CounterReceiptTax({required this.percent, required this.netMinor, required this.taxMinor, required this.grossMinor});

  final String percent;

  /// The rate as a number, for the language to write it; null when the frozen text is not one.
  num? get rate => num.tryParse(percent);
  final int netMinor;
  final int taxMinor;
  final int grossMinor;

  factory CounterReceiptTax._read(Object? json) {
    final r = JsonReader.of(json, context: 'counter_receipt.tax_breakdown');
    return CounterReceiptTax(
      percent: '${r.raw('percent') ?? ''}',
      netMinor: _minor(r, 'net_minor'),
      taxMinor: _minor(r, 'tax_minor'),
      grossMinor: _minor(r, 'gross_minor'),
    );
  }
}

/// The country operation the receipt was issued under, with its specification: the evidence the document carries.
class CounterReceiptOperation {
  const CounterReceiptOperation({
    required this.country,
    required this.operation,
    required this.regime,
    required this.specification,
    required this.specificationVersion,
    required this.effectiveFrom,
    required this.adapter,
    required this.confirmed,
  });

  final String country;
  final String operation;

  /// The owner's declaration the receipt was issued under: `none` or `register_required`.
  final String regime;
  final String specification;
  final String specificationVersion;
  final String effectiveFrom;
  final String adapter;

  /// Whether a tax professional confirmed the registry row (none has yet).
  final bool confirmed;

  factory CounterReceiptOperation._read(JsonReader r) => CounterReceiptOperation(
    country: r.textOrAbsent('country') ?? '',
    operation: r.textOrAbsent('operation') ?? '',
    regime: r.textOrAbsent('regime') ?? '',
    specification: r.textOrAbsent('specification') ?? '',
    specificationVersion: r.textOrAbsent('specification_version') ?? '',
    effectiveFrom: r.textOrAbsent('effective_from') ?? '',
    adapter: r.textOrAbsent('adapter') ?? '',
    confirmed: r.isTrue('confirmed'),
  );
}

/// The receipt a correction cites: a correction is a new receipt, never an edited one.
class CounterReceiptCorrects {
  const CounterReceiptCorrects({required this.receiptId, required this.number, required this.reason});

  final String receiptId;
  final String number;
  final String reason;
}

/// A finalized counter receipt, read from its frozen version-1 document.
class CounterReceiptDocument {
  const CounterReceiptDocument({
    required this.number,
    required this.currency,
    required this.priceBasis,
    required this.issuedAt,
    required this.lines,
    required this.totals,
    required this.taxBreakdown,
    required this.operation,
    this.corrects,
  });

  /// The one version this reader reads.
  static const readableVersion = 1;

  final String number;
  final String currency;

  /// `gross` or `net`: how the unit prices were read.
  final String priceBasis;

  /// When the receipt was numbered; null when the document does not say.
  final DateTime? issuedAt;
  final List<CounterReceiptLine> lines;
  final TillTotals totals;
  final List<CounterReceiptTax> taxBreakdown;
  final CounterReceiptOperation operation;

  /// Set on a correction: the original it cites.
  final CounterReceiptCorrects? corrects;

  bool get isCorrection => corrects != null;

  /// Reads [frozen]: version 1, or [CounterReceiptUnreadable]. Keys a later version adds are not read.
  factory CounterReceiptDocument.decode(Object? frozen) {
    if (frozen is! Map) throw const CounterReceiptUnreadable('document');
    final r = JsonReader.of(frozen, context: 'counter_receipt');
    final version = r.raw('version');
    if (version != readableVersion) throw CounterReceiptUnreadable('version $version');
    final currency = r.textOrAbsent('currency') ?? '';
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) throw const CounterReceiptUnreadable('currency');
    final lines = r.raw('lines');
    if (lines is! List) throw const CounterReceiptUnreadable('lines');
    final totals = r.objectOrNull('totals');
    if (totals == null) throw const CounterReceiptUnreadable('totals');
    final corrects = r.objectOrNull('corrects');
    return CounterReceiptDocument(
      number: r.textOrAbsent('number') ?? '',
      currency: currency,
      priceBasis: r.textOrAbsent('price_basis') ?? 'gross',
      issuedAt: DateTime.tryParse(r.textOrAbsent('issued_at') ?? ''),
      lines: [for (final l in lines) CounterReceiptLine._read(l)],
      totals: TillTotals(
        netMinor: _minor(totals, 'net_minor'),
        taxMinor: _minor(totals, 'tax_minor'),
        grossMinor: _minor(totals, 'gross_minor'),
        currency: currency,
      ),
      taxBreakdown: [for (final t in r.listOrAbsent('tax_breakdown')) CounterReceiptTax._read(t)],
      operation: CounterReceiptOperation._read(r.objectOrAbsent('operation')),
      corrects: corrects == null
          ? null
          : CounterReceiptCorrects(
              receiptId: corrects.textOrAbsent('receipt_id') ?? '',
              number: corrects.textOrAbsent('number') ?? '',
              reason: corrects.textOrAbsent('reason') ?? '',
            ),
    );
  }

  /// What does not agree in the document: the lines against the totals, the tax breakdown against the totals, net
  /// plus tax against gross. Empty for a sound document; the screen shows a document that disagrees as such.
  List<String> get disagreements {
    int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);
    return [
      if (totals.netMinor + totals.taxMinor != totals.grossMinor) 'totals',
      if (sum(lines.map((l) => l.grossMinor)) != totals.grossMinor) 'lines_gross',
      if (sum(lines.map((l) => l.taxMinor)) != totals.taxMinor) 'lines_tax',
      for (var i = 0; i < lines.length; i++)
        if (lines[i].netMinor + lines[i].taxMinor != lines[i].grossMinor) 'line_${i + 1}',
      if (taxBreakdown.isNotEmpty && sum(taxBreakdown.map((t) => t.grossMinor)) != totals.grossMinor) 'breakdown_gross',
      if (taxBreakdown.isNotEmpty && sum(taxBreakdown.map((t) => t.taxMinor)) != totals.taxMinor) 'breakdown_tax',
    ];
  }
}
