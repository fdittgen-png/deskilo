// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/time/business_day.dart';

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
  matchedAt: row.dateTime('matched_at'),
  byName: row.stringOr('by_name'),
  writeoffAt: row.dateTimeOrNull('writeoff_at'),
  // #841 — who released it, reachable from the document.
  eventId: row.stringOrNull('event_id'),
  // #2380 — the reconciled statement line's facts, present only on the
  // accounting source's rows (0641); a calendar day, not an instant.
  valueDate: _day(row.stringOrNull('value_date')),
  bankReference: row.stringOrNull('bank_reference'),
);

DateTime? _day(String? iso) => iso == null ? null : DateTime.parse(iso);

/// One `invoice_match_payments` row (#2355): an instalment of [invoiceId], dated on the CALENDAR of
/// the business ([timezone], its IANA zone) the day it was matched - the tax point is a calendar
/// date, so a payment of the first hours of a day east of UTC is that day's, whichever device reads
/// it (#4322). When the zone is not known the UTC date is read, never the device's.
({String invoiceId, TaxPointPayment payment}) invoiceInstalmentOf(
  JsonReader row, {
  String? timezone,
}) => (
  invoiceId: row.string('invoice_id'),
  payment: TaxPointPayment(
    businessDateOf(row.dateTime('matched_at'), timezone),
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
