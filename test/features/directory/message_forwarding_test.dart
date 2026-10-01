// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — forwarding with nothing hidden, the lock, "What happened",
// deleting my own account message, and the screenshot notice.
//
// The invariants: a forward lands as a copy that names its origin, and
// the conversation it came from gets a system line saying who forwarded
// it where; an author's lock removes the forward action; the history
// sheet lists what the server recorded; only my own account message can
// be deleted; a screenshot the platform reports is recorded and shown.
import 'package:deskilo/core/capture/capture_protection.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/directory/presentation/messenger/context_thread_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

String key(String id) =>
    FakeMessengerRepository.threadKey(MessageContextKind.account, id);

ContextMessage message(
  String id,
  String body, {
  bool mine = false,
  bool noForward = false,
  int minute = 0,
}) => ContextMessage(
  id: id,
  kind: MessageKind.accountMessage,
  body: body,
  mine: mine,
  authorName: mine ? 'Me' : 'Ana',
  noForward: noForward,
  createdAt: DateTime.utc(2026, 7, 15, 8, minute),
);

FakeMessengerRepository seeded() => FakeMessengerRepository()
  ..inboxRows.addAll([
    {
      'context_kind': 'account',
      'context_id': 'c-ana',
      'title': 'Ana',
      'last_at': '2026-07-15T08:00:00Z',
      'peer_id': 'ana',
    },
    {
      'context_kind': 'account',
      'context_id': 'c-bob',
      'title': 'Bob',
      'last_at': '2026-07-15T07:00:00Z',
      'peer_id': 'bob',
    },
  ])
  ..threads[key('c-ana')] = [
    message('m-mine', 'My plan', mine: true, minute: 2),
    message('m-ana', 'Heating on floor 2?', minute: 1),
  ];

