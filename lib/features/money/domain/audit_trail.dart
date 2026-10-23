// SPDX-License-Identifier: AGPL-3.0-or-later
/// The **audit trail** (#669): every money event of the period, in the
/// order it happened, with who did it.
///
/// CALLED A TRAIL, NEVER AN "AUDIT FILE", and the distinction is the
/// whole reason this file can exist. A national audit file — SAF-T(PT)
/// accounting, FAIA, JPK_KR, D406 — is a regulated artefact with a
/// published schema, a validator and a conformance claim. This is not
/// one and does not pretend to be. It is the evidence *behind* the
/// numbers: the thing an accountant or an inspector actually asks for
/// first, before any schema comes up.
///
/// WHAT MAKES IT A TRAIL RATHER THAN A REPORT. Three properties, and
/// losing any one of them makes it worthless for the job:
///
///  1. **Nothing is filtered.** Voided invoices, pending settlements,
///     write-offs and credit notes are all here. An export that showed
///     only the tidy rows would answer "what do you say happened",
///     which is the one question an audit is not asking.
///  2. **Every row names its actor.** "Who voided this invoice" is the
///     first question about a voided invoice, and a trail that cannot
///     answer it sends someone into the database by hand.
///  3. **Reversals sit next to what they reverse.** A credit note whose
///     `relates_to` is empty is just another document; with it, the
///     pair reads as one correction.
///
/// One flat CSV rather than a bundle of files: it gets opened in a
/// spreadsheet, sorted by date, and read. A zip of six sheets is worse
/// at exactly that.
library;

import '../../../core/money/money_text.dart';
import '../../../core/text/csv.dart';
import 'accounting_source_snapshot.dart';
import 'invoice.dart';
import 'ledger_entry.dart';

/// One row of the trail, already flattened. Keeping this as an explicit
/// type rather than a tuple is what lets the sort below be about the
/// EVENT time — an invoice's issue date and a payment's booking date are
/// different fields on different objects, and mixing them up puts a
/// settlement before the invoice it settles.
class AuditEvent {
  const AuditEvent({
    required this.at,
    required this.kind,
    required this.reference,
    required this.description,
    required this.amountCents,
    this.actor = '',
    this.counterparty = '',
    this.relatesTo = '',
    this.status = '',
  });

  /// When the event HAPPENED, not when it was recorded. A payment
  /// booked on the day the money moved (0070) belongs on that day, or
  /// the trail disagrees with the bank statement beside it.
  final DateTime at;

  /// 'invoice', 'void', 'payment', 'credit', 'writeoff'.
  final String kind;

  /// The document number — how a row ties back to something physical.
  final String reference;
  final String description;

  /// Signed. A credit and a write-off REDUCE what is owed, and showing
  /// them positive would let a column sum look like revenue.
  final int amountCents;

  /// Who did it. Empty when the system did it on its own, which is
  /// itself an answer.
  final String actor;
  final String counterparty;

  /// The document this one corrects, if any.
  final String relatesTo;
  final String status;
}

const _columns = [
  'happened_on',
  'kind',
  'reference',
  'relates_to',
  'description',
  'amount',
  'counterparty',
  'actor',
  'status',
];

