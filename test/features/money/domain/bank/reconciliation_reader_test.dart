// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Authorized reads preserve source uncertainty and reject refusal instead of fabricating a report.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/application/bank_reconciliation_reader.dart';
import 'package:deskilo/features/money/domain/bank/bank_records.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/bank/reconciliation_report.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Bank implements BankStatementRepository {
  _Bank(this.statements, this.lines);
  final List<StoredBankStatement> statements;
  final List<StoredBankLine> lines;
  String? workspace;
  String? statement;
  bool refuse = false;
  bool refuseLines = false;
  bool unavailableOriginal = false;
  Exception? sourceFailure;
  bool revokeAfterSource = false;
  int originalReads = 0;
  int statementReads = 0;
  @override
  Future<Uint8List> fetchOriginal(
    String workspaceId,
    String sourceSha256,
  ) async {
    originalReads++;
    if (unavailableOriginal) throw const BankOriginalUnavailable();
    if (sourceFailure case final failure?) throw failure;
    throw StateError('source refused');
  }

  @override
  Future<List<StoredBankStatement>> fetchStatements(String workspaceId) async {
    statementReads++;
    workspace = workspaceId;
    if (refuse || (revokeAfterSource && originalReads > 0)) {
      throw StateError('read refused');
    }
    return statements;
  }

  @override
  Future<List<StoredBankLine>> fetchLines(String statementId) async {
    statement = statementId;
    if (refuse || refuseLines) throw StateError('read refused');
    return lines;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final day = DateTime.utc(2026);
  final statement = StoredBankStatement(
    id: 's',
    format: BankFileFormat.csv,
    account: 'account',
    currency: 'EUR',
    from: day,
    to: day,
    lineCount: 0,
    openCount: 0,
  );
  test('reads only a statement returned for the requested workspace', () async {
    final bank = _Bank([statement], []);
    final reader = BankReconciliationReader(bank);
    final report = await reader.read(workspaceId: 'w', statementId: 's');
    expect(report.statement.id, 's');
    expect(report.sourceIssue, BankSourceIssue.csvMapping);
    expect(bank.workspace, 'w');
    expect(bank.statement, 's');
    await expectLater(
      reader.read(workspaceId: 'w', statementId: 'other'),
      throwsStateError,
    );
    expect(bank.statement, 's');
  });
  test(
    'line refusal does not turn the statement into an empty report',
    () async {
      final bank = _Bank([statement], [])..refuseLines = true;
      await expectLater(
        BankReconciliationReader(bank).read(workspaceId: 'w', statementId: 's'),
        throwsStateError,
      );
    },
  );

  test(
    'retained-source refusal is not presented as a complete report',
    () async {
      final sourced = StoredBankStatement(
        id: 'source',
        format: BankFileFormat.camt053,
        account: 'account',
        currency: 'EUR',
        from: day,
        to: day,
        lineCount: 0,
        openCount: 0,
        sourceSha256: 'digest',
      );
      final bank = _Bank([sourced], []);
      await expectLater(
        BankReconciliationReader(bank).read(
          workspaceId: 'w',
          statementId: 'source',
          sourceLimits: const BankFileLimits(maxBytes: 1024, maxLines: 10),
        ),
        throwsStateError,
      );
      expect(bank.originalReads, 1);
    },
  );

  test(
    'ambiguous missing original reauthorizes and remains unavailable',
    () async {
      final sourced = StoredBankStatement(
        id: 'source',
        format: BankFileFormat.camt053,
        account: 'account',
        currency: 'EUR',
        from: day,
        to: day,
        lineCount: 0,
        openCount: 0,
        sourceSha256: 'digest',
      );
      final bank = _Bank([sourced], [])..unavailableOriginal = true;
      final report = await BankReconciliationReader(bank).read(
        workspaceId: 'w',
        statementId: 'source',
        sourceLimits: const BankFileLimits(maxBytes: 1024, maxLines: 10),
      );
      expect(report.sourceUnavailableOrInaccessible, isTrue);
      expect(report.sourceIssue, BankSourceIssue.readUnavailable);
      expect(report.acceptedSourceLinesMatch, isFalse);
      expect(report.statementDifferenceCents, isNull);
      expect(bank.statementReads, 2);
      bank
        ..originalReads = 0
        ..revokeAfterSource = true;
      await expectLater(
        BankReconciliationReader(bank).read(
          workspaceId: 'w',
          statementId: 'source',
          sourceLimits: const BankFileLimits(maxBytes: 1024, maxLines: 10),
        ),
        throwsStateError,
      );
    },
  );

  test(
    'missing original preserves independently read movement and status',
    () async {
      final noOriginal = StoredBankStatement(
        id: 'missing',
        format: BankFileFormat.camt053,
        account: 'account',
        currency: 'EUR',
        from: day,
        to: day,
        lineCount: 1,
        openCount: 1,
      );
      final line = StoredBankLine(
        id: 'row',
        position: 1,
        bookingDate: day,
        valueDate: day,
        amountCents: 250,
        currency: 'EUR',
        status: BankLineStatus.open,
        remittance: 'Named unmatched',
      );
      final bank = _Bank([noOriginal], [line]);
      final result = await BankReconciliationReader(bank).read(
        workspaceId: 'w',
        statementId: 'missing',
        sourceLimits: const BankFileLimits(maxBytes: 1024, maxLines: 10),
      );
      expect(result.sourceIssue, BankSourceIssue.notRetained);
      expect(result.statementDifferenceCents, isNull);
      expect(result.lines.single, same(line));
      expect(result.unresolved.single.remittance, 'Named unmatched');
      expect(bank.originalReads, 0);
    },
  );

  test(
    'storage denial, server failure and network failure propagate',
    () async {
      final sourced = StoredBankStatement(
        id: 'source',
        format: BankFileFormat.camt053,
        account: 'account',
        currency: 'EUR',
        from: day,
        to: day,
        lineCount: 0,
        openCount: 0,
        sourceSha256: 'digest',
      );
      for (final failure in <Exception>[
        const StorageException('denied', statusCode: '403'),
        const StorageException('server failure', statusCode: '500'),
        const SocketException('network unavailable'),
      ]) {
        final bank = _Bank([sourced], [])..sourceFailure = failure;
        await expectLater(
          BankReconciliationReader(bank).read(
            workspaceId: 'w',
            statementId: 'source',
            sourceLimits: const BankFileLimits(maxBytes: 1024, maxLines: 10),
          ),
          throwsA(same(failure)),
        );
        expect(bank.statementReads, 1);
      }
    },
  );

  test('year reads use one authorized listing and retain scope', () async {
    final bank = _Bank([statement], []);
    final reports = await BankReconciliationReader(bank)
        .readYear(workspaceId: 'w', year: 2026);
    expect(reports.single.statement.id, 's');
    expect(reports.single.requestedFrom, DateTime.utc(2026));
    expect(reports.single.requestedTo, DateTime.utc(2026, 12, 31));
    expect(reports.single.statement.from, day);
    expect(reports.single.statement.to, day);
    expect(bank.statementReads, 1);
    expect(bank.workspace, 'w');
    expect(
      await BankReconciliationReader(bank)
          .readYear(workspaceId: 'w', year: 2025),
      isEmpty,
    );
  });

  test('refusal is not converted into an empty report', () async {
    final bank = _Bank([statement], [])..refuse = true;
    await expectLater(
      BankReconciliationReader(bank).read(workspaceId: 'w', statementId: 's'),
      throwsStateError,
    );
  });
}