Future<void> pumpThread(
  WidgetTester tester,
  FakeMessengerRepository repo, {
  String conversation = 'c-ana',
  String title = 'Ana',
  CaptureProtection? capture,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: standardTestOverrides(messenger: repo, capture: capture),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ContextThreadScreen(
          kind: MessageContextKind.account,
          contextId: conversation,
          title: title,
          peer: 'ana',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openActions(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('context-actions-$id')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a forward lands as a copy naming its origin, and the source '
      'conversation is told who forwarded it where', (tester) async {
    final repo = seeded();
    await pumpThread(tester, repo);
    await openActions(tester, 'm-ana');
    await tester.tap(find.byKey(const ValueKey('message-action-forward')));
    await tester.pumpAndSettle();
    // The picker offers the other conversation, never this one.
    expect(find.byKey(const ValueKey('forward-target-c-bob')), findsOneWidget);
    expect(find.byKey(const ValueKey('forward-target-c-ana')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('forward-target-c-bob')));
    await tester.pumpAndSettle();
    expect(find.text('Forwarded to Bob.'), findsOneWidget);
    expect(repo.forwards, [(messageId: 'm-ana', target: 'c-bob')]);
    expect(
      find.text('Me forwarded a message of this conversation to Bob.'),
      findsOneWidget,
    );
    final copy = repo.threads[key('c-bob')]!.single;
    expect(copy.forwardedFrom?.authorName, 'Ana');

    // In the target, the copy says where it came from.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpThread(tester, repo, conversation: 'c-bob', title: 'Bob');
    expect(find.byKey(ValueKey('forward-origin-${copy.id}')), findsOneWidget);
    expect(find.textContaining('written by Ana'), findsOneWidget);
  });

  testWidgets('an author locks a message and the forward action disappears', (
    tester,
  ) async {
    final repo = seeded();
    await pumpThread(tester, repo);
    await openActions(tester, 'm-mine');
    expect(
      find.byKey(const ValueKey('message-action-forward')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('message-action-lock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('context-locked-m-mine')), findsOneWidget);
    await openActions(tester, 'm-mine');
    expect(find.byKey(const ValueKey('message-action-forward')), findsNothing);
    expect(find.text('Allow forwarding'), findsOneWidget);
  });

  testWidgets('somebody else\'s locked message says why it cannot be '
      'forwarded', (tester) async {
    final repo = seeded();
    repo.threads[key('c-ana')]![1] = message(
      'm-ana',
      'Heating on floor 2?',
      noForward: true,
      minute: 1,
    );
    await pumpThread(tester, repo);
    await openActions(tester, 'm-ana');
    expect(find.byKey(const ValueKey('message-action-forward')), findsNothing);
    expect(find.byKey(const ValueKey('message-action-locked')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('message-action-lock')),
      findsNothing,
      reason: 'only the author locks or unlocks',
    );
    expect(find.byKey(const ValueKey('message-action-delete')), findsNothing);
  });

  testWidgets('"What happened" lists what the server recorded', (tester) async {
    final repo = seeded()
      ..events['m-ana'] = [
        MessageEvent(
          event: 'sent',
          at: DateTime.utc(2026, 7, 15, 8),
          actorName: 'Ana',
        ),
        MessageEvent(
          event: 'read',
          at: DateTime.utc(2026, 7, 15, 9),
          actorName: 'Me',
        ),
        MessageEvent(
          event: 'forwarded',
          at: DateTime.utc(2026, 7, 15, 10),
          actorName: 'Florian',
          detail: const {'target_label': 'Inquiry · Chauffage Sud'},
        ),
        // A personal conversation is never named to the source.
        MessageEvent(
          event: 'forwarded',
          at: DateTime.utc(2026, 7, 15, 11),
          actorName: 'Bob',
          detail: const {'target_label': ''},
        ),
        MessageEvent(
          event: 'forwarded_from',
          at: DateTime.utc(2026, 7, 15, 7),
          actorName: 'Léa',
          detail: const {'context_label': 'Étage 2 group'},
        ),
      ];
    await pumpThread(tester, repo);
    await openActions(tester, 'm-ana');
    await tester.tap(find.byKey(const ValueKey('message-action-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-history-sheet')), findsOneWidget);
    expect(find.text('Sent by Ana'), findsOneWidget);
    expect(find.text('Read by Me'), findsOneWidget);
    expect(
      find.text('Forwarded by Florian to Inquiry · Chauffage Sud'),
      findsOneWidget,
    );
    expect(
      find.text('Forwarded by Bob to a personal conversation'),
      findsOneWidget,
    );
    expect(
      find.text('Originally written by Léa in Étage 2 group'),
      findsOneWidget,
    );
  });

  testWidgets('I delete my own account message after confirming', (
    tester,
  ) async {
    final repo = seeded();
    await pumpThread(tester, repo);
    await openActions(tester, 'm-mine');
    await tester.tap(find.byKey(const ValueKey('message-action-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('context-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['m-mine']);
    expect(find.text('My plan'), findsNothing);
    expect(find.text('Message deleted.'), findsOneWidget);
  });

  testWidgets('a screenshot the platform reports is recorded and shown in '
      'the conversation', (tester) async {
    const channel = MethodChannel(CaptureProtection.channelName);
    final binary =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    binary.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return false;
    });
    addTearDown(() => binary.setMockMethodCallHandler(channel, null));
    final repo = seeded();
    await pumpThread(tester, repo, capture: CaptureProtection(web: false));
    expect(calls, [
      'enable',
    ], reason: 'an account conversation is always protected');
    await binary.handlePlatformMessage(
      CaptureProtection.channelName,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('screenshot'),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(repo.captures, ['c-ana']);
    expect(
      find.text('Me took a screenshot of this conversation.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(calls, ['enable', 'disable'], reason: 'leaving lets go');
  });

  testWidgets('a refusal the server explains is said in its own words',
      (tester) async {
    final repo = seeded()..refuseForward = 'forwarding is off in this space';
    await pumpThread(tester, repo);
    await openActions(tester, 'm-ana');
    await tester.tap(find.byKey(const ValueKey('message-action-forward')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('forward-target-c-bob')));
    await tester.pumpAndSettle();
    expect(find.text('This space does not allow forwarding its messages.'),
        findsOneWidget);
    expect(repo.forwards, isEmpty);
  });
}
