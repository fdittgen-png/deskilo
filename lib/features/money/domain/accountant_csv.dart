// SPDX-License-Identifier: 0BSD
import 'billing_rules.dart';
import 'invoice.dart';

/// A plain, self-describing CSV of the period's invoices and settlements
/// (#669) — for the ten supported countries that mandate no particular
/// file, and for any accountant who would rather read one than import
/// one.
///
/// **Honest by construction.** DesKilo defines this format, so it claims
/// nothing: no authority recognises it, no importer expects a fixed
/// column order, and nothing here has to be true to a spec written
/// somewhere else. That is why it can carry the one thing the national
/// formats cannot — the invoice's own numbers, unmapped, with no chart
/// of accounts invented to hold them.
///
/// It is a companion to the mapped exports rather than a lesser version
/// of them. DATEV and Sage answer "post this"; this answers "show me
/// what you charged and what you were paid", which is the question an
/// accountant actually opens with.
///
/// Every column is named in full and the amounts are decimal with a
/// point — this file is read by a human and by a spreadsheet, and both
/// are forgiving of length and unforgiving of ambiguity.

const _columns = [
  'invoice_number',
  'issued_on',
  'period',
  'customer',
  'customer_id',
  'title',
  'currency',
  'net',
  'vat',
  'gross',
  'vat_rates',
  'status',
  'voided_on',
  'voided_by',
  'replaces',
  'paid',
  'paid_on',
  'payment_status',
  'payment_note',
];

/// Builds the CSV. [generatedAt] and the period bounds go in a `#`
/// preamble so the file says what it is when it turns up in an e-mail
/// three months later with no message attached.
String buildAccountantCsv({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  required DateTime generatedAt,
  required String workspaceName,
  String currencyFallback = 'EUR',
}) {
  String q(String? value) {
    if (value == null || value.isEmpty) return '';
    return '"${value.replaceAll('"', '""').replaceAll(RegExp(r'[\r\n]+'), ' ')}"';
  }

  String money(int cents) => (cents / 100).toStringAsFixed(2);
  String day(DateTime? d) =>
      d == null ? '' : d.toIso8601String().split('T').first;

  // Oldest first: a ledger reads like a journal, and an accountant
  // scanning for a date wants them in order.
  final ordered = [...invoices]
    ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));

  final buffer = StringBuffer()
    ..writeln('# DesKilo accounting export — $workspaceName')
    ..writeln('# generated ${generatedAt.toIso8601String()}')
    ..writeln('# ${ordered.length} invoice(s); amounts in the '
        'invoice currency, VAT-exclusive net and tax shown separately')
    // Said plainly, because the honesty of this file is its whole value:
    // an accountant must not mistake it for a mapped journal.
    ..writeln('# NOT a journal: no account numbers, no double entry. '
        'These are the documents as issued.')
    ..writeln(_columns.join(','));

  for (final invoice in ordered) {
    final match = matches[invoice.id];
    // Voided invoices STAY in the file. They happened, they carry a
    // number that will otherwise look like a gap in the sequence, and a
    // gap is the first thing an inspector asks about. Their value is
    // shown as issued and their voided_on says what became of them.
    // #831 — a settlement regroups invoices already on this list.
    if (invoice.kind == InvoiceKind.settlement) continue;
    buffer.writeln([
      q(invoice.number),
      day(invoice.issuedAt),
      q(invoice.period),
      q(invoice.memberName),
      q(invoice.memberId),
      q(invoice.title),
      q(invoice.currency.isEmpty ? currencyFallback : invoice.currency),
      money(invoice.netCents),
      money(invoice.vatCents),
      money(invoice.chargesCents),
      // Which rates, so a reader can see at a glance that a period mixes
      // them — the single most common surprise in a coworking ledger.
      q([
        for (final total in invoice.vatTotals)
          '${total.percent.toStringAsFixed(2)}%',
      ].join(' ')),
      invoice.isVoided ? 'voided' : 'issued',
      day(invoice.voidedAt),
      q(invoice.voidedByName),
      q(invoice.replacesNumber),
      match == null ? '' : money(match.paidCents),
      match == null ? '' : day(match.matchedAt),
      // The pending/confirmed distinction is exported rather than
      // filtered. The mapped formats drop pending settlements because
      // posting them would put unagreed money in a ledger; here there is
      // no ledger to protect, and hiding them would leave an invoice
      // looking unpaid when someone is mid-validation on it.
      q(match?.status),
      q(match?.note),
    ].join(','));
  }
  return buffer.toString();
}
