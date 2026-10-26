// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bank statements as the server keeps them (`bank_statements`,
// `bank_statement_lines`): what was imported, and where each movement
// stands. A movement's status is the server's answer, never derived here:
// open (to match), review (it resembles a movement of another statement and
// a person decides), duplicate, recorded (its payment exists and settles no
// invoice yet), pending (its match awaits the validators), matched, or
// reconciled (money out, with the payment reported as made). Pure Dart.
import 'package:meta/meta.dart';

import '../../../../core/data/json_reader.dart';
import 'bank_statement.dart';

/// Where one movement stands.
enum BankLineStatus {
  open,
  review,
  duplicate,
  recorded,
  pending,
  matched,
  reconciled;

  static BankLineStatus fromWire(String? wire) => values.firstWhere(
    (s) => s.name == wire,
    orElse: () => throw FormatException('unknown bank line status $wire'),
  );

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

  factory StoredBankLine.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    return StoredBankLine(
      id: r.string('id'),
      position: r.integer('position'),
      bookingDate: _day(r, 'booking_date'),
      valueDate: _day(r, 'value_date'),
      amountCents: r.integer('amount_cents'),
      currency: r.string('currency'),
      status: BankLineStatus.fromWire(r.string('status')),
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
    this.openingCents,
    this.closingCents,
  });

  factory StoredBankStatement.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bank');
    final format = r.string('format');
    return StoredBankStatement(
      id: r.string('id'),
      format: BankFileFormat.values.firstWhere(
        (f) => f.name == format,
        orElse: () => throw FormatException('unknown bank file format $format'),
      ),
      account: r.string('account'),
      currency: r.string('currency'),
      from: _day(r, 'period_from'),
      to: _day(r, 'period_to'),
      lineCount: r.integer('lines'),
      openCount: r.integer('open'),
      statementRef: r.stringOr('statement_ref'),
      fileName: r.stringOr('file_name'),
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

  /// Imports [statement] read from a file whose bytes digest to
  /// [sourceSha256]; the same digest imports nothing a second time.
  Future<BankImportResult> importStatement(
    String workspaceId, {
    required BankStatement statement,
    required String sourceSha256,
    required String fileName,
  });

  /// Confirms money in against [invoiceId] with the resolution its amount
  /// demands (`exact`, `over_credit_note`, `over_forced`, `under_accepted`).
  Future<BankLineStatus> matchLine(
    String lineId, {
    required String invoiceId,
    required String resolution,
    required String note,
  });

  /// A movement that resembled another statement's: a duplicate, or a
  /// second genuine movement.
  Future<BankLineStatus> reviewLine(String lineId, {required bool duplicate});

  /// Money out confirmed against a payment reported as made.
  Future<BankLineStatus> reconcileOut(
    String lineId, {
    required String outgoingPaymentId,
  });
}

/// A calendar day of the wire (`YYYY-MM-DD`) at UTC midnight.
DateTime _day(JsonReader r, String key) {
  final d = r.dateTime(key);
  return DateTime.utc(d.year, d.month, d.day);
}
