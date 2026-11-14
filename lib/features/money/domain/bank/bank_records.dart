// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bank statements as the server keeps them (`bank_statements`,
// `bank_statement_lines`): what was imported, and where each movement
// stands. A movement's status is the server's answer, never derived here:
// open (to match), review (it resembles a movement of another statement and
// a person decides), duplicate, recorded (its payment exists and settles no
// invoice yet), pending (its match awaits the validators), matched, or
// reconciled (money out, with the payment reported as made). Pure Dart.
import 'dart:typed_data';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

import 'bank_statement.dart';

/// The private original could not be found or accessed. Storage intentionally
/// does not distinguish a missing object from a concealed permission refusal.
class BankOriginalUnavailable implements Exception {
  const BankOriginalUnavailable();
}

/// The permissions that read the bank statements (bank_statement_reader;
/// the owner always does).
const Set<String> bankStatementReaders = {'viewFinances', 'issueInvoices'};

/// The permission that imports and matches money in, and the one that
/// reconciles money out with a payment reported as made.
const String bankMatchPermission = 'issueInvoices';
const String bankReconcilePermission = 'recordOutgoingPayments';

/// #3913 — the lists a bank read leaves rows out of, counted per list
/// (`UnreadableRows`): a statement's lines, and a workspace's statements.
String bankLinesArea(String statementId) => 'bank_lines:$statementId';
String bankStatementsArea(String workspaceId) =>
    'bank_statements:$workspaceId';

/// #3913 — a report refused because the statement, or a movement of it, is
/// one this build could not read: a report never leaves a movement out.
class BankRowsUnreadable implements Exception {
  const BankRowsUnreadable();

  @override
  String toString() => 'BankRowsUnreadable';
}

/// Where one movement stands.
enum BankLineStatus {
  open,
  review,
  duplicate,
  recorded,
  pending,
  matched,
  reconciled;

  /// The status [wire] names; null for one this build does not know
  /// (#3913): its row is left out of a list and counted, never read as a
  /// status it is not.
  static BankLineStatus? fromWire(String? wire) =>
      values.where((s) => s.name == wire).firstOrNull;

  /// Still waiting for a person: to match, to review, or a payment that
  /// settles nothing yet.
  bool get isOpen => this == open || this == review || this == recorded;
}

/// A payment reported as made that a movement out may reconcile: same
/// amount, same currency, still only reported.
@immutable
class OutgoingCandidate {
  const OutgoingCandidate({
    required this.id,
    required this.amountCents,
    required this.paidOn,
    required this.reference,
    required this.payee,
  });

  factory OutgoingCandidate.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    return OutgoingCandidate(
      id: r.string('id'),
      amountCents: r.integer('amount_cents'),
      paidOn: _day(r, 'paid_on'),
      reference: r.stringOr('reference'),
      payee: r.stringOr('payee'),
    );
  }

  final String id;
  final int amountCents;
  final DateTime paidOn;
  final String reference;
  final String payee;
}

/// One imported movement.
@immutable
class StoredBankLine {
  const StoredBankLine({
    required this.id,
    required this.position,
    required this.bookingDate,
    required this.valueDate,
    required this.amountCents,
    required this.currency,
    required this.status,
    this.transactionId = '',
    this.counterpartyName = '',
    this.counterpartyIban = '',
    this.reference = '',
    this.endToEndId = '',
    this.remittance = '',
    this.invoiceId,
    this.invoiceNumber,
    this.outgoingCandidates = const [],
  });

  /// A row of `bank_statement_lines_v1`; null when its status is one this
  /// build does not know (#3913).
  static StoredBankLine? fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    final status = BankLineStatus.fromWire(r.stringOrNull('status'));
    if (status == null) return null;
    return StoredBankLine(
      id: r.string('id'),
      position: r.integer('position'),
      bookingDate: _day(r, 'booking_date'),
      valueDate: _day(r, 'value_date'),
      amountCents: r.integer('amount_cents'),
      currency: r.string('currency'),
      status: status,
      transactionId: r.stringOr('transaction_id'),
      counterpartyName: r.stringOr('counterparty_name'),
      counterpartyIban: r.stringOr('counterparty_iban'),
      reference: r.stringOr('reference'),
      endToEndId: r.stringOr('end_to_end_id'),
      remittance: r.stringOr('remittance'),
      invoiceId: r.stringOrNull('invoice_id'),
      invoiceNumber: r.stringOrNull('invoice_number'),
      outgoingCandidates: [
        for (final c in r.list('outgoing_candidates'))
          OutgoingCandidate.fromJson(c),
      ],
    );
  }

  final String id;
  final int position;
  final DateTime bookingDate;
  final DateTime valueDate;

  /// Minor units: positive money in, negative money out.
  final int amountCents;
  final String currency;
  final BankLineStatus status;
  final String transactionId;
  final String counterpartyName;
  final String counterpartyIban;
  final String reference;
  final String endToEndId;
  final String remittance;

  /// The invoice the movement was confirmed against (kept when the
  /// validators rejected the match: the payment stays recorded).
  final String? invoiceId;
  final String? invoiceNumber;
  final List<OutgoingCandidate> outgoingCandidates;

  bool get isMoneyIn => amountCents > 0;
}

