// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C2 — Me › Messages in the personal shell lays the inbox and the
// conversation it opens out for its width. The invariants: wide, the list
// keeps its 360 beside the thread and nothing is chosen (or read) for the
// person; narrow, an opened conversation is the focused page and Back
// finds the list's filter and scroll as they were; a resize moves the
// same thread, which is neither read nor built again; an unsent message
// is kept per conversation and source for the session, cleared only by a
// delivery and never by a completion that lands after the account
// changed; a hidden or backgrounded thread neither polls nor marks read,
// and a hidden list does not poll; a person or group picked in the
// personal directory (#2472) opens in the pane.
import 'dart:async';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/features/directory/domain/conversation_target.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/domain/personal_message_directory.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:deskilo/features/directory/presentation/messenger/conversation_pane.dart';
import 'package:deskilo/features/directory/presentation/messenger/foreground_poll.dart';
import 'package:deskilo/features/directory/providers/conversation_pane_providers.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _other = 'https://other.example';
const _wide = Size(1200, 900);
const _narrow = Size(400, 800);
const _ws =
    'cccccccc-0000-4000-8000-000000000001:00000000-0000-4000-8000-0000000000f1';

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, dynamic> _row(
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

/// The messenger as the server answers it, with every thread read and the
/// account sends held back on request.
class _Messenger extends FakeMessengerRepository {
  int threadReads = 0;
  int inboxReads = 0;
  Completer<void>? holdSends;

  @override
  Future<List<Map<String, dynamic>>> inbox() {
    inboxReads++;
    return super.inbox();
  }

  @override
  Future<List<ContextMessage>> accountMessages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  }) {
    threadReads++;
    return super.accountMessages(
      conversation,
      beforeAt: beforeAt,
      beforeId: beforeId,
    );
  }

  @override
  Future<String> sendAccountMessage(String recipient, String body) async {
    await holdSends?.future;
    return super.sendAccountMessage(recipient, body);
  }
}

/// The personal home's directory: one workspace with Ada, one group.
class _Directory implements PersonalMessageDirectoryRepository {
  @override
  Future<DirectoryPage<DirectoryWorkspace>> workspaces({String? after}) async =>
      const DirectoryPage(
        items: [DirectoryWorkspace(networkId: _ws, name: 'Atelier')],
        status: RelationshipStatus.ready,
      );

  @override
  Future<DirectoryPage<DirectoryPerson>> people(
    String networkId, {
    String? after,
    String query = '',
  }) async => const DirectoryPage(
    items: [
      DirectoryPerson(id: 'ada', workspaceRef: _ws, name: 'Ada Lovelace'),
    ],
    status: RelationshipStatus.ready,
  );

