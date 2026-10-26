// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The one door for the bank statements: reading a file the bank produced
// (refused whole, with its reason, or sent whole), and the person's
// decisions on its movements. The server checks the flag, the rights, the
// line count and every match again; this refuses only what cannot be
// right, before anything is sent.
import 'package:crypto/crypto.dart';

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

/// The widths of the text columns a movement is stored in
/// (`bank_statement_lines`): a longer name or text is cut there, the rest
/// of the movement is kept.
const int _nameWidth = 140;
const int _remittanceWidth = 1000;

BankStatement _fitted(BankStatement s) => BankStatement(
  format: s.format,
  account: s.account,
  currency: s.currency,
  statementId: s.statementId,
  openingCents: s.openingCents,
  closingCents: s.closingCents,
  lines: [
    for (final l in s.lines)
      BankLine(
        position: l.position,
        bookingDate: l.bookingDate,
        valueDate: l.valueDate,
        amountCents: l.amountCents,
        currency: l.currency,
        transactionId: l.transactionId,
        counterpartyName: _cut(l.counterpartyName, _nameWidth),
        counterpartyIban: l.counterpartyIban,
        reference: l.reference,
        endToEndId: l.endToEndId,
        remittance: _cut(l.remittance, _remittanceWidth),
      ),
  ],
);

String _cut(String s, int width) => s.length <= width ? s : s.substring(0, width);

class BankImportCommands {
  const BankImportCommands(this._repository);

  final BankStatementRepository _repository;

  /// Reads [bytes] as [format] under [settings]' bounds and imports the
  /// statement; a file that cannot be read is refused whole and nothing
  /// is sent.
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
      statement = parseBankFile(
        bytes,
        format: format,
        limits: settings.limits,
        csv: csv,
      );
    } on BankFileException catch (e) {
      return (result: null, refused: e);
    }
    final result = await _repository.importStatement(
      workspaceId,
      statement: _fitted(statement),
      sourceSha256: sha256.convert(bytes).toString(),
      fileName: fileName,
    );
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

  /// Confirms every movement whose structured reference names one invoice
  /// for exactly what it still owes, one after the other; answers how many
  /// the server took.
  Future<int> confirmReferenceMatches(
    List<StoredBankLine> lines,
    List<OpenInvoice> open, {
    required int windowDays,
  }) async {
    var confirmed = 0;
    for (final line in lines) {
      final match = referenceMatchOf(line, open, windowDays: windowDays);
      if (match == null) continue;
      await _repository.matchLine(
        line.id,
        invoiceId: match.invoice.id,
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
}
