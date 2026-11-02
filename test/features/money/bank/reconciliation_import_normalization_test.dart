// SPDX-License-Identifier: AGPL-3.0-or-later
// A retained source is compared using the same fitting rules as bank import.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/bank_import_commands.dart';
import 'package:deskilo/features/money/application/bank_reconciliation_reader.dart';
import 'package:deskilo/features/money/domain/bank/bank_import_settings.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'actual import fitting and source verification agree on long fields',
    () async {
      final original = File(
        'test/features/money/fixtures/bank/camt053_statement.xml',
      ).readAsStringSync();
      final pendingStart = original.lastIndexOf('      <Ntry>');
      final pendingEnd =
          original.indexOf('      </Ntry>', pendingStart) +
          '      </Ntry>'.length;
      final xml = original
          .replaceRange(pendingStart, pendingEnd, '')
          .replaceFirst('STMT-2026-01', 'S' * 150)
          .replaceFirst('Demo Member One', 'N' * 160)
          .replaceFirst('E2E-0001', 'E' * 160)
          .replaceFirst('CH5604835012345678009', 'CH${'1' * 40}')
          .replaceFirst('Invoice 2026-0042', 'R' * 1200);
      final bank = FakeBankStatementRepository(
        money: FakeMoneyRepository(),
        today: DateTime.utc(2026),
      );
      const settings = BankImportSettings(maxBytes: 100000, maxLines: 100);
      final outcome = await BankImportCommands(bank).importFile(
        'ws-1',
        bytes: utf8.encode(xml),
        fileName: 'synthetic.xml',
        format: BankFileFormat.camt053,
        settings: settings,
      );
      expect(outcome.refused, isNull);
      final result = await BankReconciliationReader(bank).read(
        workspaceId: 'ws-1',
        statementId: outcome.result!.statementId,
        sourceLimits: settings.limits,
      );
      expect(result.acceptedSourceLinesMatch, isTrue);
      expect(result.statementDifferenceCents, 0);
      expect(
        result.statement.statementRef.length,
        BankColumnWidths.statementRef,
      );
      expect(
        result.lines.first.counterpartyName.length,
        BankColumnWidths.counterpartyName,
      );
      expect(result.lines.first.counterpartyIban, isEmpty);
      expect(result.lines.first.endToEndId, isEmpty);
      expect(result.lines.first.remittance.length, BankColumnWidths.remittance);
    },
  );
}
