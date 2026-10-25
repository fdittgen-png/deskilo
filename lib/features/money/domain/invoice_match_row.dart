// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'invoice.dart';
import 'vat_tax_point.dart';

/// One `invoice_matches` row as the app holds it. The same reading for the
/// invoice list's matches and for the matches of the one fiscal source of an
/// export (#2365), so the two can never disagree on what a row means.
InvoiceMatch invoiceMatchOf(JsonReader row) => InvoiceMatch(
  invoiceId: row.string('invoice_id'),
  paidCents: row.integer('paid_cents'),
  resolution: row.string('resolution'),
  note: row.stringOr('note'),
  status: row.stringOr('status', 'confirmed'),
  paymentLedgerId: row.stringOrNull('payment_ledger_id'),
  matchedAt: row.dateTime('matched_at').toLocal(),
  byName: row.stringOr('by_name'),
  writeoffAt: row.dateTimeOrNull('writeoff_at')?.toLocal(),
  // #841 — who released it, reachable from the document.
  eventId: row.stringOrNull('event_id'),
);

/// One `invoice_match_payments` row (#2355): an instalment of [invoiceId],
/// dated when it was matched.
({String invoiceId, TaxPointPayment payment}) invoiceInstalmentOf(
  JsonReader row,
) => (
  invoiceId: row.string('invoice_id'),
  payment: TaxPointPayment(
    row.dateTime('matched_at').toLocal(),
    row.integer('amount_cents'),
  ),
);

/// The instalments of [rows] per invoice, in the rows' order.
Map<String, List<TaxPointPayment>> instalmentsByInvoice(
  Iterable<({String invoiceId, TaxPointPayment payment})> rows,
) {
  final out = <String, List<TaxPointPayment>>{};
  for (final row in rows) {
    out.putIfAbsent(row.invoiceId, () => []).add(row.payment);
  }
  return out;
}
