// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Demo report keeps matched and unmatched movements distinct through source, UI and archive.
import 'dart:convert';

import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/bank_reconciliation_fixture.dart';
import 'package:deskilo/core/demo/data/bank_statement_repository.dart';
import 'package:deskilo/features/money/application/bank_import_commands.dart';
import 'package:deskilo/features/money/application/bank_reconciliation_reader.dart';
import 'package:deskilo/features/money/domain/bank/bank_import_settings.dart';
import 'package:deskilo/features/money/domain/bank/bank_statement.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/presentation/bank_reconciliation_archive.dart';
import 'package:deskilo/features/money/providers/bank_statement_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

void main() {
  testWidgets('Demo bank repository reports a retained balanced statement', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, openHub: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final bank = container.read(
      bankStatementRepositoryProvider,
    ) as FakeBankStatementRepository;
    // A synthetic EUR invoice and two consecutive source files: the first
    // closes at 150.00 after a 50.00 receipt; the second opens at 150.00
    // and closes at 140.00 after the named 10.00 movement.
    journey.fixture.money
      ..matchPolicyConfigured = false
      ..invoices.add(
        Invoice(
          id: 'demo-report-invoice',
          workspaceId: 'ws-1',
          memberId: 'demo-report-member',
          number: 'DEMO-REPORT-INVOICE',
          issuedAt: DateTime.utc(2026),
          title: 'Demo',
          lines: const [InvoiceLine(label: 'Demo', amountCents: 5000)],
          totalCents: 5000,
          currency: 'EUR',
          memberName: 'Demo member',
          memberAddress: '',
          workspaceName: 'Demo',
          workspaceAddress: '',
          issuerName: 'Demo',
          signature: 'demo',
        ),
      );
    final xml = demoReconciliationStatementXml.replaceAll(
      'DEMO-REPORT-ACCOUNT',
      'DEMO-TEST-ACCOUNT',
    );
    final first = xml.indexOf('    <Ntry>');
    final second = xml.indexOf('    <Ntry>', first + 1);
    final end = xml.indexOf('  </Stmt>', second);
    final baselineXml = (xml.substring(0, second) + xml.substring(end))
        .replaceFirst('140.00', '150.00')
        .replaceFirst('DEMO-REPORT-202601', 'DEMO-REPORT-BASE');
    final addedXml = (xml.substring(0, first) + xml.substring(second))
        .replaceFirst('100.00', '150.00')
        .replaceFirst('DEMO-REPORT-202601', 'DEMO-REPORT-ADDED');
    const limits = BankFileLimits(maxBytes: 100000, maxLines: 100);
    Future<String> importSource(String source, String fileName) async {
      final outcome = await BankImportCommands(bank).importFile(
        'ws-1',
        bytes: utf8.encode(source),
        fileName: fileName,
        format: BankFileFormat.camt053,
        settings: const BankImportSettings(maxBytes: 100000, maxLines: 100),
      );
      expect(outcome.refused, isNull);
      return outcome.result!.statementId;
    }

    final reader = BankReconciliationReader(bank);
    final baselineId = await importSource(baselineXml, 'baseline.xml');
    final receipt = (await bank.fetchLines(baselineId)).single;
    await bank.matchLine(
      receipt.id,
      invoiceId: 'demo-report-invoice',
      resolution: 'exact',
      note: '',
    );
    final baseline = await reader.read(
      workspaceId: 'ws-1',
      statementId: baselineId,
      sourceLimits: limits,
    );
    expect(baseline.statementDifferenceCents, 0);
    expect(baseline.unresolved, isEmpty);
    final addedId = await importSource(addedXml, 'added.xml');
    final after = await reader.read(
      workspaceId: 'ws-1',
      statementId: addedId,
      sourceLimits: limits,
    );
    expect(after.statementDifferenceCents, 0);
    expect(after.unresolved.single.remittance, 'Named unmatched stationery');

    // A later overlapping file repeats both bank IDs. Without a persisted
    // source-to-canonical association, statuses and arithmetic stay unknown.
    final overlapId = await importSource(xml, 'overlap.xml');
    expect(await bank.fetchLines(overlapId), isEmpty);
    final overlap = await reader.read(
      workspaceId: 'ws-1',
      statementId: overlapId,
      sourceLimits: limits,
    );
    expect(overlap.sourceAssociationUnavailable, isTrue);
    expect(overlap.statementDifferenceCents, isNull);

    // Exercise the real Demo entry into the statement's report quick view.
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    container.read(routerProvider).go('/money/cash');
    await settle();
    await tester.tap(find.byKey(const ValueKey('bank-statements-button')));
    await settle();
    final overlapTile = find.byKey(ValueKey('bank-statement-$addedId'));
    await tester.ensureVisible(overlapTile);
    await tester.tap(overlapTile);
    await settle();
    await tester.tap(find.byKey(const ValueKey('bank-reconciliation-report')));
    await settle();
    await tester.tap(
      find.byKey(const ValueKey('bank-reconciliation-report-quick')),
    );
    await settle();
    expect(find.textContaining('Named unmatched stationery'), findsWidgets);
    expect(find.textContaining('Partial coverage'), findsWidgets);

    // Build the same archive members used by the export, in the Demo scope.
    Map<String, List<int>>? archive;
    final overlay = Overlay.of(tester.element(find.byType(Scaffold).first));
    final entry = OverlayEntry(
      builder: (_) => Consumer(
        builder: (context, ref, _) => Material(
          child: TextButton(
            key: const ValueKey('test-bank-archive'),
            onPressed: () async {
              archive = await BankReconciliationArchive(
                context,
                ref,
              ).build(workspaceId: 'ws-1', year: 2026);
            },
            child: const Text('Build test archive'),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('test-bank-archive')));
    await settle();
    expect(archive, isNotNull);
    expect(archive!.keys.where((key) => key.endsWith('.pdf')), isNotEmpty);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    )!;
    expect(
      utf8.decode(archive!['bank-reconciliation/coverage.txt']!),
      contains(l10n.bankReconCoverage),
    );
    entry.remove();
    await tester.pump();

    expect(
      baseline.lines.first.bookingDate,
      isNot(baseline.lines.first.valueDate),
    );
  });
}
