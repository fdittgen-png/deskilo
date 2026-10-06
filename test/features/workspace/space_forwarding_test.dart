// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — the space thread under the workspace's own switches.
//
// The invariants: with `messageForwarding` on, every bubble offers its
// actions and a forward goes out as a `member_note`; off, no bubble
// offers any. A forwarded note names its origin and a system line is a
// line, not a bubble. With `captureProtection` on the thread holds the
// window's protection; off, it never asks the platform.
import 'package:deskilo/core/capture/capture_protection.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/presentation/widgets/conversation_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

MemberNote note(String id, {String from = 'member-2', int minute = 0}) =>
    MemberNote.fromRow({
      'id': id,
      'workspace_id': 'ws-1',
      'from_member_id': from,
      'to_member_id': null,
      'body': 'body of $id',
      'created_at': DateTime.utc(2026, 7, 15, 8, minute).toIso8601String(),
      'conversation_id': 'c1',
    });

Future<(FakeMessengerRepository, List<String>, CaptureProtection)>
pumpSpaceThread(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  List<MemberNote>? notes,
}) async {
  const channel = MethodChannel(CaptureProtection.channelName);
  final binary =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  binary.setMockMethodCallHandler(channel, (call) async {
    calls.add(call.method);
    return false;
  });
  addTearDown(() => binary.setMockMethodCallHandler(channel, null));
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(
      Conversation(
        id: 'c1',
        kind: ConversationKind.group,
        title: 'Étage 2 group',
        lastAt: DateTime.utc(2026, 7, 15, 8),
      ),
    );
  workspace.conversationMessages['c1'] = notes ?? [note('n1')];
  final messenger = FakeMessengerRepository()
    ..inboxRows.addAll([
      {
        'context_kind': 'space',
        'context_id': 'c1',
        'title': 'Étage 2 group',
        'last_at': '2026-07-15T08:00:00Z',
      },
      {
        'context_kind': 'account',
        'context_id': 'c-ana',
        'title': 'Ana',
        'last_at': '2026-07-15T07:00:00Z',
      },
    ]);
  final protection = CaptureProtection(web: false);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        messenger: messenger,
        capture: protection,
      ),
      child: const MaterialApp(
        home: Scaffold(body: ConversationThread(conversationId: 'c1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (messenger, calls, protection);
}

void main() {
  testWidgets('with forwarding on, a space message is forwarded as a '
      'member note into another conversation', (tester) async {
    final (messenger, _, _) = await pumpSpaceThread(tester);
    await tester.tap(find.byKey(const ValueKey('bubble-actions-n1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-forward')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('forward-target-c1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('forward-target-c-ana')));
    await tester.pumpAndSettle();
    expect(messenger.forwards, [(messageId: 'n1', target: 'c-ana')]);
    expect(find.text('Forwarded to Ana.'), findsOneWidget);
  });

  testWidgets('with forwarding off, the actions offer no forward', (
    tester,
  ) async {
    await pumpSpaceThread(tester, flags: const {'messageForwarding': false});
    expect(find.byKey(const ValueKey('bubble-n1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('bubble-actions-n1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-action-star')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-forward')), findsNothing);
  });

  testWidgets('a forwarded note names its origin; a notice is a line', (
    tester,
  ) async {
    final forwarded = MemberNote.fromRow({
      'id': 'n2',
      'workspace_id': 'ws-1',
      'from_member_id': 'member-2',
      'body': 'Can someone look at the heating?',
      'created_at': '2026-07-15T08:05:00Z',
      'conversation_id': 'c1',
      'forwarded_from': {
        'kind': 'account_message',
        'context_label': 'Person to person',
        'author_name': 'Léa M.',
      },
    });
    final notice = MemberNote.fromRow({
      'id': 'n3',
      'workspace_id': 'ws-1',
      'from_member_id': 'member-1',
      'body': '',
      'created_at': '2026-07-15T08:06:00Z',
      'conversation_id': 'c1',
      'notice': {
        'kind': 'forwarded',
        'actor_name': 'Flo',
        'target_label': 'Inquiry · Chauffage Sud',
      },
    });
    await pumpSpaceThread(tester, notes: [note('n1'), forwarded, notice]);
    expect(find.byKey(const ValueKey('forward-origin-n2')), findsOneWidget);
    expect(find.textContaining('written by Léa M.'), findsOneWidget);
    expect(find.byKey(const ValueKey('notice-n3')), findsOneWidget);
    expect(find.byKey(const ValueKey('bubble-n3')), findsNothing);
    expect(
      find.text(
        'Flo forwarded a message of this conversation to '
        'Inquiry · Chauffage Sud.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('capture protection follows the workspace switch', (
    tester,
  ) async {
    final (_, onCalls, on) = await pumpSpaceThread(tester);
    expect(onCalls, ['enable']);
    expect(on.holders, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(onCalls, ['enable', 'disable']);
    expect(on.holders, 0);
    // Off: once the workspace's flags are known the thread lets go. While
    // they are still loading it holds — unknown fails closed.
    final (_, offCalls, off) = await pumpSpaceThread(
      tester,
      flags: const {'captureProtection': false},
    );
    expect(off.holders, 0);
    expect(offCalls.lastOrNull, isNot('enable'));
  });
}
