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
    );
