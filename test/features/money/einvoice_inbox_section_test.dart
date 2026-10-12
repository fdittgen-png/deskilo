// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — the supplier inbox on screen: a document waits for a decision,
// a rejection needs its reason and then shows as rejected.
import 'package:deskilo/core/demo/data/einvoice_inbox_repository.dart';
import 'package:deskilo/features/money/domain/einvoice_inbox.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_inbox_section.dart';
import 'package:deskilo/features/money/providers/einvoice_inbox_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a received document is rejected with a reason', (tester) async {
    final repo = FakeEInvoiceInboxRepository()
      ..documents.add(
        const InboxDocument(
          id: 'd1',
          number: 'F-9',
          issueDate: '2026-09-01',
          currency: 'EUR',
          supplierName: 'ACME',
          grossCents: 12000,
          status: InboxStatus.received,
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [eInvoiceInboxRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: EInvoiceInboxSection(workspaceId: 'ws'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ACME · F-9'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-match-d1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-reject-d1')));
    await tester.pumpAndSettle();
    // No reason: nothing is decided.
    await tester.tap(find.byKey(const ValueKey('inbox-reject-confirm')));
    await tester.pumpAndSettle();
    expect(repo.documents.single.status, InboxStatus.received);

    await tester.tap(find.byKey(const ValueKey('inbox-reject-d1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inbox-reject-reason')),
      'not ours',
    );
    await tester.tap(find.byKey(const ValueKey('inbox-reject-confirm')));
    await tester.pumpAndSettle();
    expect(repo.documents.single.status, InboxStatus.rejected);
    expect(find.byKey(const ValueKey('inbox-match-d1')), findsNothing);
    expect(find.textContaining('not ours'), findsOneWidget);
  });
}
