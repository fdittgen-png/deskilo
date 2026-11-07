// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 — the card that says whether the accounting connectors admit new work
// and offers the moves: hidden from whoever may not manage the connectors; a
// manager stops and resumes new work; only the owner retires or reopens, each
// with a reason (a missing one is refused under its field); retiring is
// refused in words while a delivery is still in progress, and works once it is
// settled. The Demo repository applies the contract's rules like the server.
import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/presentation/widgets/accounting_capability_card.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 11, 6, 9);

FakeAccountingConnectionRepository _repo() =>
    FakeAccountingConnectionRepository(
      books: FakeBookPeriodRepository(today: _today),
      today: _today,
    );

Future<void> _pump(
  WidgetTester tester,
  FakeAccountingConnectionRepository repo, {
  bool manage = true,
  bool owner = false,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountingConnectionRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CapabilityStateCard(
            workspaceId: 'ws-1',
            manage: manage,
            owner: owner,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

String _chip(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('acct-state-chip'))).data!;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('hidden from someone who may not manage the connectors', (
    tester,
  ) async {
    await _pump(tester, _repo(), manage: false);
    expect(find.byKey(const ValueKey('acct-state-card')), findsNothing);
  });

  testWidgets('a manager sees the state and may stop new work, not retire', (
    tester,
  ) async {
    await _pump(tester, _repo());
    expect(_chip(tester), startsWith('Active'));
    expect(find.byKey(const ValueKey('acct-state-derived')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('acct-state-to-servicing')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('acct-state-to-retired')), findsNothing);

    await _tap(tester, 'acct-state-to-servicing');
    await _tap(tester, 'acct-state-confirm');
    expect(_chip(tester), startsWith('Servicing'));
    expect(find.byKey(const ValueKey('acct-state-derived')), findsNothing);
    // a manager may resume; retiring is the owner's
    expect(find.byKey(const ValueKey('acct-state-to-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-state-to-retired')), findsNothing);

    await _tap(tester, 'acct-state-to-active');
    await _tap(tester, 'acct-state-confirm');
    expect(_chip(tester), startsWith('Active'));
  });

  testWidgets('the owner retires with a reason and reopens with a reason', (
    tester,
  ) async {
    final repo = _repo();
    await _pump(tester, repo, owner: true);
    await _tap(tester, 'acct-state-to-servicing');
    await _tap(tester, 'acct-state-confirm');

    await _tap(tester, 'acct-state-to-retired');
    // no reason: refused under its field, nothing sent
    await _tap(tester, 'acct-state-confirm');
    expect(find.text('Say why.'), findsOneWidget);
    expect(_chip(tester), startsWith('Servicing'));
    await tester.enterText(
      find.byKey(const ValueKey('acct-state-reason')),
      'closing the books',
    );
    await _tap(tester, 'acct-state-confirm');
    expect(_chip(tester), startsWith('Retired'));
    expect(find.text('closing the books'), findsOneWidget);
    // from retired only the owner's reopen is offered, never "resume"
    expect(find.byKey(const ValueKey('acct-state-to-active')), findsNothing);

    await _tap(tester, 'acct-state-to-servicing');
    await tester.enterText(
      find.byKey(const ValueKey('acct-state-reason')),
      'one more correction',
    );
    await _tap(tester, 'acct-state-confirm');
    expect(_chip(tester), startsWith('Servicing'));
  });

  testWidgets('retiring is refused in words while a delivery is in progress, '
      'and works once it is settled', (tester) async {
    final repo = _repo();
    final connection = await repo.openTokenConnection(
      'ws-1',
      issuerSiteId: 'site-1',
      targetId: 'pennylane_api',
      displayName: 'Pennylane',
    );
    repo.deliveries.add(
      AccountingDelivery(
        id: 'd-1',
        targetId: 'pennylane_api',
        connectionId: connection.id,
        documentKind: 'invoice',
        documentId: 'inv-1',
        eventDate: DateTime(2026, 10, 30),
        payloadSha256: 'a' * 64,
        status: DeliveryStatus.sent,
      ),
    );
    await _pump(tester, repo, owner: true);
    await _tap(tester, 'acct-state-to-servicing');
    await _tap(tester, 'acct-state-confirm');
    // the snack of this move leaves before the next one speaks
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 1));

    await _tap(tester, 'acct-state-to-retired');
    await tester.enterText(
      find.byKey(const ValueKey('acct-state-reason')),
      'closing',
    );
    await _tap(tester, 'acct-state-confirm');
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.text(
        'Deliveries are still in progress. Finish or settle them before '
        'retiring.',
      ),
      findsOneWidget,
    );
    expect(_chip(tester), startsWith('Servicing'));

    // settled: the same move now works
    repo.deliveries[0] = AccountingDelivery(
      id: 'd-1',
      targetId: 'pennylane_api',
      connectionId: connection.id,
      documentKind: 'invoice',
      documentId: 'inv-1',
      eventDate: DateTime(2026, 10, 30),
      payloadSha256: 'a' * 64,
      status: DeliveryStatus.acknowledged,
    );
    await tester.pump(const Duration(seconds: 5)); // the snack leaves
    await _tap(tester, 'acct-state-to-retired');
    await tester.enterText(
      find.byKey(const ValueKey('acct-state-reason')),
      'closing',
    );
    await _tap(tester, 'acct-state-confirm');
    expect(_chip(tester), startsWith('Retired'));
  });
}