/// One imported file.
@immutable
class StoredBankStatement {
  const StoredBankStatement({
    required this.id,
    required this.format,
    required this.account,
    required this.currency,
    required this.from,
    required this.to,
    required this.lineCount,
    required this.openCount,
    this.statementRef = '',
    this.fileName = '',
    this.sourceSha256 = '',
    this.openingCents,
    this.closingCents,
  });

  /// A row of `bank_statements_v1`; null when its file format is one this
  /// build does not know (#3913).
  static StoredBankStatement? fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    final format = r.string('format');
    final known = BankFileFormat.values.where((f) => f.name == format);
    if (known.isEmpty) return null;
    return StoredBankStatement(
      id: r.string('id'),
      format: known.first,
      account: r.string('account'),
      currency: r.string('currency'),
      from: _day(r, 'period_from'),
      to: _day(r, 'period_to'),
      lineCount: r.integer('lines'),
      openCount: r.integer('open'),
      statementRef: r.stringOr('statement_ref'),
      fileName: r.stringOr('file_name'),
      sourceSha256: r.stringOr('source_sha256'),
      openingCents: r.intOrNull('opening_cents'),
      closingCents: r.intOrNull('closing_cents'),
    );
  }

  final String id;
  final BankFileFormat format;
  final String account;
  final String currency;
  final DateTime from;
  final DateTime to;
  final int lineCount;

  /// Movements still waiting for a person.
  final int openCount;
  final String statementRef;
  final String fileName;

  /// #2380 — the digest of the file it was read from, which names the
  /// original kept beside it; empty from a server before 0621.
  final String sourceSha256;
  final int? openingCents;
  final int? closingCents;
}

/// What an import did: the statement, whether the very same file had been
/// imported before (then nothing was added), and the movements created,
/// already known by their bank id, and kept for a review.
@immutable
class BankImportResult {
  const BankImportResult({
    required this.statementId,
    required this.repeated,
    required this.created,
    required this.known,
    required this.review,
  });

  factory BankImportResult.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    return BankImportResult(
      statementId: r.string('statement_id'),
      repeated: r.boolOr('repeated', fallback: false),
      created: r.integer('created'),
      known: r.integer('known'),
      review: r.integer('review'),
    );
  }

  final String statementId;
  final bool repeated;
  final int created;
  final int known;
  final int review;
}

/// The statements of a space, the movements of one, and the person's
/// decisions on them. The server checks the flag and every right.
abstract interface class BankStatementRepository {
  Future<List<StoredBankStatement>> fetchStatements(String workspaceId);

  Future<List<StoredBankLine>> fetchLines(String statementId);

  /// #2380 — keeps the file's [bytes] as the original of the statement
  /// read from it, under its digest [sourceSha256]. Keeping the same file
  /// again is not an error: the bytes are the same.
  Future<void> storeOriginal(
    String workspaceId, {
    required String sourceSha256,
    required List<int> bytes,
  });

  /// #2380 — the original file of a statement, as it was imported.
  Future<Uint8List> fetchOriginal(String workspaceId, String sourceSha256);

  /// Imports [statement] read from a file whose bytes digest to
  /// [sourceSha256]; the same digest imports nothing a second time.
  Future<BankImportResult> importStatement(
    String workspaceId, {
    required BankStatement statement,
    required String sourceSha256,
    required String fileName,
  });

  /// The writes below answer the line's status after them; null when the
  /// write was done but its status is one this build does not know (#3913):
  /// the write is not refused, and the list is read again.
  ///
  /// Confirms money in against [invoiceId] with the resolution its amount
  /// demands (`exact`, `over_credit_note`, `over_forced`, `under_accepted`).
  Future<BankLineStatus?> matchLine(
    String lineId, {
    required String invoiceId,
    required String resolution,
    required String note,
  });

  /// A movement that resembled another statement's: a duplicate, or a
  /// second genuine movement.
  Future<BankLineStatus?> reviewLine(String lineId, {required bool duplicate});

  /// Money out confirmed against a payment reported as made.
  Future<BankLineStatus?> reconcileOut(
    String lineId, {
    required String outgoingPaymentId,
  });

  /// Undoes the reconciliation of money out, once, for [reason]: the
  /// movement is open again and its payment reported again; the undoing is
  /// kept on record. The same [requestId] again changes nothing.
  Future<BankLineStatus?> unreconcileOut(
    String lineId, {
    required String reason,
    required String requestId,
  });

  /// Undoes the match of money in to an invoice, once, for [reason] (0650):
  /// the invoice is open again, the movement keeps its payment and reads
  /// [BankLineStatus.recorded], and the undoing is kept on record. Only the
  /// exact, single-payment, open-period match is undone: the server refuses
  /// the others with a known code. The same [requestId] again changes
  /// nothing.
  Future<BankLineStatus?> unmatchIn(
    String lineId, {
    required String reason,
    required String requestId,
  });
}

/// A calendar day of the wire (`YYYY-MM-DD`) at UTC midnight.
DateTime _day(JsonReader r, String key) {
  final d = r.dateTime(key);
  return DateTime.utc(d.year, d.month, d.day);
}
