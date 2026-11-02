// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/bank/bank_records.dart';
import '../domain/bank/bank_statement.dart';
import '../domain/bank/reconciliation_report.dart';
import '../domain/bank/reconciliation_source.dart';

/// Reads one statement through the same server-authorized bank read paths.
/// These calls do not create a cross-request snapshot. Errors are propagated;
/// neither a refusal nor a missing statement is an empty report.
class BankReconciliationReader {
  const BankReconciliationReader(this.repository);

  final BankStatementRepository repository;

  Future<BankReconciliationReport> read({
    required String workspaceId,
    required String statementId,
    BankFileLimits? sourceLimits,
  }) async {
    final statements = await repository.fetchStatements(workspaceId);
    final selected = statements.where((s) => s.id == statementId).toList();
    if (selected.length != 1) {
      throw StateError('statement unavailable or ambiguous');
    }
    return _readSelected(workspaceId, selected.single, sourceLimits);
  }

  /// Reads each statement overlapping the year from one authorized statement
  /// listing; this is a selection, not evidence of full-year coverage.
  Future<List<BankReconciliationReport>> readYear({
    required String workspaceId,
    required int year,
    BankFileLimits? sourceLimits,
  }) async {
    final statements = await repository.fetchStatements(workspaceId);
    if (statements.map((s) => s.id).toSet().length != statements.length) {
      throw StateError('ambiguous statement list');
    }
    final reports = <BankReconciliationReport>[];
    for (final statement in statements) {
      if (statement.from.year <= year && statement.to.year >= year) {
        reports.add(
          await _readSelected(workspaceId, statement, sourceLimits, year: year),
        );
      }
    }
    return reports;
  }

  Future<BankReconciliationReport> _readSelected(
    String workspaceId,
    StoredBankStatement statement,
    BankFileLimits? sourceLimits, {
    int? year,
  }) async {
    final lines = await repository.fetchLines(statement.id);
    try {
      final verified = await _verify(
        workspaceId,
        statement,
        lines,
        sourceLimits,
      );
      return BankReconciliationReport(
        statement: statement,
        lines: verified.lines ?? lines,
        acceptedSourceLinesMatch:
            verified.lines != null && verified.issue == null,
        sourceAssociationUnavailable:
            verified.unmapped != null && verified.lines == null,
        fileDifferenceCents: verified.difference,
        unmappedSourceCount: verified.unmapped,
        sourceIssue: verified.issue,
        requestedFrom: year == null ? null : DateTime.utc(year),
        requestedTo: year == null ? null : DateTime.utc(year, 12, 31),
      );
    } on BankOriginalUnavailable {
      return _unavailable(workspaceId, statement.id, year);
    }
  }

  Future<
    ({
      List<StoredBankLine>? lines,
      int? difference,
      int? unmapped,
      BankSourceIssue? issue,
    })
  >
  _verify(
    String workspaceId,
    StoredBankStatement statement,
    List<StoredBankLine> lines,
    BankFileLimits? limits,
  ) async {
    if (statement.format == BankFileFormat.csv) {
      return (
        lines: null,
        difference: null,
        unmapped: null,
        issue: BankSourceIssue.csvMapping,
      );
    }
    if (statement.sourceSha256.isEmpty) {
      return (
        lines: null,
        difference: null,
        unmapped: null,
        issue: BankSourceIssue.notRetained,
      );
    }
    if (statement.format != BankFileFormat.camt053 || limits == null) {
      return (
        lines: null,
        difference: null,
        unmapped: null,
        issue: BankSourceIssue.unsupportedFormat,
      );
    }
    final List<int> bytes;
    try {
      bytes = await repository.fetchOriginal(
        workspaceId,
        statement.sourceSha256,
      );
    } on Exception {
      // The storage service may conceal a refusal as absence. Reauthorize
      // the statement and lines before preserving them as an incomplete report.
      throw const BankOriginalUnavailable();
    }
    final analysis = analyzeBankSource(
      statement: statement,
      lines: lines,
      original: bytes,
      limits: limits,
    );
    final direct = verifiedBankSourceMovements(
      statement: statement,
      lines: lines,
      original: bytes,
      limits: limits,
    );
    return (
      lines: direct,
      difference: analysis.difference,
      unmapped: analysis.unmapped,
      issue: analysis.issue,
    );
  }

  Future<BankReconciliationReport> _unavailable(
    String workspaceId,
    String statementId,
    int? year,
  ) async {
    // A 404 may conceal a refusal; re-authorize both reads.
    final statements = await repository.fetchStatements(workspaceId);
    final selected = statements.where((s) => s.id == statementId).toList();
    if (selected.length != 1) {
      throw StateError('statement unavailable or ambiguous');
    }
    final lines = await repository.fetchLines(statementId);
    return BankReconciliationReport(
      statement: selected.single,
      lines: lines,
      sourceUnavailableOrInaccessible: true,
      sourceIssue: BankSourceIssue.readUnavailable,
      requestedFrom: year == null ? null : DateTime.utc(year),
      requestedTo: year == null ? null : DateTime.utc(year, 12, 31),
    );
  }
}
