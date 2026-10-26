// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A bank statement as the parsers read it from a file the bank produced:
// the account it is about, and one line per movement with its dates, its
// signed amount (money in is positive, money out negative), the
// counterparty, the structured reference the payer typed (a Swiss QR
// reference or an ISO 11649 `RF` creditor reference), the end-to-end id and
// the free remittance text. Nothing here is trusted: a file is read whole or
// refused with the reason named, never kept in part. Pure Dart.
import 'package:meta/meta.dart';

import '../../../../core/time/date_text.dart';

/// The file formats a statement is read from.
enum BankFileFormat {
  /// ISO 20022 BankToCustomerStatement (end-of-day statement).
  camt053,

  /// ISO 20022 BankToCustomerDebitCreditNotification (intraday advice).
  camt054,

  /// SWIFT MT940 customer statement.
  mt940,

  /// Febelfin CODA (Belgian coded statement of account).
  coda,

  /// Open Financial Exchange (OFX 1.x SGML or 2.x XML, QFX alike).
  ofx,

  /// A spreadsheet export whose columns the person maps.
  csv,
}

/// Why a file is refused. Every refusal names one of these; the screen
/// says it in the person's language.
enum BankFileProblem {
  /// Larger than the import allows.
  tooLarge,

  /// More movements than the import allows.
  tooManyLines,

  /// Not readable as the chosen format (not XML, no statement in it,
  /// a record of the wrong shape).
  malformed,

  /// No account is named: the movements could not be told apart from
  /// another account's.
  missingAccount,

  /// An amount that is not a number of the currency's minor units.
  badAmount,

  /// A date that is not a calendar day.
  badDate,

  /// A currency that is not three letters, or movements in several
  /// currencies on one account statement.
  badCurrency,

  /// No movement at all.
  empty,

  /// An account or a bank id longer than a statement keeps
  /// ([BankColumnWidths]).
  tooLong,
}

/// The widths of the columns a statement and its movements are stored in
/// (`bank_statements`, `bank_statement_lines`, their checks): not a choice,
/// the shape of the store. An identity (the account, a bank id) longer than
/// its column refuses the file; a text is cut; an end-to-end id or an IBAN
/// that does not fit is left out.
abstract final class BankColumnWidths {
  static const int account = 64;
  static const int transactionId = 140;
  static const int statementRef = 140;
  static const int endToEndId = 35;
  static const int counterpartyName = 140;
  static const int remittance = 1000;
  static const int fileName = 255;

  /// An IBAN as stored: up to 34 upper-case letters and digits.
  static final RegExp iban = RegExp(r'^[A-Z0-9]{0,34}$');
}

/// A refused file: the reason, the 1-based line or entry it was found at
/// when there is one, and a technical detail for the trace (never shown as
/// the message).
class BankFileException implements Exception {
  const BankFileException(this.problem, {this.line, this.detail = ''});

  final BankFileProblem problem;
  final int? line;
  final String detail;

  @override
  String toString() =>
      'BankFileException(${problem.name}${line == null ? '' : ' at $line'}'
      '${detail.isEmpty ? '' : ': $detail'})';
}

/// The bounds a file is read under. They come from the settings registry
/// (`bank.import_max_bytes`, `bank.import_max_lines`); the server checks
/// the same line count on its side.
@immutable
class BankFileLimits {
  const BankFileLimits({required this.maxBytes, required this.maxLines});

  final int maxBytes;
  final int maxLines;
}

/// One movement on the account.
@immutable
class BankLine {
  const BankLine({
    required this.position,
    required this.bookingDate,
    required this.valueDate,
    required this.amountCents,
    required this.currency,
    this.transactionId = '',
    this.counterpartyName = '',
    this.counterpartyIban = '',
    this.reference = '',
    this.endToEndId = '',
    this.remittance = '',
  });

  /// 1-based order of the movement in its file.
  final int position;

  /// The day the bank booked it (UTC midnight).
  final DateTime bookingDate;

  /// The day the money is valued (UTC midnight); the booking day when the
  /// file gives none.
  final DateTime valueDate;

  /// Minor units, positive for money in, negative for money out.
  final int amountCents;

  /// ISO 4217, upper case.
  final String currency;

  /// The bank's own identity of the movement (camt `AcctSvcrRef`, MT940
  /// bank reference, CODA bank reference, OFX `FITID`); empty when the file
  /// carries none. Two movements with equal dates, amounts and references
  /// are told apart only by it.
  final String transactionId;

  final String counterpartyName;

  /// Upper case, without spaces.
  final String counterpartyIban;

  /// The structured reference, upper case without spaces: a 27-digit QR
  /// reference or an `RF` creditor reference; empty when the payer gave
  /// none.
  final String reference;

  final String endToEndId;

  /// The unstructured remittance text, lines joined by a space.
  final String remittance;

  /// The line as the import RPC stores it (`import_bank_statement`).
  Map<String, Object?> toJson() => {
    'position': position,
    'booking_date': isoDay(bookingDate),
    'value_date': isoDay(valueDate),
    'amount_cents': amountCents,
    'currency': currency,
    'transaction_id': transactionId,
    'counterparty_name': counterpartyName,
    'counterparty_iban': counterpartyIban,
    'reference': reference,
    'end_to_end_id': endToEndId,
    'remittance': remittance,
  };
}

/// What one file says about one account.
@immutable
class BankStatement {
  const BankStatement({
    required this.format,
    required this.account,
    required this.currency,
    required this.lines,
    this.statementId = '',
    this.openingCents,
    this.closingCents,
  });

  final BankFileFormat format;

  /// The account the file is about: its IBAN (upper case, no spaces) when
  /// the file gives one, otherwise the bank's account number as written.
  final String account;

  /// The account's currency, ISO 4217 upper case.
  final String currency;

  /// The bank's identity of the statement or notification; empty when the
  /// file has none.
  final String statementId;

  /// The booked balance before and after, in minor units, when the file
  /// states them.
  final int? openingCents;
  final int? closingCents;

  final List<BankLine> lines;

  /// The first and last booking day of the movements.
  DateTime get from => lines
      .map((l) => l.bookingDate)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime get to =>
      lines.map((l) => l.bookingDate).reduce((a, b) => a.isAfter(b) ? a : b);
}
