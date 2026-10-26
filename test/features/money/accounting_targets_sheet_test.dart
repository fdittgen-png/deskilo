// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting systems sheet: a billing manager connects the
// issuer to Pennylane with a token (a short one is refused under its
// field), maps a tax code, and revokes; a reader sees the states and the
// transfers but no door to act; a sign-in where the server registered no
// application says so; the transfers name each file's digest and the
// documents it carried, and a connection delivery's state.
import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/book_period.dart';
import 'package:deskilo/features/money/presentation/widgets/accounting_targets_sheet.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 10, 25, 9);

const _workspace = Workspace(
  id: 'ws-1',
  name: 'Atelier',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'x',
);

const _studio = Site(id: 'demo-site-studio', workspaceId: 'ws-1', name: 'Atelier du Marché');

Future<void> _open(
  WidgetTester tester,
  FakeAccountingConnectionRepository repo, {
  required Set<WorkspacePermission> permissions,
}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      accountingConnectionRepositoryProvider.overrideWithValue(repo),
      currentWorkspaceProvider.overrideWith((ref) async => _workspace),
      myPermissionsProvider.overrideWithValue(permissions),
      sitesProvider.overrideWith((ref) async => const [_studio]),
      memberNamesProvider.overrideWith((ref) async => const {'m-e': 'Eve Exporter'}),
      clockProvider.overrideWithValue(FixedClock(_today)),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AccountingTargetsView(workspaceId: 'ws-1')),
    ),
  ));
  await tester.pumpAndSettle();
}

FakeAccountingConnectionRepository _empty() =>
    FakeAccountingConnectionRepository(books: FakeBookPeriodRepository(today: _today), today: _today);

const _card = 'pennylane_api-demo-site-studio';

/// Taps the control keyed [key] and lets the sheet settle.
Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a billing manager connects with a token, maps a tax code and revokes', (tester) async {
    final repo = _empty();
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    expect(find.text('Not connected'), findsOneWidget);

    await _tap(tester, 'acct-connect-token-$_card');
    await tester.enterText(find.byKey(const ValueKey('acct-token-value')), 'short');
    await _tap(tester, 'acct-token-save');
    expect(find.text('Paste the whole token.'), findsOneWidget);
    expect(repo.connections, isEmpty, reason: 'nothing was sent');

    await tester.enterText(find.byKey(const ValueKey('acct-token-value')), 'tok-secret-2370-abcdef');
    await _tap(tester, 'acct-token-save');
    expect(find.byKey(const ValueKey('acct-connection-state-$_card')), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('tok-secret'), findsNothing, reason: 'the token is never shown');

    await _tap(tester, 'acct-maps-$_card');
    expect(find.byKey(const ValueKey('acct-maps-empty')), findsOneWidget);
    await _tap(tester, 'acct-map-add');
    await _tap(tester, 'acct-map-kind');
    await tester.tap(find.text('Tax code').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('acct-map-tax')), 'VAT|FR|5.5');
    await tester.enterText(find.byKey(const ValueKey('acct-map-code')), 'FR_55');
    await _tap(tester, 'acct-map-save');
    expect(find.text('This is not a key of this kind.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('acct-map-tax')), 'VAT|FR|taxed|5.5|2014');
    await _tap(tester, 'acct-map-save');
    expect(repo.connections.single.maps.single.key, 'VAT|FR|taxed|5.5|2014');
    expect(find.text('VAT|FR|taxed|5.5|2014 → FR_55'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await _tap(tester, 'acct-revoke-$_card');
    await _tap(tester, 'acct-revoke-confirm');
    expect(repo.connections.single.live, isFalse);
    expect(repo.connections.single.maps, hasLength(1), reason: 'the mappings stay');
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('One earlier connection was revoked'), findsOneWidget);
  });

  testWidgets('a sign-in where the server registered no application says so and opens nothing', (tester) async {
    final repo = _empty();
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    await tester.tap(find.byKey(const ValueKey('acct-sign-in-$_card')));
    await tester.pump();
    expect(find.textContaining('connect with an API token instead'), findsOneWidget);
    expect(repo.connections, isEmpty);
  });

  testWidgets('a reader sees the connection and the transfers, and no door to act', (tester) async {
    final books = FakeBookPeriodRepository(today: _today);
    final repo = seedDemoAccountingConnections(books, _today);
    final id = await books.recordExport('ws-1', _journalFile);
    await repo.recordFileDeliveries('ws-1', targetId: 'generic_journal_csv', issuerSiteId: 'demo-site-studio',
        bookExportId: id!, documents: [
          FileDocument(kind: 'invoice', id: 'inv-1', number: 'F-2026-0001', date: DateTime(2026, 1, 31), sha256: 'a' * 64),
        ]);
    await _open(tester, repo, permissions: {WorkspacePermission.viewFinances});
    expect(find.text('Connected'), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-maps-$_card')), findsOneWidget, reason: 'the mappings are readable');
    for (final door in ['acct-connect-token', 'acct-sign-in', 'acct-revoke', 'acct-refresh']) {
      expect(find.byKey(ValueKey('$door-$_card')), findsNothing, reason: door);
    }
    // The file: its target, its short digest and who made it.
    expect(find.textContaining('Generic journal'), findsOneWidget);
    expect(find.textContaining('SHA-256 ${'e' * 12}…'), findsOneWidget);
    await _tap(tester, 'acct-transfer-file-$id');
    expect(find.text('SHA-256 ${'e' * 64}'), findsOneWidget);
    expect(find.textContaining('F-2026-0001 · Invoice'), findsWidgets);
    // The connection's deliveries: received, and one waiting for its readback.
    expect(find.textContaining('Received by the system'), findsOneWidget);
    expect(find.textContaining('In the system: F-2026-0001'), findsOneWidget);
    expect(find.textContaining('To check: the answer is missing or differs'), findsOneWidget);
    expect(find.textContaining('no answer after send: timeout'), findsOneWidget);
  });

  testWidgets('the transfers move by year', (tester) async {
    final repo = _empty();
    await _open(tester, repo, permissions: {WorkspacePermission.viewFinances});
    expect(find.text('Year 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-transfers-empty')), findsOneWidget);
    await _tap(tester, 'acct-transfers-previous');
    expect(find.text('Year 2025'), findsOneWidget);
  });
}

/// A generic journal file of 2026, as the export logs it.
final _journalFile = BookExportRecord(
  formatId: 'generic_journal_csv',
  from: DateTime(2026),
  to: DateTime(2026, 12, 31),
  sha256: 'e' * 64,
  bytes: 420,
  rows: 3,
  documents: 1,
);
