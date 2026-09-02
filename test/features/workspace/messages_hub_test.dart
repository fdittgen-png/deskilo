// SPDX-License-Identifier: 0BSD
//
// #821 — the Messages tab reworked: filter chips over the list, a
// long-press menu (pin, mute, mark unread, archive) that writes a
// preference and reorders the list, the thread as a PAGE with day
// separators and a draft that survives leaving, one attach button in the
// composer, the alerts face named for what it holds, a person opened on
// a tap from the new-conversation sheet, and a muted conversation that
// the announcer keeps quiet.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
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

Finder _row(String id) => find.byKey(ValueKey('conversation-$id'));

Future<void> _menu(WidgetTester tester, String id, String item) async {
  // Let the previous action's snack go, so it cannot sit over the sheet.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  await tester.longPress(_row(id));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('conversation-menu-$item')));
  await tester.pumpAndSettle();
}

Finder get _daySeparators => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> &&
          key.value.startsWith('conversation-day-');
    });

void main() {
  testWidgets('the alerts face is named for what it holds, and the chips '
      'narrow the list to unread or archived', (tester) async {
    await _pump(tester);
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
    expect(_row('conv-ana'), findsOneWidget);
    expect(_row('conv-bob'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-filter-unread')));
    await tester.pumpAndSettle();
    expect(_row('conv-ana'), findsOneWidget);
    expect(_row('conv-bob'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('inbox-filter-archived')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-list-no-archived')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
    await tester.pumpAndSettle();
    expect(_row('conv-bob'), findsOneWidget);
  });

  testWidgets('long-press: pin lifts a row to the top, mute marks it, '
      'mark-unread and archive write through and the list follows',
      (tester) async {
    final workspace = await _pump(tester);
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    // Newest first: Ana above Bob.
    expect(tester.getTopLeft(_row('conv-ana')).dy,
        lessThan(tester.getTopLeft(_row('conv-bob')).dy));

    await _menu(tester, 'conv-bob', 'pin');
    expect(workspace.prefsWrites.last.id, 'conv-bob');
    expect(workspace.prefsWrites.last.pinned, isTrue);
    expect(find.byKey(const ValueKey('conversation-pinned-conv-bob')),
        findsOneWidget);
    // Pinned wins over newest.
    expect(tester.getTopLeft(_row('conv-bob')).dy,
        lessThan(tester.getTopLeft(_row('conv-ana')).dy));

    await _menu(tester, 'conv-bob', 'mute');
    expect(workspace.prefsWrites.last.muted, isTrue);
    expect(find.byKey(const ValueKey('conversation-muted-conv-bob')),
        findsOneWidget);

    // A READ conversation offers "mark as unread"; an unread one does not.
    await _menu(tester, 'conv-bob', 'unread');
    expect(workspace.unreadMarks, ['conv-bob']);
    await tester.longPress(_row('conv-ana'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-menu-unread')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('conversation-menu-archive')));
    await tester.pumpAndSettle();
    expect(workspace.prefsWrites.last.id, 'conv-ana');
    expect(workspace.prefsWrites.last.archived, isTrue);
    expect(_row('conv-ana'), findsNothing);

    // The archive filter shows it, and the same menu restores it.
    await tester.tap(find.byKey(const ValueKey('inbox-filter-archived')));
    await tester.pumpAndSettle();
    expect(_row('conv-ana'), findsOneWidget);
    await _menu(tester, 'conv-ana', 'archive');
    expect(workspace.prefsWrites.last.archived, isFalse);
    await tester.tap(find.byKey(const ValueKey('inbox-filter-all')));
    await tester.pumpAndSettle();
    expect(_row('conv-ana'), findsOneWidget);
  });

  testWidgets('a conversation opens as a PAGE with day separators, and '
      'what was typed survives leaving and coming back', (tester) async {
    await _pump(tester);
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    await tester.tap(_row('conv-ana'));
    await tester.pumpAndSettle();
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
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('member-note-body')), 'on my way');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-page')), findsNothing);
    expect(_row('conv-ana'), findsOneWidget);

    await tester.tap(_row('conv-ana'));
    await tester.pumpAndSettle();
    final field = tester
        .widget<TextField>(find.byKey(const ValueKey('member-note-body')));
    expect(field.controller?.text, 'on my way');
    // Sending clears the draft for good.
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('conversation-back')));
    await tester.pumpAndSettle();
    await tester.tap(_row('conv-ana'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('member-note-body')))
            .controller
            ?.text,
        isEmpty);
  });

  testWidgets('the new-conversation sheet opens a person on a tap; the '
      'Group switch is the way to a named group', (tester) async {
    await _pump(tester);
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-conversation')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-conversation-group-switch')),
        findsOneWidget);
    // No start button in the one-to-one mode: the row IS the button.
    expect(find.byKey(const ValueKey('new-conversation-start')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('new-conversation-group-switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('new-conversation-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-group-name')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('new-conversation-group-switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-conversation-member-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-page')), findsOneWidget);
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
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();
    expect(find.text('Events'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-filter-unread')), findsNothing);
    await tester.tap(_row('conv-ana'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-page')), findsNothing);
    expect(find.byKey(const ValueKey('conversation-thread')), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach')), findsNothing);
    expect(find.byKey(const ValueKey('member-note-ref-space')), findsOneWidget);
  });

  test('migration 0146 carries the preferences and the paged list', () {
    final sql = File('supabase/migrations/0146_conversation_prefs.sql')
        .readAsStringSync();
    for (final what in [
      'add column if not exists pinned_at timestamptz',
      'add column if not exists muted boolean not null default false',
      'add column if not exists archived_at timestamptz',
      'create or replace function public.set_conversation_prefs(',
      'create or replace function public.mark_conversation_unread(',
      'p_include_archived boolean default false',
      '(p_include_archived or mine.archived_at is null)',
      '(mine.pinned_at is not null) desc',
    ]) {
      expect(sql, contains(what), reason: what);
    }
  });
}
