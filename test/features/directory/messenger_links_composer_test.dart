// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C3 — the messenger of the personal shell, continued. A workspace
// conversation on this server opens in the pane (the focused page on a
// phone), with its workspace lent for as long as it is shown and given
// back after. A link to a conversation selects it only once its own source
// lists it for this person; a link it does not list, or cannot be asked
// about, says so and opens nothing. The composer: Return is a newline,
// Ctrl/Cmd+Enter sends once, an input method's composition never sends; a
// send that does not answer in time is unconfirmed and never resent by
// itself; a thread opened again while its send is in flight shows neither
// the text nor a Send that could repeat it.
import 'dart:async';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/directory/domain/conversation_delivery.dart';
import 'package:deskilo/features/directory/domain/conversation_link.dart';
import 'package:deskilo/features/directory/domain/conversation_target.dart';
import 'package:deskilo/features/directory/domain/inbox_composition.dart';
import 'package:deskilo/features/directory/domain/inbox_sources.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/presentation/messenger/inbox_header.dart';
import 'package:deskilo/features/directory/providers/conversation_pane_providers.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _other = 'https://other.example';
const _wide = Size(1200, 900);
const _narrow = Size(400, 800);

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, dynamic> _row(
  MessageContextKind kind,
  String id,
  String title, {
  String workspace = 'ws-1',
  String at = '2026-07-15T08:00:00Z',
  String? peer,
}) => {
  'context_kind': kind.wire,
  'context_id': id,
  'workspace_id': workspace,
  'workspace_name': 'Pézenas',
  'title': title,
  'last_body': 'last words of $title',
  'last_at': at,
  'unread': 1,
  'peer_id': ?peer,
};

/// The messenger as the server answers it; account sends counted and held
/// back on request.
class _Messenger extends FakeMessengerRepository {
  int sends = 0;
  Completer<void>? holdSends;

  @override
  Future<String> sendAccountMessage(String recipient, String body) async {
    sends++;
    await holdSends?.future;
    return super.sendAccountMessage(recipient, body);
  }
}

