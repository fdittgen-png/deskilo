// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A line as the server froze it (`invoices.lines`), read the way every
// reader reads it: what a line lacks is its default, never a failure.
import 'invoice.dart';

InvoiceLine invoiceLineFromSnapshot(Map<Object?, Object?> line) => InvoiceLine(
      kind: line['kind'] as String? ?? '',
      label: line['label'] as String? ?? '',
      quantity: (line['quantity'] as num?)?.toInt() ?? 1,
      amountCents: (line['amount_cents'] as num?)?.toInt() ?? 0,
      vatPercent: (line['vat_percent'] as num?)?.toDouble() ?? 0,
      sourceNumber: line['source_number'] as String? ?? '',
      vatCategory: line['vat_category'] as String? ?? '',
      netCents: (line['net_cents'] as num?)?.toInt(),
      taxCents: (line['tax_cents'] as num?)?.toInt() ?? 0,
      text: _textFactsOf(line['text']),
    );

/// One annex activity row as the server froze it (`details.ledger`).
InvoiceDetailEntry invoiceDetailFromSnapshot(Map<Object?, Object?> entry) =>
    InvoiceDetailEntry(
      on: entry['on'] as String? ?? '',
      category: entry['category'] as String? ?? '',
      label: entry['description'] as String? ?? '',
      amountCents: (entry['amount_cents'] as num?)?.toInt() ?? 0,
      text: _textFactsOf(entry['text']),
    );

/// #3809 — a line's frozen facts, or null when it has none (or they are not
/// an object): what a line lacks is its default, never a failure.
Map<String, Object?>? _textFactsOf(Object? text) => switch (text) {
      final Map<Object?, Object?> facts => {
          for (final MapEntry(:key, :value) in facts.entries) '$key': value,
        },
      _ => null,
    };
