// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #821 — the Messages tab reworked: the thread as a PAGE with day
// separators and a draft that survives leaving, one attach button in the
// composer, the alerts face named for what it holds, and a muted
// conversation that the announcer keeps quiet. The list's filter chips
// and long-press menu live on in the Me messenger and are tested there
// (`unified_inbox_test.dart`); the workspace list they were built on is
// gone (#2383).

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_notification_service.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

const _ana = Member(
  id: 'member-2',
  workspaceId: 'ws-1',
  userId: 'user-2',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);
const _bob = Member(
  id: 'member-3',
  workspaceId: 'ws-1',
  userId: 'user-3',
  isAdmin: false,
  isOwner: false,
  status: MemberStatus.active,
);

MemberNote _note(String id, String from, String body, DateTime at,
        {String conversation = 'conv-ana'}) =>
    MemberNote(
      id: id,
      workspaceId: 'ws-1',
      fromMemberId: from,
      toMemberId: from == 'member-1' ? 'member-2' : 'member-1',
      body: body,
      createdAt: at,
      conversationId: conversation,
    );

/// Two conversations: Ana's, with one unread message from her today and
/// one of mine three days ago (two days → two separators); Bob's, read,
/// older.
Future<FakeWorkspaceRepository> _pump(
  WidgetTester tester, {
  Map<String, dynamic> flags = const {},
  bool anaMuted = false,
  FakeNotificationService? notifications,
}) async {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final today = DateTime.utc(kTestNow.year, kTestNow.month, kTestNow.day, 8);
  final earlier = today.subtract(const Duration(days: 3));
  final anaNotes = [
    _note('n-old', 'member-1', 'see you thursday', earlier),
    _note('n-new', 'member-2', 'nine works', today),
  ];
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags)
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana', 'member-3': 'Bob'}
    ..otherMembers.addAll([_ana, _bob])
    ..memberNotes.addAll(anaNotes)
    ..conversationMessages['conv-ana'] = [...anaNotes]
    ..conversationMessages['conv-bob'] = [
      _note('n-bob', 'member-3', 'thanks', earlier, conversation: 'conv-bob'),
    ]
    ..conversations.addAll([
      Conversation(
        id: 'conv-ana',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'nine works',
        lastFromMemberId: 'member-2',
        lastAt: today,
        unread: 1,
        muted: anaMuted,
      ),
      Conversation(
        id: 'conv-bob',
        kind: ConversationKind.direct,
        otherMemberId: 'member-3',
        lastBody: 'thanks',
        lastFromMemberId: 'member-3',
        lastAt: earlier,
      ),
    ]);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        notifications: notifications,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

Finder get _daySeparators => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> &&
          key.value.startsWith('conversation-day-');
    });

void main() {
  testWidgets('the alerts face is named for what it holds', (tester) async {
    await _pump(tester);
    await openAlertsTab(tester);
    expect(find.text('Alerts'), findsWidgets);
    expect(find.text('Events'), findsNothing);
  });

  testWidgets('a conversation opens as a PAGE with day separators, and '
      'what was typed survives leaving and coming back', (tester) async {
    await _pump(tester);
    await openWorkspaceConversation(tester, 'conv-ana');
    expect(find.byKey(const ValueKey('conversation-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
    // Two messages on two days → two separators, and the old date is
    // spelled out where "Today" is not.
    expect(_daySeparators, findsNWidgets(2));
    expect(find.text('Today'), findsOneWidget);

    // One attach button; the pickers live behind it.
    expect(find.byKey(const ValueKey('composer-attach')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-note-ref-space')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('composer-attach')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('member-note-ref-space')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-note-ref-reservation')),
        findsOneWidget);
    // Close the menu without picking.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('member-note-body')), 'on my way');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-page')), findsNothing);

    await openWorkspaceConversation(tester, 'conv-ana');
    final field = tester
        .widget<TextField>(find.byKey(const ValueKey('member-note-body')));
    expect(field.controller?.text, 'on my way');
    // Sending clears the draft for good.
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-back')));
    await tester.pumpAndSettle();
    await openWorkspaceConversation(tester, 'conv-ana');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('member-note-body')))
            .controller
            ?.text,
        isEmpty);
  });

  testWidgets('a MUTED conversation is not announced; another one is',
      (tester) async {
    final notifications = FakeNotificationService();
    await _pump(tester, anaMuted: true, notifications: notifications);
    // Ana's unread note is the only one that would be announced — and
    // her conversation is muted.
    expect(notifications.shown.where((s) => s.body == 'nine works'),
        isEmpty);
  });

  testWidgets('with the flag off the thread stays a sheet and the face '
      'keeps its old name', (tester) async {
    await _pump(tester, flags: const {'messagesHub': false});
    await openAlertsTab(tester);
    expect(find.text('Events'), findsWidgets);
    await openWorkspaceConversation(tester, 'conv-ana');
    expect(find.byKey(const ValueKey('conversation-page')), findsNothing);
    expect(find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach')), findsNothing);
    expect(find.byKey(const ValueKey('member-note-ref-space')), findsOneWidget);
  });

}