/// Two workspaces of mine on this server: ws-1 is active, the conversation
/// conv-2 lives in ws-2.
FakeWorkspaceRepository _workspaces() {
  final repo = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(
      Conversation(
        id: 'conv-2',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'see you at ten',
        lastAt: DateTime.utc(2026, 7, 15, 10),
      ),
    );
  repo.workspaces.add(
    repo.workspaces.first.copyWith(id: 'ws-2', name: 'La Serre'),
  );
  repo.conversationMessages['conv-2'] = [
    MemberNote(
      id: 'n-1',
      workspaceId: 'ws-2',
      fromMemberId: 'member-2',
      toMemberId: 'member-1',
      body: 'see you at ten',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      conversationId: 'conv-2',
    ),
  ];
  return repo;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _Messenger home,
  required FakeMessengerRepository remote,
  Size size = _wide,
  String location = '/',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: '/',
        builder: (_, state) => Scaffold(
          body: MeMessagesTab(
            link: state.uri.queryParameters[ConversationLink.parameter],
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...standardTestOverrides(
          messenger: home,
          messengers: {_other: remote},
          workspace: _workspaces(),
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

/// The text of the thread's composer.
TextEditingController _composer(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(
        of: _key('context-thread'),
        matching: find.byType(TextField),
      ),
    )
    .controller!;

Future<void> _chord(WidgetTester tester, LogicalKeyboardKey modifier) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

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
          at: '2026-07-15T09:00:00Z',
        ),
        _row(MessageContextKind.account, 'c-bo', 'Bo', peer: 'bo'),
        _row(
          MessageContextKind.space,
          'conv-2',
          'Ana at La Serre',
          workspace: 'ws-2',
          at: '2026-07-15T10:00:00Z',
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
      ..inboxRows.add(_row(MessageContextKind.inquiryOut, 'c-inq', 'La Serre'));
  });

  group('a link is authorized by its own source', () {
    const link = ConversationLink(
      source: '',
      kind: MessageContextKind.account,
      contextId: 'c-ana',
    );
    final ana = InboxEntry(
      source: '',
      kind: MessageContextKind.account,
      contextId: 'c-ana',
      lastAt: DateTime.utc(2026, 7, 15),
    );
    InboxSlot slot(InboxSlotState state, {String source = ''}) {
      final reading = InboxSlot.reading(
        role: InboxSourceRole.personalHome,
        source: source,
      );
      return switch (state) {
        InboxSlotState.loaded => reading.legacyRows(const []),
        InboxSlotState.failed => reading.failed(StateError('down')),
        _ => reading,
      };
    }

    test('the link round-trips the qualified key, and nothing else parses', () {
      expect(ConversationLink.parse(link.key)?.key, '|account|c-ana');
      expect(
        ConversationLink.parse('$_other|inquiry_out|c-inq')?.source,
        _other,
      );
      for (final bad in [null, '', 'c-ana', '|nope|c-ana', '|account|']) {
        expect(ConversationLink.parse(bad), isNull, reason: '$bad');
      }
    });

    test('listed: authorized; still reading: pending; answered without it: '
        'refused; not answering: unreachable', () {
      expect(authorizeLink(UnifiedInbox([ana]), link), (
        LinkVerdict.authorized,
        ana,
      ));
      expect(
        authorizeLink(
          ComposedInbox(const [], sources: [slot(InboxSlotState.reading)]),
          link,
        ).$1,
        LinkVerdict.pending,
      );
      expect(
        authorizeLink(
          ComposedInbox(const [], sources: [slot(InboxSlotState.loaded)]),
          link,
        ).$1,
        LinkVerdict.refused,
      );
      expect(
        authorizeLink(
          ComposedInbox(
            const [],
            sources: [
              slot(InboxSlotState.failed),
              slot(InboxSlotState.loaded, source: _other),
            ],
          ),
          link,
        ).$1,
        LinkVerdict.unreachable,
        reason: 'another source answering is not this one\'s word',
      );
    });
  });

  testWidgets('a workspace conversation opens in the pane with its '
      'workspace lent, read once; leaving it gives the workspace back', (
    tester,
  ) async {
    final container = await _pump(tester, home: home, remote: remote);
    expect(await container.read(activeWorkspaceIdProvider.future), 'ws-1');

    await _tap(tester, _key('inbox-entry-conv-2'));
    expect(_key('workspace-thread-pane'), findsOneWidget);
    expect(_key('unified-inbox'), findsOneWidget, reason: 'the list stays');
    expect(_key('conversation-page'), findsNothing, reason: 'no own route');
    expect(_key('conversation-back'), findsNothing);
    expect(find.text('see you at ten'), findsWidgets);
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-2');
    expect(home.reads, ['conv-2']);

    await _tap(tester, _key('inbox-entry-c-bo'));
    expect(_key('workspace-thread-pane'), findsNothing);
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-1');
  });

  testWidgets('narrow: the workspace conversation is the focused page, and '
      'its Back returns to the list and the workspace', (tester) async {
    final container = await _pump(
      tester,
      home: home,
      remote: remote,
      size: _narrow,
    );
    await _tap(tester, _key('inbox-entry-conv-2'));
    expect(_key('workspace-thread-pane'), findsOneWidget);
    expect(_key('unified-inbox'), findsNothing);
    await _tap(tester, _key('conversation-back'));
    expect(_key('unified-inbox'), findsOneWidget);
    expect(container.read(conversationSelectionProvider), isNull);
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-1');
  });

  testWidgets('a link its source lists selects the conversation — this '
      'server\'s or another\'s', (tester) async {
    await _pump(
      tester,
      home: home,
      remote: remote,
      location:
          '/?'
          '${ConversationLink.parameter}=${Uri.encodeComponent('|account|c-ana')}',
    );
    expect(_key('context-thread'), findsOneWidget);
    expect(find.text('Are you in tomorrow?'), findsOneWidget);
    expect(home.reads, ['c-ana']);
  });

  testWidgets('a link to another server\'s conversation opens it there', (
    tester,
  ) async {
    await _pump(
      tester,
      home: home,
      remote: remote,
      location:
          '/?'
          '${ConversationLink.parameter}='
          '${Uri.encodeComponent('$_other|inquiry_out|c-inq')}',
    );
    expect(_key('context-thread'), findsOneWidget);
    expect(remote.reads, ['c-inq']);
    expect(home.reads, isEmpty);
  });

  testWidgets('a link no source lists for me — another server\'s id, an '
      'unknown one, a malformed one — says so and opens nothing', (
    tester,
  ) async {
    for (final link in [
      '$_other|account|c-ana',
      '|account|c-zed',
      'nonsense',
    ]) {
      await _pump(
        tester,
        home: home,
        remote: remote,
        location:
            '/?'
            '${ConversationLink.parameter}=${Uri.encodeComponent(link)}',
      );
      expect(
        find.text(_en.conversationLinkRefused),
        findsOneWidget,
        reason: link,
      );
      expect(_key('context-thread'), findsNothing, reason: link);
      expect(_key('messenger-choose'), findsOneWidget, reason: link);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    }
    expect(home.reads, isEmpty);
    expect(remote.reads, isEmpty);
  });

  testWidgets('a link whose source cannot answer says so and opens nothing; '
      'the other sources still show', (tester) async {
    remote.fail = true;
    await _pump(
      tester,
      home: home,
      remote: remote,
      location:
          '/?'
          '${ConversationLink.parameter}='
          '${Uri.encodeComponent('$_other|inquiry_out|c-inq')}',
    );
    expect(find.text(_en.conversationLinkUnreachable), findsOneWidget);
    expect(_key('context-thread'), findsNothing);
    expect(_key('inbox-entry-c-ana'), findsOneWidget);
  });

  testWidgets('Return is a newline, Ctrl+Enter sends once, a composing '
      'word never sends', (tester) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-bo'));
    await tester.showKeyboard(_key('member-note-body'));
    await tester.enterText(_key('member-note-body'), 'line one');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(home.sends, 0, reason: 'Return never sends');

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'line one\nにほ',
        selection: TextSelection.collapsed(offset: 11),
        composing: TextRange(start: 9, end: 11),
      ),
    );
    await tester.pump();
    await _chord(tester, LogicalKeyboardKey.controlLeft);
    expect(home.sends, 0, reason: 'a candidate is still being chosen');

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'line one\n日本',
        selection: TextSelection.collapsed(offset: 11),
      ),
    );
    await tester.pump();
    await _chord(tester, LogicalKeyboardKey.controlLeft);
    await _chord(tester, LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(home.sends, 1, reason: 'the same command as Send, once');
    expect(find.text('line one\n日本'), findsOneWidget);
  });

  testWidgets('Cmd+Enter sends from another server\'s composer', (
    tester,
  ) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-inq'));
    await tester.showKeyboard(_key('context-composer'));
    await tester.enterText(_key('context-composer'), 'Is the room free?');
    await _chord(tester, LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('Is the room free?'), findsOneWidget);
    expect(_composer(tester).text, isEmpty);
  });

  testWidgets('a send that does not answer in time is unconfirmed: never '
      'resent, read again on request; its late delivery clears the draft', (
    tester,
  ) async {
    final container = await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'on my way');
    await tester.pump();
    home.holdSends = Completer<void>();
    await tester.tap(_key('member-note-send'));
    await tester.pump(ConversationDelivery.unconfirmedAfter);
    await tester.pump();
    expect(_key('context-send-unconfirmed'), findsOneWidget);
    expect(_composer(tester).text, 'on my way', reason: 'nothing is lost');

    await tester.tap(_key('member-note-send'));
    await tester.pump();
    expect(home.sends, 1, reason: 'no blind resend');

    await tester.tap(_key('context-send-review'));
    await tester.pump();
    expect(_key('context-send-unconfirmed'), findsNothing);
    expect(_composer(tester).text, 'on my way');

    home.holdSends!.complete();
    await tester.pump();
    await tester.pump();
    expect(_composer(tester).text, isEmpty, reason: 'it did arrive');
    final key = conversationDraftKey(
      source: '',
      kind: MessageContextKind.account,
      contextId: 'c-ana',
    );
    expect(
      container
          .read(conversationDraftsProvider.notifier)
          .draftOf('user-1', key),
      isEmpty,
    );
    expect(container.read(conversationSendsProvider), isEmpty);
  });

  testWidgets('a thread opened again while its send is in flight shows '
      'neither the text nor a Send that repeats it; a refusal gives the '
      'text back', (tester) async {
    await _pump(tester, home: home, remote: remote);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'see you there');
    await tester.pump();
    home.holdSends = Completer<void>();
    await tester.tap(_key('member-note-send'));
    await tester.pump();

    await tester.tap(_key('inbox-entry-c-bo'));
    await tester.pump();
    await tester.tap(_key('inbox-entry-c-ana'));
    await tester.pump();
    await tester.pump();
    expect(_composer(tester).text, isEmpty);
    expect(_key('context-send-in-flight'), findsOneWidget);
    expect(_key('context-draft-session-only'), findsNothing);

    home.fail = true;
    home.holdSends!.complete();
    await tester.pump();
    await tester.pump();
    expect(_key('context-send-in-flight'), findsNothing);
    expect(_composer(tester).text, 'see you there', reason: 'refused: kept');
    expect(home.sends, 1);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a delivery that lands while the thread is open again leaves '
      'its composer empty', (tester) async {
    await _pump(tester, home: home, remote: remote, size: _narrow);
    await _tap(tester, _key('inbox-entry-c-ana'));
    await tester.enterText(_key('member-note-body'), 'landed late');
    await tester.pump();
    home.holdSends = Completer<void>();
    await tester.tap(_key('member-note-send'));
    await tester.pump();
    await tester.tap(_key('context-thread-back'));
    await tester.pump();
    await tester.tap(_key('inbox-entry-c-ana'));
    await tester.pump();
    await tester.pump();
    expect(_composer(tester).text, isEmpty);

    home.holdSends!.complete();
    await tester.pump();
    await tester.pump();
    expect(_composer(tester).text, isEmpty);
    expect(_key('context-send-in-flight'), findsNothing);
    expect(home.sends, 1);
  });

  testWidgets('the list is built row by row, each row at least 88 tall; '
      'Requests are a labelled count in its header and New group and '
      'Starred a secondary menu', (tester) async {
    expect(InboxListRowMetrics.minHeight, 88);
    home.requests.add(
      const MessageRequest(
        conversationId: 'r-1',
        userId: 'zoe',
        name: 'Zoé',
        body: 'Hello from the third floor',
      ),
    );
    await _pump(tester, home: home, remote: remote);
    final list = tester.widget<ListView>(_key('unified-inbox-list'));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    for (final id in ['c-ana', 'c-bo', 'conv-2', 'c-inq']) {
      expect(
        tester.getSize(_key('inbox-entry-$id')).height,
        greaterThanOrEqualTo(InboxListRowMetrics.minHeight),
        reason: id,
      );
    }

    expect(_key('message-requests'), findsNothing, reason: 'not above it');
    expect(find.text(_en.inboxRequestsCount(1)), findsOneWidget);
    await _tap(tester, _key('unified-inbox-requests'));
    expect(_key('message-requests'), findsOneWidget);
    await _tap(tester, _key('request-accept-r-1'));
    expect(home.requests, isEmpty);
    await tester.tapAt(const Offset(600, 40));
    await tester.pump(const Duration(seconds: 1));
    expect(_key('unified-inbox-requests'), findsNothing, reason: 'none left');

    expect(_key('unified-inbox-new-group'), findsNothing);
    expect(_key('unified-inbox-starred'), findsNothing);
    await tester.tap(_key('unified-inbox-more'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(_key('unified-inbox-new-group'), findsOneWidget);
    expect(_key('unified-inbox-starred'), findsOneWidget);
  });
}
