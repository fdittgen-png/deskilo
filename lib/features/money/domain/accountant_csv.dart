// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/i18n/currencies.dart';
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

/// #1640 — bumped when a column, the encoding or the text policy
/// changes; the handoff report quotes it.
const int accountantCsvFormatVersion = 2;

/// #1640 — the longest text a cell carries; longer is cut with an
/// ellipsis, so a pasted essay cannot turn one row into a page.
const int accountantCsvMaxText = 1000;

/// #1640 — the spreadsheet-safe text policy (OWASP "CSV injection").
///
/// Quoting alone does not stop a spreadsheet from evaluating `=…`, so a
/// TEXT cell whose first character could start a formula (`=`, `+`, `-`,
/// `@`) gets a leading apostrophe, which every major spreadsheet reads as
/// "this is text". Control characters (tabs, carriage returns, line
/// feeds, the rest of C0 and DEL) become a space first, so none of them
/// can open a cell either. Numbers never pass through here: a credit
/// note's `-12.00` stays a number. The stored value is untouched; only
/// this export's text changes.
String accountantCsvText(String? value) {
  if (value == null || value.isEmpty) return '';
  var text = value.replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), ' ');
  if (text.length > accountantCsvMaxText) {
    text = '${text.substring(0, accountantCsvMaxText - 1)}…';
  }
  if (RegExp(r'^[=+\-@]').hasMatch(text)) text = "'$text";
  return '"${text.replaceAll('"', '""')}"';
}

/// #1640 — a preamble line is ONE cell starting with `#`: nothing in the
/// workspace name may end it (a delimiter, a quote, a line break) and so
/// open a second cell that a spreadsheet would evaluate.
String _inertPreamble(String value) =>
    value.replaceAll(RegExp(r'[\x00-\x1F\x7F,;"]+'), ' ').trim();

/// The columns, in order — the handoff report quotes them.
const List<String> accountantCsvColumns = _columns;

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
  const q = accountantCsvText;

  // #1077 — the document's own currency decides the grain.
  String money(int minor, String code) => Currencies.toMajor(minor, code)
      .toStringAsFixed(Currencies.minorDigits(code));
  String day(DateTime? d) =>
      d == null ? '' : d.toIso8601String().split('T').first;

  // Oldest first: a ledger reads like a journal, and an accountant
  // scanning for a date wants them in order.
  // #1640 — ties broken by number, so two runs over the same documents
  // write the same bytes.
  final ordered = [...invoices]
    ..sort((a, b) {
      final byDate = a.issuedAt.compareTo(b.issuedAt);
      return byDate != 0 ? byDate : a.number.compareTo(b.number);
    });
  final rows = ordered.where((i) => i.kind != InvoiceKind.settlement);

  final buffer = StringBuffer()
    ..writeln('# DesKilo accounting export — ${_inertPreamble(workspaceName)}')
    ..writeln('# generated ${generatedAt.toIso8601String()}')
    // #1640 — the rows actually written, not the documents loaded.
    ..writeln('# ${rows.length} invoice(s); amounts in the '
        'invoice currency, VAT-exclusive net and tax shown separately')
    // Said plainly, because the honesty of this file is its whole value:
    // an accountant must not mistake it for a mapped journal.
    ..writeln('# NOT a journal: no account numbers, no double entry. '
        'These are the documents as issued.')
    ..writeln(_columns.join(','));

  for (final invoice in rows) {
    final match = matches[invoice.id];
    // Voided invoices STAY in the file. They happened, they carry a
    // number that will otherwise look like a gap in the sequence, and a
    // gap is the first thing an inspector asks about. Their value is
    // shown as issued and their voided_on says what became of them.
    // #831 — a settlement regroups invoices already on this list, so
    // [rows] leaves it out.
    buffer.writeln([
      q(invoice.number),
      day(invoice.issuedAt),
      q(invoice.period),
      q(invoice.memberName),
      q(invoice.memberId),
      q(invoice.title),
      q(invoice.currency.isEmpty ? currencyFallback : invoice.currency),
      money(invoice.netCents, invoice.currency),
      money(invoice.vatCents, invoice.currency),
      money(invoice.chargesCents, invoice.currency),
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
      match == null ? '' : money(match.paidCents, invoice.currency),
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
