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
import 'package:deskilo/features/directory/domain/message_marks.dart';
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
      find.byKey(const ValueKey('member-note-body')),
      'Yes, at nine',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
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

  testWidgets('search narrows the list by title, last words or space',
      (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('unified-inbox-search-field')),
      'ana',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-entry-c-space')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-entry-c-inq')), findsNothing);
  });

  testWidgets('pin lifts a row to the top; archive moves it to Archived and '
      'back', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    await tester.longPress(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inbox-menu-pin')));
    await tester.pumpAndSettle();
    final first = tester
        .widgetList<ListTile>(find.byWidgetPredicate(
          (w) => w is ListTile && '${w.key}'.contains('inbox-entry-'),
        ))
        .first
        .key;
    expect('$first', contains('c-ana'));
    expect(find.byKey(const ValueKey('inbox-pinned-c-ana')), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inbox-menu-archive')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('unified-inbox-archived')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-entry-c-space')), findsNothing);
  });

  testWidgets('references need a workspace both people belong to: none in '
      'common locks the attach menu, one in common opens it', (tester) async {
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    // no shared workspace with Ana: the attach control is locked
    expect(find.byKey(const ValueKey('composer-attach-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach')), findsNothing);
  });

  testWidgets('with a shared workspace the attach menu is there',
      (tester) async {
    home.shared['ana'] = [(id: 'ws-1', name: 'Pézenas')];
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-attach')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach-locked')), findsNothing);
  });


  testWidgets('references in a message read as links, not as raw tokens',
      (tester) async {
    home.threads[FakeMessengerRepository.threadKey(MessageContextKind.account, 'c-ana')] = [
      ContextMessage(
        id: 'm-ref',
        kind: MessageKind.accountMessage,
        authorName: 'Ana',
        body: 'See [res:12bb132e-ff0b-4afc-8f59-8364e0caac9b|Ana · Desk 1 · 10 Aug] and [space:seat:ea9cad40-47a9-4ff5-830c-43eb9e556b13|Place 1]',
        createdAt: DateTime.utc(2026, 8, 10, 8),
        mine: false,
      ),
    ];
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    expect(find.textContaining('[res:'), findsNothing);
    expect(find.textContaining('[space:'), findsNothing);
    expect(find.text('Ana · Desk 1 · 10 Aug'), findsOneWidget);
    expect(find.text('Place 1'), findsOneWidget);
  });

  testWidgets('reactions show under the bubble; the action sheet reacts, '
      'stars and edits', (tester) async {
    final now = kTestNow.toUtc();
    home.threads[FakeMessengerRepository.threadKey(MessageContextKind.account, 'c-ana')] = [
      ContextMessage(
        id: 'm-1',
        kind: MessageKind.accountMessage,
        authorName: 'Me',
        body: 'Lunch at noon?',
        createdAt: now.subtract(const Duration(minutes: 2)),
        mine: true,
      ),
    ];
    home.marksByContext['account_conversation|c-ana'] = const MessageMarks(
      reactions: {'m-1': [ReactionCount('👍', 2, mine: true)]},
      starred: {'m-1'},
      edited: {'m-1'},
    );
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    // drawn: the reaction with its count, the star, the edited mark
    expect(find.byKey(const ValueKey('reaction-m-1-👍')), findsOneWidget);
    expect(find.text('👍 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('context-starred-m-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('context-edited-m-1')), findsOneWidget);

    // react from the sheet
    await tester.tap(find.byKey(const ValueKey('context-actions-m-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-react-❤️')));
    await tester.pumpAndSettle();
    expect(home.reactions.single.emoji, '❤️');

    // star toggles
    await tester.tap(find.byKey(const ValueKey('context-actions-m-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-star')));
    await tester.pumpAndSettle();
    expect(home.starredIds, contains('m-1'));

    // my own recent message can be edited
    await tester.tap(find.byKey(const ValueKey('context-actions-m-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('message-edit-field')), 'Lunch at one?');
    await tester.tap(find.byKey(const ValueKey('message-edit-save')));
    await tester.pumpAndSettle();
    expect(home.edits.single.body, 'Lunch at one?');
  });

  testWidgets('an old message offers no edit; a received one never does',
      (tester) async {
    home.threads[FakeMessengerRepository.threadKey(MessageContextKind.account, 'c-ana')] = [
      ContextMessage(
        id: 'm-old',
        kind: MessageKind.accountMessage,
        authorName: 'Me',
        body: 'old words',
        createdAt: kTestNow.toUtc().subtract(const Duration(hours: 2)),
        mine: true,
      ),
      ContextMessage(
        id: 'm-in',
        kind: MessageKind.accountMessage,
        authorName: 'Ana',
        body: 'hello',
        createdAt: kTestNow.toUtc().subtract(const Duration(minutes: 1)),
        mine: false,
      ),
    ];
    await pumpInbox(tester, home: home, remote: remote);
    await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
    await tester.pumpAndSettle();
    for (final id in ['m-old', 'm-in']) {
      await tester.tap(find.byKey(ValueKey('context-actions-$id')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('message-action-edit')), findsNothing,
          reason: id);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
    }
  });


  group('a workspace conversation keeps its flags on the server (0386)', () {
    setUp(() {
      home.inboxRows.add({
        ...inboxRow(MessageContextKind.space, 'c-flag', 'Salle', at: '2026-07-15T06:00:00Z'),
        'pinned': false,
        'muted': false,
        'archived': false,
      });
    });

    Future<void> choose(WidgetTester tester, String entry, String item) async {
      await tester.longPress(find.byKey(ValueKey('inbox-entry-$entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('inbox-menu-$item')));
      await tester.pumpAndSettle();
    }

    testWidgets('mute is the server\'s, shows on the row, and quiets the badge',
        (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      expect(find.byKey(const ValueKey('inbox-menu-mute')), findsNothing);
      await choose(tester, 'c-flag', 'mute');
      expect(home.flagLog, ['flags:c-flag']);
      expect(find.byKey(const ValueKey('inbox-muted-c-flag')), findsOneWidget);
    });

    testWidgets('mark unread is offered for a read thread and sets the server',
        (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      await choose(tester, 'c-flag', 'unread');
      expect(home.flagLog, ['unread:c-flag']);
      expect(find.byKey(const ValueKey('inbox-unread-c-flag')), findsOneWidget);
    });

    testWidgets('archive and pin go to the server; archived lists under Archived',
        (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      await choose(tester, 'c-flag', 'pin');
      expect(find.byKey(const ValueKey('inbox-pinned-c-flag')), findsOneWidget);
      await choose(tester, 'c-flag', 'archive');
      expect(home.flagLog, ['flags:c-flag', 'flags:c-flag']);
      expect(find.byKey(const ValueKey('inbox-entry-c-flag')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('unified-inbox-archived')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-entry-c-flag')), findsOneWidget);
      // A person-to-person conversation keeps this device's marks.
      expect(find.byKey(const ValueKey('inbox-entry-c-ana')), findsNothing);
    });

    testWidgets('a person-to-person thread offers no server mute',
        (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      await tester.longPress(find.byKey(const ValueKey('inbox-entry-c-ana')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('inbox-menu-mute')), findsNothing);
      expect(find.byKey(const ValueKey('inbox-menu-pin')), findsOneWidget);
    });
  });

  group('blocking a person (0387)', () {
    testWidgets('block from the thread asks first, blocks, and leaves the thread',
        (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      await tester.tap(find.byKey(const ValueKey('inbox-entry-c-ana')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-block')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Block Ana?'), findsOneWidget);
      // Cancelling blocks nobody.
      await tester.tap(find.byKey(const ValueKey('account-block-cancel')));
      await tester.pumpAndSettle();
      expect(home.blocked, isEmpty);
      await tester.tap(find.byKey(const ValueKey('account-block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('account-block-confirm')));
      await tester.pumpAndSettle();
      expect(home.blocked.keys, ['ana']);
      expect(find.byKey(const ValueKey('context-thread')), findsNothing);
    });

    testWidgets('a workspace conversation offers no person block', (tester) async {
      await pumpInbox(tester, home: home, remote: remote);
      await tester.tap(find.byKey(const ValueKey('inbox-entry-c-space')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-block')), findsNothing);
    });
  });
}
