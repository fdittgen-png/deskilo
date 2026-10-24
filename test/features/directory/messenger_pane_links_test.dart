// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C4 — the messenger's leftovers of C3. The workspace conversation
// in the pane keeps the account thread's delivery rules: one send at a
// time, also across a thread opened again; no answer in time is "Delivery
// not confirmed" and never resent on its own. Text typed while a send goes
// out is never taken by its answer — neither emptied by a delivery nor
// replaced by the refused draft. The lent workspace comes back on the
// installation it was selected on. A link to a conversation is followed
// outside the personal shell too, through the same authorization.
import 'dart:async';

import 'package:deskilo/app/routes/me_adapters.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/backend/context_client_providers.dart';
import 'package:deskilo/features/directory/domain/conversation_delivery.dart';
import 'package:deskilo/features/directory/domain/conversation_link.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _other = 'https://other.example';
const _wide = Size(1200, 900);

Finder _key(String key) => find.byKey(ValueKey(key));

Map<String, dynamic> _row(
  MessageContextKind kind,
  String id,
  String title, {
  String workspace = 'ws-1',
  String? peer,
}) => {
  'context_kind': kind.wire,
  'context_id': id,
  'workspace_id': workspace,
  'workspace_name': 'Pézenas',
  'title': title,
  'last_body': 'last words of $title',
  'last_at': '2026-07-15T08:00:00Z',
  'unread': 1,
  'peer_id': ?peer,
};

/// Account sends, counted, held back and refused on request.
class _Messenger extends FakeMessengerRepository {
  int sends = 0;
  Completer<void>? hold;

  @override
  Future<String> sendAccountMessage(String recipient, String body) async {
    sends++;
    await hold?.future;
    return super.sendAccountMessage(recipient, body);
  }
}

/// Two workspaces of mine on this server; conv-2 lives in ws-2. Its sends
/// are counted, held back and refused on request.
class _Workspaces extends FakeWorkspaceRepository {
  _Workspaces() : super.withWorkspace() {
    memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    conversations.add(
      Conversation(
        id: 'conv-2',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'see you at ten',
        lastAt: DateTime.utc(2026, 7, 15, 10),
      ),
    );
    workspaces.add(workspaces.first.copyWith(id: 'ws-2', name: 'La Serre'));
    conversationMessages['conv-2'] = [
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
  }

  int sends = 0;
  Completer<void>? hold;
  bool refuse = false;

  @override
  Future<void> sendConversationMessage(
    String conversationId,
    String body,
  ) async {
    sends++;
    await hold?.future;
    if (refuse) throw StateError('refused');
    return super.sendConversationMessage(conversationId, body);
  }
}

/// The active workspace as the person chose it, without a server default
/// that would answer for a connected one.
class _Ids extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'ws-1';
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _Messenger home,
  required _Workspaces workspace,
  bool personalShell = true,
  String location = '/',
}) async {
  tester.view.physicalSize = _wide;
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
          messengers: {_other: FakeMessengerRepository()},
          workspace: workspace,
          connectedSources: [
            const ConnectedInstallation(
              endpoint: BackendEndpoint(_other, 'key'),
              account: 'u-remote',
              installationId: 'inst-2',
            ),
          ],
        ),
        personalShellEnabledProvider.overrideWithValue(personalShell),
        activeWorkspaceIdProvider.overrideWith(_Ids.new),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await _settle(tester);
  return ProviderScope.containerOf(tester.element(find.byType(MeMessagesTab, skipOffstage: false)));
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// The text of the open thread's composer.
String _field(WidgetTester tester) =>
    tester.widget<TextField>(_key('member-note-body')).controller!.text;

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_key('member-note-body'), text);
  await tester.pump();
}

