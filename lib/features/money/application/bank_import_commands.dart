// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one door for the bank statements: reading a file the bank produced
// (refused whole, with its reason, or sent whole), and the person's
// decisions on its movements. The server checks the flag, the rights, the
// line count and every match again; this refuses only what cannot be
// right, before anything is sent.
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/trace/trace_logger.dart';

import '../domain/bank/bank_file.dart';
import '../domain/bank/bank_import_settings.dart';
import '../domain/bank/bank_match.dart';
import '../domain/bank/bank_records.dart';
import '../domain/bank/bank_statement.dart';
import '../domain/bank/csv_statement.dart';

/// What reading and importing one file came to: the server's answer, or
/// the reason the file was refused before anything was sent.
typedef BankImportOutcome = ({
  BankImportResult? result,
  BankFileException? refused,
});

/// [s] as the store keeps it: an account or a bank id that does not fit
/// refuses the file, by name; a name or a text is cut to its column; an
/// end-to-end id or an IBAN that does not fit is left out.
BankStatement _fitted(BankStatement s) {
  BankFileException tooLong(int? line, String what) =>
      BankFileException(BankFileProblem.tooLong, line: line, detail: what);
  if (s.account.trim().length > BankColumnWidths.account) {
    throw tooLong(null, 'account');
  }
  return BankStatement(
    format: s.format,
    account: s.account,
    currency: s.currency,
    statementId: _cut(s.statementId, BankColumnWidths.statementRef),
    openingCents: s.openingCents,
    closingCents: s.closingCents,
    lines: [
      for (final l in s.lines)
        if (l.transactionId.length > BankColumnWidths.transactionId)
          throw tooLong(l.position, 'transaction id')
        else
          BankLine(
            position: l.position,
            bookingDate: l.bookingDate,
            valueDate: l.valueDate,
            amountCents: l.amountCents,
            currency: l.currency,
            transactionId: l.transactionId,
            counterpartyName: _cut(
              l.counterpartyName,
              BankColumnWidths.counterpartyName,
            ),
            counterpartyIban: BankColumnWidths.iban.hasMatch(l.counterpartyIban)
                ? l.counterpartyIban
                : '',
            reference: l.reference,
            endToEndId: l.endToEndId.length > BankColumnWidths.endToEndId
                ? ''
                : l.endToEndId,
            remittance: _cut(l.remittance, BankColumnWidths.remittance),
          ),
    ],
  );
}

String _cut(String s, int width) => s.length <= width ? s : s.substring(0, width);

class BankImportCommands {
  const BankImportCommands(this._repository);

  final BankStatementRepository _repository;

  /// Reads [bytes] as [format] under [settings]' bounds, keeps the file as
  /// the statement's original and imports the statement; a file that
  /// cannot be read is refused whole and nothing is sent.
  Future<BankImportOutcome> importFile(
    String workspaceId, {
    required List<int> bytes,
    required String fileName,
    required BankFileFormat format,
    required BankImportSettings settings,
    BankCsvMapping? csv,
  }) async {
    final BankStatement statement;
    try {
      statement = _fitted(
        parseBankFile(bytes, format: format, limits: settings.limits, csv: csv),
      );
    } on BankFileException catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'bank file refused: $e',
        error: e,
        stackTrace: st,
      );
      return (result: null, refused: e);
    }
    final digest = sha256.convert(bytes).toString();
    final result = await _repository.importStatement(
      workspaceId,
      statement: statement,
      sourceSha256: digest,
      fileName: _cut(fileName, BankColumnWidths.fileName),
    );
    // #2380 — the original after its statement: the server keeps a file only
    // for a statement its uploader imported (0621). A failed upload of a new
    // statement throws; importing the same file again finds it repeated and
    // keeps the file then. A repeated file another member imported is theirs
    // to keep, so its refusal is logged, not reported.
    try {
      await _repository.storeOriginal(
        workspaceId,
        sourceSha256: digest,
        bytes: bytes,
      );
    } catch (e, st) {
      if (!result.repeated) rethrow;
      TraceLogger.instance.warn(
        'money',
        'bank original of a repeated statement not kept: $e',
        error: e,
        stackTrace: st,
      );
    }
    return (result: result, refused: null);
  }

  /// Confirms [line] against [invoiceId] with the resolution its amount
  /// demands against [dueCents]: exact, under (accepted, a note is
  /// required) or over ([overResolution], a forced one needs a note).
  Future<BankLineStatus> confirm(
    StoredBankLine line, {
    required String invoiceId,
    required int dueCents,
    String overResolution = 'over_credit_note',
    String note = '',
  }) => _repository.matchLine(
    line.id,
    invoiceId: invoiceId,
    resolution: line.amountCents == dueCents
        ? 'exact'
        : line.amountCents > dueCents
        ? overResolution
        : 'under_accepted',
    note: note.trim(),
  );

  /// Confirms the movements of [list] whose structured reference names one
  /// invoice for exactly what it still owes, each invoice once
  /// ([BankWorkList.referenceBatch]), one after the other; answers how many
  /// the server took.
  Future<int> confirmReferenceMatches(BankWorkList list) async {
    var confirmed = 0;
    for (final item in list.referenceBatch) {
      await _repository.matchLine(
        item.line.id,
        invoiceId: item.referenceMatch!.invoice.id,
        resolution: 'exact',
        note: '',
      );
      confirmed++;
    }
    return confirmed;
  }

  Future<BankLineStatus> review(StoredBankLine line, {required bool duplicate}) =>
      _repository.reviewLine(line.id, duplicate: duplicate);

  Future<BankLineStatus> reconcileOut(
    StoredBankLine line, {
    required String outgoingPaymentId,
  }) => _repository.reconcileOut(line.id, outgoingPaymentId: outgoingPaymentId);

  /// #2380 — the original file of [statement], as it was imported.
  Future<Uint8List> original(String workspaceId, StoredBankStatement statement) =>
      _repository.fetchOriginal(workspaceId, statement.sourceSha256);
}

/// What a spreadsheet's mapping still lacks, field by field.
enum BankCsvMappingProblem { account, currency, date, amount, duplicateColumn }

/// The problems of a mapping as the person filled it in: an account named
/// in at most [BankColumnWidths.account] characters, a three-letter
/// currency, a date column and an amount column chosen, and no column
/// chosen for two meanings.
Set<BankCsvMappingProblem> bankCsvMappingProblems({
  required String account,
  required String currency,
  required int? dateColumn,
  required int? amountColumn,
  int? currencyColumn,
  List<int?> otherColumns = const [],
}) {
  final chosen = [
    dateColumn,
    amountColumn,
    currencyColumn,
    ...otherColumns,
  ].nonNulls.toList();
  return {
    if (account.trim().isEmpty ||
        account.trim().length > BankColumnWidths.account)
      BankCsvMappingProblem.account,
    if (currencyColumn == null &&
        !RegExp(r'^[A-Za-z]{3}$').hasMatch(currency.trim()))
      BankCsvMappingProblem.currency,
    if (dateColumn == null) BankCsvMappingProblem.date,
    if (amountColumn == null) BankCsvMappingProblem.amount,
    if (chosen.toSet().length < chosen.length)
      BankCsvMappingProblem.duplicateColumn,
  };
}
