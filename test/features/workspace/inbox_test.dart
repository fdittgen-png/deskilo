// SPDX-License-Identifier: AGPL-3.0-or-later
//
// THE INBOX (#702): conversations and alerts — two faces of one
// destination, where they used to be a tab and an app-bar bell. (Members
// was a third face for one release and went back to the bar in #707.)
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
  await openAlertsTab(tester);
  return workspace;
}

void main() {
  testWidgets('the alerts (the calendar Alerts view) carry one door to the '
      'messenger in Me', (tester) async {
    await pumpInbox(tester);

    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-messenger-door')), findsOneWidget);
    // Discussions are not here any more: no chat list, no compose button.
    expect(find.byKey(const ValueKey('new-conversation')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-tab-chats')), findsNothing);
  });

  testWidgets('the door leads to the messenger of the Me space and carries '
      'the unread count', (tester) async {
    await pumpInbox(tester, conversations: [
      Conversation(
        id: 'conv-ana',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'See you at ten',
        unread: 2,
        lastAt: DateTime.utc(2026, 8, 27),
      ),
    ]);
    expect(find.byKey(const ValueKey('conversation-conv-ana')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('inbox-messenger-door')));
    await tester.pumpAndSettle();
    expect(
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .state
          .uri
          .toString(),
      startsWith('/me'),
    );
    expect(find.byKey(const ValueKey('unified-inbox')), findsOneWidget);
  });

  testWidgets('the alerts face stays INSIDE the shell — the bar never goes '
      'away', (tester) async {
    await pumpInbox(tester);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('alerts off: no alerts face, the door to the messenger stays',
      (tester) async {
    await pumpInbox(tester, featureFlags: const {'eventsTab': false});

    expect(find.byKey(const ValueKey('inbox-tab-alerts')), findsNothing);
    expect(find.byKey(const ValueKey('inbox-messenger-door')), findsOneWidget);
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
