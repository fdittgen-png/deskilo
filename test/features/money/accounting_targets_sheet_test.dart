// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 — the accounting systems sheet: a billing manager connects the
// issuer to Pennylane with a token (a short one is refused under its
// field), maps a tax code, and revokes; a reader sees the states and the
// transfers but no door to act; a sign-in where the server registered no
// application says so; the transfers name each file's digest and the
// documents it carried, and a connection delivery's state.
import 'dart:async';

import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/core/demo/seed/demo_book_period_seed.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/domain/accounting_delivery_run.dart';
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

/// A route or a sheet opening or closing, and the dropdown menu: longer
/// than the Material transitions they run (300 ms at most).
const _transition = Duration(milliseconds: 400);

/// Taps the control keyed [key], then lets the fake repository answer and
/// the transition it starts finish: explicit frames, never a settle loop.
Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await _frames(tester);
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_transition);
  await tester.pump();
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
    await _frames(tester);
    await tester.enterText(find.byKey(const ValueKey('acct-map-tax')), 'VAT|FR|5.5');
    await tester.enterText(find.byKey(const ValueKey('acct-map-code')), 'FR_55');
    await _tap(tester, 'acct-map-save');
    expect(find.text('This is not a key of this kind.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('acct-map-tax')), 'VAT|FR|taxed|5.5|2014');
    await _tap(tester, 'acct-map-save');
    expect(repo.connections.single.maps.single.key, 'VAT|FR|taxed|5.5|2014');
    expect(find.text('VAT|FR|taxed|5.5|2014 → FR_55'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await _frames(tester);

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

  testWidgets('a billing manager delivers the year: the document whose answer was missing is read back', (tester) async {
    final repo = seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today);
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    expect(find.text('Deliver 2026 to Pennylane — Atelier du Marché'), findsOneWidget);
    // Only the delivery the target has not acknowledged can be sent again.
    expect(find.byKey(const ValueKey('acct-redeliver-demo-delivery-credit')), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-redeliver-demo-delivery-invoice')), findsNothing);

    await _tap(tester, 'acct-deliver-demo-connection-pennylane');
    expect(find.text('Delivered: 1 · already there: 1 · to check: 0'), findsOneWidget);
    expect(find.textContaining('Received by the system'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('acct-redeliver-demo-delivery-credit')), findsNothing);
  });

  testWidgets('one document is sent again on its own', (tester) async {
    final repo = seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today);
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    await _tap(tester, 'acct-redeliver-demo-delivery-credit');
    expect(repo.deliveries.map((d) => d.status), everyElement(DeliveryStatus.acknowledged));
    expect(find.text('Delivered: 1 · already there: 0 · to check: 0'), findsOneWidget);
  });

  testWidgets('a reader has no door to deliver', (tester) async {
    final repo = seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today);
    await _open(tester, repo, permissions: {WorkspacePermission.viewFinances});
    // The list is there, with the delivery a manager could send again.
    expect(find.byKey(const ValueKey('acct-delivery-demo-delivery-credit')), findsOneWidget);
    expect(find.byKey(const ValueKey('acct-deliver-demo-connection-pennylane')), findsNothing);
    expect(find.byKey(const ValueKey('acct-redeliver-demo-delivery-credit')), findsNothing);
  });

  testWidgets('a delivery says what it waits for: an unmapped key, blocked books, a refused company', (tester) async {
    final repo = _Answering(seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today));
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    final answers = {
      'Delivered: 0 · already there: 0 · to check: 1 Map these first: account bank': const DeliveryRunDone([
        DeliveryRunDocument(status: DeliveryRunStatus.blocked, missing: ['account bank']),
      ]),
      'The books of this period cannot be posted yet: bank. Nothing was delivered.':
          const DeliveryRunBooksBlocked(['bank']),
      'The accounting system refused this company: Custom transaction numbers is off. Nothing was delivered.':
          const DeliveryRunTargetRefused('Custom transaction numbers is off'),
      'This connection is signed out: connect it again, then deliver. Nothing was delivered.':
          const DeliveryRunNotConnected(),
      'The server refused: check that you may manage the billing. Nothing was delivered.':
          const DeliveryRunNotAllowed(),
    };
    for (final MapEntry(key: said, value: answer) in answers.entries) {
      repo.answer = answer;
      await _tap(tester, 'acct-redeliver-demo-delivery-credit');
      expect(find.text(said), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).removeCurrentSnackBar();
      await _frames(tester);
    }
    expect(repo.asked, answers.length, reason: 'one request per tap');
  });

  testWidgets('a door is disabled and busy while its run goes; a second tap starts nothing', (tester) async {
    final pending = Completer<DeliveryRun>();
    final repo = _Answering(seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today))
      ..pending = pending;
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    const door = ValueKey('acct-redeliver-demo-delivery-credit');
    await tester.tap(find.byKey(door));
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(door)).onPressed, isNull);
    await tester.tap(find.byKey(door), warnIfMissed: false);
    await tester.pump();
    expect(repo.asked, 1);
    pending.complete(const DeliveryRunDone([]));
    await _frames(tester);
    expect(tester.widget<ButtonStyleButton>(find.byKey(door)).onPressed, isNotNull);
    expect(find.text('Nothing to deliver in this period.'), findsOneWidget);
  });

  testWidgets('a year stopped in one month names it and what went before it', (tester) async {
    final repo = _Answering(seedDemoAccountingConnections(FakeBookPeriodRepository(today: _today), _today))
      ..answers = [
        const DeliveryRunDone([DeliveryRunDocument(status: DeliveryRunStatus.acknowledged)]),
        const DeliveryRunBooksBlocked(['bank']),
      ];
    await _open(tester, repo, permissions: {WorkspacePermission.manageBilling});
    await _tap(tester, 'acct-deliver-demo-connection-pennylane');
    expect(
      find.text('The books of this period cannot be posted yet: bank. Stopped at February 2026. Delivered before it: 1.'),
      findsOneWidget,
    );
    expect(repo.asked, 2);
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

/// The demo repository answering every delivery with [answer].
class _Answering extends FakeAccountingConnectionRepository {
  _Answering(FakeAccountingConnectionRepository seeded)
    : super(
        books: seeded.books,
        today: seeded.today,
        connections: seeded.connections,
        deliveries: seeded.deliveries,
      );

  DeliveryRun answer = const DeliveryRunDone([]);

  /// One answer per request, in order, before [answer].
  List<DeliveryRun> answers = const [];

  /// When set, the next request waits for it.
  Completer<DeliveryRun>? pending;
  int asked = 0;

  @override
  Future<DeliveryRun> deliver(
    String connectionId, {
    required DateTime from,
    required DateTime to,
    ({String kind, String id})? document,
  }) async {
    asked++;
    final waiting = pending;
    if (waiting != null) {
      pending = null;
      return waiting.future;
    }
    return asked <= answers.length ? answers[asked - 1] : answer;
  }
}