/// Flattens invoices, settlements and ledger movements into one ordered
/// trail.
List<AuditEvent> buildAuditEvents({
  required List<Invoice> invoices,
  required Map<String, InvoiceMatch> matches,
  List<LedgerEntry> ledger = const [],
}) {
  final events = <AuditEvent>[];

  for (final invoice in invoices) {
    // #2365 — a credit note charges nothing (`chargesCents` is the
    // positive positions): its value is its signed total, or the trail
    // shows a correction of zero.
    final worth = invoice.isCreditNote ? invoice.totalCents : invoice.chargesCents;
    events.add(AuditEvent(
      at: invoice.issuedAt,
      kind: 'invoice',
      reference: invoice.number,
      relatesTo: invoice.replacesNumber,
      description: invoice.title,
      amountCents: worth,
      actor: invoice.issuerName,
      counterparty: invoice.memberName,
      status: invoice.isVoided ? 'voided' : 'issued',
    ));

    // The void is its OWN event, on its own date. Folding it into the
    // invoice row would put a cancellation on the issue date and lose
    // the gap between the two, which is the interesting part.
    if (invoice.voidedAt case final voidedAt?) {
      events.add(AuditEvent(
        at: voidedAt,
        kind: 'void',
        reference: invoice.number,
        relatesTo: invoice.number,
        description: 'Voided',
        // Negative: it takes back exactly what the invoice charged.
        amountCents: -worth,
        actor: invoice.voidedByName,
        counterparty: invoice.memberName,
        status: 'voided',
      ));
    }

    if (matches[invoice.id] case final match?) {
      events.add(AuditEvent(
        at: match.matchedAt,
        kind: 'payment',
        reference: invoice.number,
        relatesTo: invoice.number,
        description: match.note.isEmpty ? 'Payment' : match.note,
        amountCents: match.paidCents,
        actor: match.byName,
        counterparty: invoice.memberName,
        // Pending settlements are IN the trail — see the header. A
        // mapped journal must exclude them; a trail that hid them would
        // show an invoice as unpaid while someone is mid-validation.
        status: match.status,
      ));
      // #2365 — the write-off is its own event, on its own date: what was
      // still owed when the owner gave it up. Negative, like a credit.
      if (match.writeoffAt case final writtenOffAt?) {
        final owed = invoice.totalCents - match.paidCents;
        events.add(AuditEvent(
          at: writtenOffAt,
          kind: 'writeoff',
          reference: invoice.number,
          relatesTo: invoice.number,
          description: 'Written off',
          amountCents: owed > 0 ? -owed : 0,
          actor: match.byName,
          counterparty: invoice.memberName,
          status: match.status,
        ));
      }
    }
  }

  for (final entry in ledger) {
    events.add(AuditEvent(
      // `on` is what HAPPENED (0070): a transfer made on the 3rd and
      // recorded on the 26th belongs on the 3rd, or the trail disagrees
      // with the bank statement it will be read beside.
      at: entry.on,
      kind: entry.category.name,
      reference: entry.id,
      description: entry.description,
      // The sign already carries the direction: a credit reduces what
      // is owed. Re-deriving it from `kind` here would be a second
      // opinion about something the ledger already decided.
      amountCents: entry.amountCents,
      counterparty: entry.memberId,
      status: entry.kind.name,
    ));
  }

  // Chronological. A trail out of order is a list.
  events.sort((a, b) => a.at.compareTo(b.at));
  return events;
}

/// [source] — the revisions of the settings, tax reference, book profile and
/// calendar the one fiscal source was read with (#2564): when given, the
/// trail states which version of each it was made with.
String buildAuditTrailCsv({
  required List<AuditEvent> events,
  required DateTime generatedAt,
  required String workspaceName,
  AccountingSourceRevisions? source,
}) {

  final buffer = StringBuffer()
    ..writeln('# DesKilo audit trail — $workspaceName')
    ..writeln('# generated ${generatedAt.toIso8601String()}')
    ..writeln('# ${events.length} event(s), oldest first');
  if (source != null) {
    buffer.writeln('# made with: settings ${source.settings}; '
        'tax reference ${source.taxReference}; '
        'book profile ${source.bookProfile}; calendar ${source.calendar}');
  }
  buffer
    // The disclaimer is not boilerplate: someone will be handed this
    // file in an audit, and they must not present it as a national
    // audit file.
    ..writeln('# This is the evidence behind the numbers, not a '
        'regulated audit file. Nothing is filtered: voided documents, '
        'pending settlements and reversals are all included.')
    ..writeln(_columns.join(','));

  for (final event in events) {
    buffer.writeln([
      event.at.toIso8601String().split('T').first,
      event.kind,
      // #2385 — the shared cell writer: quotes doubled, line breaks and
      // other control characters a space, formula starts defused.
      csvCell(event.reference),
      csvCell(event.relatesTo),
      csvCell(event.description),
      // The trail has no currency column: two decimals, as since #669.
      minorToText(event.amountCents, 'EUR'),
      csvCell(event.counterparty),
      csvCell(event.actor),
      csvCell(event.status),
    ].join(','));
  }
  return buffer.toString();
}
