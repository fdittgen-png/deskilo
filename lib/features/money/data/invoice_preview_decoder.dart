// SPDX-License-Identifier: AGPL-3.0-or-later

/// #2585 — the strict decoder of `preview_invoice`'s answer.
///
/// The server emits `{lines: [{kind, label, quantity, amount_cents}],
/// total_cents}`. An absent `lines` used to read as an empty invoice, an
/// absent total as 0, and a fractional minor amount was truncated by
/// `toInt()`: a malformed answer rendered as a plausible zero invoice. Here
/// every required field must be present and exact; anything else is a
/// [JsonShapeException] naming the field. A present empty list and a total
/// of 0 are valid; a negative amount (a credit) is valid.
library;

import '../../../core/data/json_reader.dart';
import '../domain/invoice.dart';

const _context = 'preview_invoice';

/// The largest integer a JSON number carries without losing a unit
/// (2^53 - 1, also the web `int` limit).
const _maxSafeInt = 9007199254740991;

/// [value] as the exact whole number of minor units (or pieces) it
/// states; a missing, fractional, non-numeric or unsafe-sized value is a
/// shape error.
int _exactWholeNumber(Object? value, {required String key, String context = _context}) {
  if (value is int && value.abs() <= _maxSafeInt) return value;
  if (value is double &&
      value.isFinite &&
      value == value.truncateToDouble() &&
      value.abs() <= _maxSafeInt) {
    return value.toInt();
  }
  throw JsonShapeException(context, key, 'whole number', _describe(value));
}

String _describe(Object? value) =>
    value == null ? 'null' : '${value.runtimeType} $value';

/// Decodes the raw answer of `preview_invoice`.
({List<InvoiceLine> lines, int totalCents}) decodeInvoicePreview(Object? raw) {
  final reader = JsonReader.of(raw, context: _context);
  final rawLines = reader.raw('lines');
  if (rawLines is! List) {
    throw JsonShapeException(
      _context,
      'lines',
      'List',
      rawLines == null ? 'null' : rawLines.runtimeType.toString(),
    );
  }
  final lines = <InvoiceLine>[
    for (final item in rawLines) _decodeLine(JsonReader.of(item, context: '$_context.lines')),
  ];
  return (
    lines: List.unmodifiable(lines),
    totalCents: _exactWholeNumber(reader.raw('total_cents'), key: 'total_cents'),
  );
}

InvoiceLine _decodeLine(JsonReader line) => InvoiceLine(
      kind: line.string('kind'),
      // The server emits the label for every line; null for an unlabelled one.
      label: line.stringOr('label'),
      quantity: _exactWholeNumber(
        line.raw('quantity'),
        key: 'quantity',
        context: line.context,
      ),
      amountCents: _exactWholeNumber(
        line.raw('amount_cents'),
        key: 'amount_cents',
        context: line.context,
      ),
      // 0072 — optional: absent on every line the server emits today.
      vatPercent: line.numOrNull('vat_percent')?.toDouble() ?? 0,
    );
