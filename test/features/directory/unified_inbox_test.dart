// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — Me › Messages is ONE inbox across contexts and servers.
//
// The invariant: every conversation the person takes part in shows up
// once, labelled with its context, its server named only when it is not
// this one, with its unread count; a server that does not answer is
// named and the others still show; opening a conversation reads it.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const other = 'https://other.example';

Map<String, dynamic> inboxRow(
  MessageContextKind kind,
  String id,
  String title, {
  int unread = 0,
  String at = '2026-07-15T08:00:00Z',
  String? peer,
}) => {
  'context_kind': kind.wire,
  'context_id': id,
  'workspace_id': 'ws-1',
  'workspace_name': 'Pézenas',
  'title': title,
  'last_body': 'last words of $title',
  'last_at': at,
  'unread': unread,
  'peer_id': ?peer,
};

Future<void> pumpInbox(
  WidgetTester tester, {
  required FakeMessengerRepository home,
  required FakeMessengerRepository remote,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: MeMessagesTab()),
      ),
      GoRoute(
        path: '/account-messages',
        builder: (_, _) => const Scaffold(body: Text('people search')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: standardTestOverrides(
        messenger: home,
        messengers: {other: remote},
        connectedSources: [
          const ConnectedInstallation(
            endpoint: BackendEndpoint(other, 'key'),
            account: 'u-remote',
            installationId: 'inst-2',
          ),
        ],
      ),
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeMessengerRepository home;
  late FakeMessengerRepository remote;

  setUp(() {
    home = FakeMessengerRepository()
      ..inboxRows.addAll([
        inboxRow(
          MessageContextKind.space,
          'c-space',
          'Étage 2 group',
          unread: 2,
          at: '2026-07-15T09:00:00Z',
        ),
        inboxRow(
          MessageContextKind.account,
          'c-ana',
          'Ana',
          peer: 'ana',
          at: '2026-07-15T07:00:00Z',
        ),
      ]);
    remote = FakeMessengerRepository()
      ..inboxRows.add(
        inboxRow(
          MessageContextKind.inquiryOut,
          'c-inq',
          'La Serre',
          unread: 1,
          at: '2026-07-15T08:00:00Z',
        ),
      );
  });

  testWidgets('conversations of every context and server in one list, '
      'newest first, each labelled', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    final rows = tester
        .widgetList<ListTile>(
          find.byWidgetPredicate(
            (w) => w is ListTile && '${w.key}'.contains('inbox-entry-'),
          ),
        )
        .map((t) => '${t.key}')
        .toList();
    expect(rows, [
      "[<'inbox-entry-c-space'>]",
      "[<'inbox-entry-c-inq'>]",
      "[<'inbox-entry-c-ana'>]",
    ]);
    expect(find.textContaining('In Pézenas'), findsOneWidget);
    expect(find.textContaining('Person to person'), findsOneWidget);
    // The remote row names its server; the home rows do not.
    expect(
      find.textContaining('Your inquiry to Pézenas · on other.example'),
      findsOneWidget,
    );
    expect(find.textContaining('on other.example'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-unread-c-space')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-unread-c-inq')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-unread-c-ana')), findsNothing);
  });

  testWidgets('the Unread filter keeps only what waits for me', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    expect(find.text('Unread · 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-unread')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-entry-c-space')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsOneWidget);
  });

  testWidgets('a server that does not answer is named; the rest still show', (
    tester,
  ) async {
    remote.fail = true;
    await pumpInbox(tester, home: home, remote: remote);
    expect(
      find.byKey(const ValueKey('unified-inbox-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('other.example'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-entry-c-space')), findsOneWidget);
    remote.fail = false;
    await tester.tap(find.byKey(const ValueKey('unified-inbox-unavailable')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-inq')), findsOneWidget);
  });

  testWidgets('opening a conversation reads it and replies to the right '
      'person', (tester) async {
    home.threads[FakeMessengerRepository.threadKey(
      MessageContextKind.account,
      'c-ana',
    )] = [
      ContextMessage(
        id: 'm-ana',
        kind: MessageKind.accountMessage,
        body: 'Are you in tomorrow?',
        mine: false,
        authorName: 'Ana',
        createdAt: DateTime.utc(2026, 7, 15, 7),
      ),
    ];
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-thread')), findsOneWidget);
    expect(find.text('Are you in tomorrow?'), findsOneWidget);
    expect(home.reads, contains('c-ana'));
    await tester.enterText(
      find.byKey(const ValueKey('context-composer')),
      'Yes, at nine',
    );
    await tester.tap(find.byKey(const ValueKey('context-send')));
    await tester.pumpAndSettle();
    expect(find.text('Yes, at nine'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context-delivered-msg-1')),
      findsOneWidget,
    );
  });

  testWidgets('a remote inquiry opens on its own server', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-inq')));
    await tester.pumpAndSettle();
    expect(remote.reads, ['c-inq']);
    expect(home.reads, isEmpty);
  });

  testWidgets('Find people leads to the account search', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-people')));
    await tester.pumpAndSettle();
    expect(find.text('people search'), findsOneWidget);
  });
}