Future<void> _open(WidgetTester tester, String id) async {
  await tester.tap(_key('inbox-entry-$id'));
  await _frames(tester);
}

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  late _Messenger home;
  late _Workspaces workspace;

  setUp(() {
    home = _Messenger()
      ..inboxRows.addAll([
        _row(MessageContextKind.account, 'c-ana', 'Ana', peer: 'ana'),
        _row(MessageContextKind.account, 'c-bo', 'Bo', peer: 'bo'),
        _row(
          MessageContextKind.space,
          'conv-2',
          'Ana at La Serre',
          workspace: 'ws-2',
        ),
      ]);
    workspace = _Workspaces();
  });

  group('the workspace conversation in the pane', () {
    testWidgets('a send with no answer in time is unconfirmed, never resent; '
        'read again on request; its late delivery empties the field', (
      tester,
    ) async {
      await _pump(tester, home: home, workspace: workspace);
      await tester.tap(_key('inbox-entry-conv-2'));
      await _settle(tester);
      await _type(tester, 'on my way');
      workspace.hold = Completer<void>();
      await tester.tap(_key('member-note-send'));
      await tester.pump(ConversationDelivery.unconfirmedAfter);
      await tester.pump();
      expect(find.text(_en.conversationSendUnconfirmed), findsOneWidget);
      expect(_field(tester), 'on my way', reason: 'nothing is lost');

      await tester.tap(_key('member-note-send'));
      await tester.pump();
      expect(workspace.sends, 1, reason: 'no blind resend');

      await tester.tap(_key('context-send-review'));
      await tester.pump();
      expect(_key('context-send-unconfirmed'), findsNothing);

      workspace.hold!.complete();
      await _frames(tester);
      expect(_field(tester), isEmpty, reason: 'it did arrive');
      expect(workspace.sentMessages.single.body, 'on my way');
    });

    testWidgets('opened again while its send is in flight: no text, no '
        'repeat; text typed then is not replaced by the refused draft', (
      tester,
    ) async {
      await _pump(tester, home: home, workspace: workspace);
      await tester.tap(_key('inbox-entry-conv-2'));
      await _settle(tester);
      await _type(tester, 'first words');
      workspace
        ..hold = Completer<void>()
        ..refuse = true;
      await tester.tap(_key('member-note-send'));
      await tester.pump();

      await _open(tester, 'c-bo');
      await tester.tap(_key('inbox-entry-conv-2'));
      await _settle(tester);
      expect(_field(tester), isEmpty);
      expect(_key('context-send-in-flight'), findsOneWidget);
      await tester.tap(_key('member-note-send'));
      await tester.pump();
      expect(workspace.sends, 1, reason: 'nothing to repeat');

      await _type(tester, 'new words');
      workspace.hold!.complete();
      await _frames(tester);
      expect(_key('context-send-in-flight'), findsNothing);
      expect(_field(tester), 'new words', reason: 'typed since: kept');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('opened again while in flight and left untouched: a refusal '
        'gives the text back', (tester) async {
      await _pump(tester, home: home, workspace: workspace);
      await tester.tap(_key('inbox-entry-conv-2'));
      await _settle(tester);
      await _type(tester, 'give it back');
      workspace
        ..hold = Completer<void>()
        ..refuse = true;
      await tester.tap(_key('member-note-send'));
      await tester.pump();
      await _open(tester, 'c-bo');
      await tester.tap(_key('inbox-entry-conv-2'));
      await _settle(tester);

      workspace.hold!.complete();
      await _frames(tester);
      expect(_field(tester), 'give it back');
      expect(workspace.sentMessages, isEmpty);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('the account thread', () {
    testWidgets('text typed while a send goes out survives its delivery', (
      tester,
    ) async {
      await _pump(tester, home: home, workspace: workspace);
      await _open(tester, 'c-ana');
      await _type(tester, 'hello');
      home.hold = Completer<void>();
      await tester.tap(_key('member-note-send'));
      await tester.pump();
      await _type(tester, 'hello and more');
      home.hold!.complete();
      await _frames(tester);
      expect(home.sends, 1);
      expect(_field(tester), 'hello and more');
    });

    testWidgets('opened again while in flight: text typed then is not '
        'replaced by the refused draft', (tester) async {
      await _pump(tester, home: home, workspace: workspace);
      await _open(tester, 'c-ana');
      await _type(tester, 'refused words');
      home.hold = Completer<void>();
      await tester.tap(_key('member-note-send'));
      await tester.pump();
      await _open(tester, 'c-bo');
      await _open(tester, 'c-ana');
      expect(_field(tester), isEmpty);

      await _type(tester, 'typed meanwhile');
      home
        ..fail = true
        ..hold!.complete();
      await _frames(tester);
      expect(_field(tester), 'typed meanwhile');
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('a workspace of a connected installation lent to the pane '
      'comes back on that installation', (tester) async {
    final container = await _pump(tester, home: home, workspace: workspace);
    container
        .read(activeWorkspaceIdProvider.notifier)
        .activateConnected('ws-far', _other);
    await tester.pump();
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-far');

    await tester.tap(_key('inbox-entry-conv-2'));
    await _settle(tester);
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-2');
    expect(container.read(selectedWorkspaceHostProvider), isNull);

    await _open(tester, 'c-bo');
    await tester.pump();
    expect(container.read(activeWorkspaceIdProvider).value, 'ws-far');
    expect(container.read(selectedWorkspaceHostProvider), (
      workspaceId: 'ws-far',
      source: _other,
    ));
  });

  group('outside the personal shell', () {
    testWidgets('a link its source lists opens the conversation on its page', (
      tester,
    ) async {
      await _pump(
        tester,
        home: home,
        workspace: workspace,
        personalShell: false,
        location:
            '/?${ConversationLink.parameter}='
            '${Uri.encodeComponent('|account|c-ana')}',
      );
      expect(_key('context-thread'), findsOneWidget);
      expect(home.reads, ['c-ana']);
    });

    testWidgets('a link no source lists says so and opens nothing', (
      tester,
    ) async {
      await _pump(
        tester,
        home: home,
        workspace: workspace,
        personalShell: false,
        location:
            '/?${ConversationLink.parameter}='
            '${Uri.encodeComponent('|account|c-zed')}',
      );
      expect(find.text(_en.conversationLinkRefused), findsOneWidget);
      expect(_key('context-thread'), findsNothing);
      expect(home.reads, isEmpty);
    });

    test('the legacy tab address carries the link into the personal shell', () {
      const link = '|space|conv-2';
      expect(
        personalShellAddressOf(
          Uri(
            path: '/me',
            queryParameters: {
              'tab': 'messages',
              ConversationLink.parameter: link,
            },
          ),
        ),
        '/me/messages?conversation=${Uri.encodeQueryComponent(link)}',
      );
      expect(
        personalShellAddressOf(
          Uri(path: '/me', queryParameters: {'tab': 'messages'}),
        ),
        '/me/messages',
      );
    });
  });
}
