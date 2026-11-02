// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/bank/bank_records.dart';
import '../domain/bank/bank_statement.dart';
import '../domain/bank/reconciliation_overlap.dart';
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
    return _readSelected(
      workspaceId,
      selected.single,
      sourceLimits,
      statements,
    );
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
          await _readSelected(
            workspaceId,
            statement,
            sourceLimits,
            statements,
            year: year,
          ),
        );
      }
    }
    return reports;
  }

  Future<BankReconciliationReport> _readSelected(
    String workspaceId,
    StoredBankStatement statement,
    BankFileLimits? sourceLimits,
    List<StoredBankStatement> statements, {
    int? year,
  }) async {
    final lines = await repository.fetchLines(statement.id);
    try {
      final verified = await _verify(
        workspaceId,
        statement,
        lines,
        sourceLimits,
        statements,
      );
      final ownIds = {for (final line in lines) line.id};
      return BankReconciliationReport(
        statement: statement,
        lines: verified ?? lines,
        acceptedSourceLinesMatch: verified != null,
        canonicalMovementIds: {
          for (final line in verified ?? <StoredBankLine>[])
            if (!ownIds.contains(line.id)) line.id,
        },
        requestedFrom: year == null ? null : DateTime.utc(year),
        requestedTo: year == null ? null : DateTime.utc(year, 12, 31),
      );
    } on BankOriginalUnavailable {
      return _unavailable(workspaceId, statement.id, year);
    }
  }

  Future<List<StoredBankLine>?> _verify(
    String workspaceId,
    StoredBankStatement statement,
    List<StoredBankLine> lines,
    BankFileLimits? limits,
    List<StoredBankStatement> statements,
  ) async {
    if (limits == null ||
        statement.sourceSha256.isEmpty ||
        statement.format != BankFileFormat.camt053) {
      return null;
    }
    final bytes = await repository.fetchOriginal(
      workspaceId,
      statement.sourceSha256,
    );
    final direct = verifiedBankSourceMovements(
      statement: statement,
      lines: lines,
      original: bytes,
      limits: limits,
    );
    if (direct != null ||
        !bankSourceNeedsCanonicalLookup(
          statement: statement,
          lines: lines,
          original: bytes,
          limits: limits,
        )) {
      return direct;
    }
    final candidates = await _candidates(statement, statements);
    return verifiedBankSourceMovements(
      statement: statement,
      lines: lines,
      original: bytes,
      limits: limits,
      candidates: candidates,
    );
  }

  Future<List<BankCanonicalLine>> _candidates(
    StoredBankStatement statement,
    List<StoredBankStatement> statements,
  ) async {
    final candidates = <BankCanonicalLine>[];
    for (final other in statements) {
      if (other.id == statement.id ||
          other.account != statement.account ||
          other.currency != statement.currency) {
        continue;
      }
      for (final line in await repository.fetchLines(other.id)) {
        candidates.add((
          account: other.account,
          currency: other.currency,
          line: line,
        ));
      }
    }
    return candidates;
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
      requestedFrom: year == null ? null : DateTime.utc(year),
      requestedTo: year == null ? null : DateTime.utc(year, 12, 31),
    );
  }
}
