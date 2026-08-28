// SPDX-License-Identifier: 0BSD
//
// THE INBOX (#702): conversations, alerts and members — three faces of
// one destination, where they used to be a tab, an app-bar bell and
// another tab.
//
// What is worth pinning here is not that three widgets render. It is the
// rule they were merged under: ONE HOME EACH. A thing reachable from two
// places is a thing you can read in one and still be told about in the
// other, which is why messages left the bell in #687 and why the bell
// itself left in #702.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<FakeWorkspaceRepository> pumpInbox(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
  List<Conversation> conversations = const [],
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: featureFlags,
  )
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.addAll(conversations);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tapNavIcon(tester, Icons.forum_outlined);
  return workspace;
}

void main() {
  testWidgets('three faces, and the chats one is showing', (tester) async {
    await pumpInbox(tester);

    for (final tab in ['chats', 'alerts', 'members']) {
      expect(find.byKey(ValueKey('inbox-tab-$tab')), findsOneWidget,
          reason: 'the $tab face is missing');
    }
    // Chats first: it is the face that is always there, and the one the
    // destination is named after.
    expect(find.byKey(const ValueKey('new-conversation')), findsOneWidget);
  });

  testWidgets('each face keeps its place while you look at another',
      (tester) async {
    await pumpInbox(tester, conversations: [
      Conversation(
        id: 'conv-ana',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'See you at ten',
        lastAt: DateTime.utc(2026, 8, 27),
      ),
    ]);

    expect(find.byKey(const ValueKey('conversation-conv-ana')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('inbox-tab-alerts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inbox-tab-chats')));
    await tester.pumpAndSettle();
    // An IndexedStack, so the list was never torn down and rebuilt.
    expect(find.byKey(const ValueKey('conversation-conv-ana')), findsOneWidget);
  });

  testWidgets('the faces stay INSIDE the shell — the bar never goes away',
      (tester) async {
    await pumpInbox(tester);

    for (final tab in ['alerts', 'members', 'chats']) {
      await tester.tap(find.byKey(ValueKey('inbox-tab-$tab')));
      await tester.pumpAndSettle();
      expect(find.byType(ShellBottomBar), findsOneWidget,
          reason: 'the $tab face covered the bottom bar');
    }
  });

  testWidgets('one face left is no tab bar at all', (tester) async {
    await pumpInbox(tester, featureFlags: const {
      'eventsTab': false,
      'membersDirectory': false,
    });

    expect(find.byKey(const ValueKey('inbox-tabs')), findsNothing);
    // The conversations are still there — it is the CHROME that goes.
    expect(find.byKey(const ValueKey('new-conversation')), findsOneWidget);
  });

  testWidgets('/events lands on the Alerts face, not on a second screen',
      (tester) async {
    await pumpInbox(tester);
    final context = tester.element(find.byType(ShellBottomBar));
    GoRouter.of(context).go('/events');
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.text('No events yet.'), findsOneWidget);
  });

  testWidgets('/directory lands on the Members face', (tester) async {
    await pumpInbox(tester);
    final context = tester.element(find.byType(ShellBottomBar));
    GoRouter.of(context).go('/directory');
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
    // The face is showing — the directory's own content depends on
    // seeded members, which this pump deliberately does not have.
    expect(
      tester
          .widget<TabBar>(find.byKey(const ValueKey('inbox-tabs')))
          .controller!
          .index,
      2,
    );
  });

  group('the pieces the widget tree cannot show', () {
    test('a message repaints the inbox live, not on the next pull', () {
      // The map sent `member_notes` to the OLD bell feed and nothing
      // else, so an incoming message left the list, the unread badge and
      // any open thread sitting on caches nothing refreshed. A messenger
      // where messages arrive when you pull down is not a messenger.
      final map =
          File('lib/core/realtime/invalidation_map.dart').readAsStringSync();
      final mapping = map.substring(map.indexOf("'member_notes' =>"));
      expect(mapping, contains('conversationsProvider'));
      expect(mapping, contains('conversationMessagesProvider'));
      // And the conversation tables themselves, which 0125 created after
      // the last publication change and nobody went back for.
      expect(map, contains("'conversations' || 'conversation_participants'"));
      expect(
        File('lib/core/realtime/realtime_sync.dart').readAsStringSync(),
        contains("'conversation_participants'"),
      );
      final migration =
          File('supabase/migrations/0129_conversations_realtime.sql')
              .readAsStringSync();
      expect(migration, contains('add table public.conversations'));
      expect(migration, contains('replica identity full'));
    });

    test('pre-0125 messages are backfilled into conversations', () {
      // 0125 gave member_notes a conversation_id; nothing ever filled it
      // for the notes already there. Reading threads BY conversation
      // then renders them nowhere — and #702 deletes the old filtering
      // sheet that was still showing them.
      final sql = File('supabase/migrations/0130_backfill_conversations.sql')
          .readAsStringSync();
      expect(sql, contains('conversation_id is null'));
      expect(sql, contains('insert into public.conversation_participants'));
      // A pair that already has a thread must not get a second one.
      expect(sql, contains('where not exists'));
      // Broadcasts have no pair and stay in the alerts feed.
      expect(sql, contains('to_member_id is not null'));
    });

    test('the bar survives on one destination', () {
      // The old guard hid the whole bar below two destinations — and the
      // bar carries the raised Reserve button, so a workspace with
      // Calendar and Money off would have lost the app's core action.
      final shell =
          File('lib/app/shell/shell_screen.dart').readAsStringSync();
      expect(shell, contains('visibleBranches.isEmpty'));
      expect(shell, isNot(contains('visibleBranches.length < 2')));
    });
  });
}