  @override
  Future<DirectoryPage<DirectoryGroup>> groups({String? after}) async =>
      const DirectoryPage(
        items: [
          DirectoryGroup(
            id: 'g1',
            title: 'Floor crew',
            announceOnly: false,
            canWrite: true,
          ),
        ],
        status: RelationshipStatus.ready,
      );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _Messenger home,
  required FakeMessengerRepository remote,
  Size size = _wide,
  FakeAuthRepository? auth,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: MeMessagesTab()),
      ),
      GoRoute(
        path: '/account-messages',
        builder: (_, _) => const AccountMessengerScreen(handOffTo: '/'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...standardTestOverrides(
          auth: auth,
          messenger: home,
          messengers: {_other: remote},
          personalDirectory: _Directory(),
          connectedSources: [
            const ConnectedInstallation(
              endpoint: BackendEndpoint(_other, 'key'),
              account: 'u-remote',
              installationId: 'inst-2',
            ),
          ],
        ),
        personalShellEnabledProvider.overrideWithValue(true),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MeMessagesTab)));
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// The text of the composer field the thread shows.
String _composerText(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: _key('context-thread'),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

Future<void> _lifecycle(
  WidgetTester tester,
  List<AppLifecycleState> states,
) async {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
}

void main() {
  late _Messenger home;
  late FakeMessengerRepository remote;

  setUp(() {
    home = _Messenger()
      ..inboxRows.addAll([
        _row(
          MessageContextKind.account,
          'c-ana',
          'Ana',
          peer: 'ana',
          unread: 1,
          at: '2026-07-15T09:00:00Z',
        ),
        _row(
          MessageContextKind.account,
          'c-bo',
          'Bo',
          peer: 'bo',
          at: '2026-07-15T07:00:00Z',
        ),
      ])
      ..threads[FakeMessengerRepository.threadKey(
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
    remote = FakeMessengerRepository()
      ..inboxRows.add(
        _row(MessageContextKind.inquiryOut, 'c-inq', 'La Serre', unread: 1),
      );
  });

  test('the list and the narrowest thread are design sizes', () {
    expect(MessengerMetrics.listWidth, 360);
    expect(MessengerMetrics.minThreadWidth, 360);
    expect(messengerSplits(721), isTrue);
    expect(messengerSplits(720), isFalse);
  });

  testWidgets('wide: the list keeps its 360 beside Choose a conversation; '
      'nothing is read until a row is opened, which opens in the pane', (
    tester,
  ) async {
    await _pump(tester, home: home, remote: remote);
    expect(_key('messenger-split'), findsOneWidget);
    expect(_key('messenger-choose'), findsOneWidget);
    expect(tester.getSize(_key('unified-inbox')).width, 360);
    expect(home.reads, isEmpty, reason: 'the first read marks nothing');
    expect(remote.reads, isEmpty);
    expect(home.threadReads, 0, reason: 'no conversation is chosen for me');

    await _tap(tester, _key('inbox-entry-c-ana'));
    expect(_key('context-thread'), findsOneWidget);
    expect(_key('unified-inbox'), findsOneWidget, reason: 'the list stays');
    expect(_key('messenger-choose'), findsNothing);
    expect(
      _key('context-thread-back'),
      findsNothing,
      reason: 'beside the list there is nothing to go back to',
    );
    expect(find.text('Are you in tomorrow?'), findsOneWidget);
    expect(home.reads, ['c-ana']);
    expect(tester.widget<ListTile>(_key('inbox-entry-c-ana')).selected, isTrue);
  });

  testWidgets('narrow: an opened conversation is the focused page; Back '
      'restores the list\'s filter and scroll', (tester) async {
    home.inboxRows.addAll([
      for (var i = 0; i < 30; i++)
        _row(
          MessageContextKind.account,
          'c-$i',
          'Person $i',
          peer: 'p$i',
          unread: 1,
          at: '2026-07-14T${(i % 20).toString().padLeft(2, '0')}:00:00Z',
        ),
    ]);
    await _pump(tester, home: home, remote: remote, size: _narrow);
    expect(_key('messenger-focused'), findsOneWidget);
    expect(
      _key('messenger-choose'),
      findsNothing,
      reason: 'narrow, the list is the page',
    );
    await _tap(tester, _key('unified-inbox-unread'));
    final list = find
        .descendant(
          of: _key('unified-inbox-list'),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(list, const Offset(0, -900));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(list).position.pixels;
    expect(offset, greaterThan(0));

    final row = find
        .byWidgetPredicate(
          (w) =>
              w is ListTile &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('inbox-entry-c-'),
        )
        .hitTestable();
    await _tap(tester, row.first);
    expect(_key('context-thread'), findsOneWidget);
    expect(_key('unified-inbox'), findsNothing, reason: 'kept, not shown');
    expect(_key('context-thread-back'), findsOneWidget);

    await _tap(tester, _key('context-thread-back'));
    expect(_key('context-thread'), findsNothing);
    expect(
      tester.widget<FilterChip>(_key('unified-inbox-unread')).selected,
      isTrue,
    );
    expect(tester.state<ScrollableState>(list).position.pixels, offset);
  });

  testWidgets('a resize moves the same thread: it is not read again and the '
      'half-written message stays', (tester) async {
    await _pump(tester, home: home, remote: remote, size: _narrow);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'half written');
    await tester.pump();
    expect(home.reads, ['c-ana']);
    final reads = home.threadReads;

    await _resize(tester, _wide);
    expect(_key('messenger-split'), findsOneWidget);
    expect(_key('context-thread'), findsOneWidget);
    expect(_key('context-thread-back'), findsNothing);
    expect(_composerText(tester), 'half written');
    await _resize(tester, _narrow);
    expect(_key('context-thread-back'), findsOneWidget);
    expect(_composerText(tester), 'half written');
    expect(home.reads, ['c-ana'], reason: 'one thread, one read mark');
    expect(home.threadReads, reads, reason: 'nothing was fetched again');
    expect(
      _key('context-draft-session-only'),
      findsNothing,
      reason: 'the same thread, not a restored draft',
    );
  });

  testWidgets('an unsent message is kept per conversation and source; a '
      'refused send keeps it, a delivered one clears it', (tester) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'for Ana');
    await tester.pump();

    await _tap(tester, _key('inbox-entry-c-inq'));
    expect(
      _composerText(tester),
      isEmpty,
      reason: 'another source, another conversation',
    );
    await _tap(tester, _key('inbox-entry-c-ana'));
    expect(_composerText(tester), 'for Ana');
    expect(_key('context-draft-session-only'), findsOneWidget);

    home.fail = true;
    await _tap(tester, _key('member-note-send'));
    expect(_composerText(tester), 'for Ana', reason: 'a refusal keeps it');
    await tester.pump(const Duration(seconds: 5));
    home.fail = false;
    await _tap(tester, _key('inbox-entry-c-bo'));
    await _tap(tester, _key('inbox-entry-c-ana'));
    expect(_composerText(tester), 'for Ana');

    await _tap(tester, _key('member-note-send'));
    expect(find.text('for Ana'), findsOneWidget, reason: 'it went out');
    await _tap(tester, _key('inbox-entry-c-bo'));
    await _tap(tester, _key('inbox-entry-c-ana'));
    expect(_composerText(tester), isEmpty);
    expect(_key('context-draft-session-only'), findsNothing);
  });

  testWidgets('a send that lands after the account changed neither clears '
      'nor fills the next account\'s drafts, and the next account starts '
      'with no conversation open', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final container = await _pump(
      tester,
      home: home,
      remote: remote,
      auth: auth,
    );
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'sent late');
    await tester.pump();
    home.holdSends = Completer<void>();
    await tester.tap(_key('member-note-send'));
    await tester.pump();

    auth.signInAs('user-2');
    await tester.pumpAndSettle();
    expect(container.read(conversationSelectionProvider), isNull);
    expect(_key('context-thread'), findsNothing);
    final drafts = container.read(conversationDraftsProvider.notifier);
    final key = conversationDraftKey(
      source: '',
      kind: MessageContextKind.account,
      contextId: 'c-ana',
    );
    drafts.keep('user-2', key, 'mine now');

    home.holdSends!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      drafts.draftOf('user-2', key),
      'mine now',
      reason: 'the late delivery is the earlier account\'s',
    );
    expect(
      drafts.draftOf('user-1', key),
      isEmpty,
      reason: 'and nothing of the earlier account is readable',
    );
  });

  testWidgets('a hidden or backgrounded thread neither polls nor marks '
      'read; shown again it reads once', (tester) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-ana'));
    expect(home.reads, ['c-ana']);
    const poll = Duration(seconds: SettingDefaults.messagingThreadPollSeconds);
    await tester.pump(poll);
    await tester.pump();
    expect(home.threadReads, greaterThan(1), reason: 'shown, it polls');

    await _lifecycle(tester, const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    final before = home.threadReads;
    for (var i = 0; i < 3; i++) {
      await tester.pump(poll);
    }
    await tester.pump();
    expect(home.threadReads, before, reason: 'no poll in the background');
    expect(home.reads, ['c-ana'], reason: 'no read mark in the background');

    await _lifecycle(tester, const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(home.threadReads, before + 1, reason: 'one read catches up');
    expect(home.reads, ['c-ana', 'c-ana']);
  });

  testWidgets('under a focused thread the list does not poll', (tester) async {
    await _pump(tester, home: home, remote: remote, size: _narrow);
    await _tap(tester, _key('inbox-entry-c-bo'));
    final pages = home.inboxReads;
    const poll = Duration(seconds: SettingDefaults.messagingInboxPollSeconds);
    for (var i = 0; i < 3; i++) {
      await tester.pump(poll);
    }
    await tester.pump();
    expect(home.inboxReads, pages);

    await _tap(tester, _key('context-thread-back'));
    final shown = home.inboxReads;
    expect(shown, greaterThan(pages), reason: 'shown again, it reads once');
    await tester.pump(poll);
    await tester.pump();
    expect(home.inboxReads, greaterThan(shown), reason: 'and polls again');
  });

  testWidgets('#2472: a person picked in the personal directory opens in the '
      'pane, and the first message goes to them', (tester) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('unified-inbox-people'));
    expect(find.byType(AccountMessengerScreen), findsOneWidget);
    await _tap(tester, _key('reachable-person-p-$_ws-ada'));

    expect(find.byType(AccountMessengerScreen), findsNothing);
    expect(_key('messenger-split'), findsOneWidget);
    expect(_key('context-thread'), findsOneWidget);
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tester.enterText(_key('member-note-body'), 'Hello Ada');
    await _tap(tester, _key('member-note-send'));
    expect(find.text('Hello Ada'), findsOneWidget);
    expect(
      home
          .threads[FakeMessengerRepository.threadKey(
            MessageContextKind.account,
            'ada',
          )]
          ?.map((m) => m.body),
      ['Hello Ada'],
    );
  });

  testWidgets('#2472: a group picked in the personal directory opens in the '
      'pane on a phone, with Back to the list', (tester) async {
    await _pump(tester, home: home, remote: remote, size: _narrow);
    await _tap(tester, _key('unified-inbox-people'));
    await tester.scrollUntilVisible(
      _key('reachable-group-g1'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountMessengerScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await _tap(tester, _key('reachable-group-g1'));
    expect(_key('context-thread'), findsOneWidget);
    expect(find.text('Floor crew'), findsOneWidget);
    await _tap(tester, _key('context-thread-back'));
    expect(_key('unified-inbox'), findsOneWidget);
  });

  testWidgets('a poll whose view is hidden stops; shown again it catches up '
      'once; disposed, nothing pending fires', (tester) async {
    var ticks = 0, resumes = 0;
    const period = Duration(seconds: 10);
    final poll = ForegroundPoll(
      period: period,
      onTick: () => ticks++,
      onResume: () => resumes++,
    );
    await tester.pump(period * 2);
    expect((ticks, resumes), (2, 0));

    poll.setShown(shown: false);
    await tester.pump(period * 3);
    expect((ticks, resumes), (2, 0), reason: 'hidden, nothing ticks');

    poll
      ..setShown(shown: true)
      ..setShown(shown: true);
    await tester.pump();
    expect((ticks, resumes), (2, 1), reason: 'one catch-up, not three');

    poll
      ..setShown(shown: false)
      ..setShown(shown: true)
      ..dispose();
    await tester.pump(period * 2);
    expect((ticks, resumes), (2, 1), reason: 'disposed: nothing lands');
  });
}
