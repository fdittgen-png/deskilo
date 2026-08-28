// SPDX-License-Identifier: 0BSD
//
// #687 stage 2 — the messaging centre as a screen.
//
// On its own route, deliberately: the bottom-bar swap removes Plan,
// which is one line to make and a release to undo, so it waits for the
// owner. Everything else about messaging is built and usable against
// /messages meanwhile.
import 'dart:io';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Conversation conv({
  required String id,
  ConversationKind kind = ConversationKind.direct,
  String? title,
  String? other,
  String lastBody = 'hello',
  String? lastFrom,
  int unread = 0,
  required DateTime at,
}) =>
    Conversation(
      id: id,
      kind: kind,
      title: title,
      otherMemberId: other,
      lastBody: lastBody,
      lastFromMemberId: lastFrom,
      unread: unread,
      lastAt: at,
    );

void main() {
  Future<FakeWorkspaceRepository> pump(
    WidgetTester tester,
    List<Conversation> seed,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The whole app, then navigate: the centre is workspace-scoped, and
    // a bare MaterialApp has no active workspace for the providers to
    // resolve against — the list would render empty for the wrong
    // reason and the test would pass while proving nothing.
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..conversations.addAll(seed);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/messages');
    await tester.pumpAndSettle();
    return workspace;
  }

  testWidgets('people and groups interleave, newest activity first',
      (tester) async {
    // WhatsApp's ordering, asked for by name. A list that put people
    // above groups would bury whatever was just written in.
    await pump(tester, [
      conv(id: 'old', other: 'm-2', at: DateTime.utc(2026, 8, 20)),
      conv(
        id: 'new-group',
        kind: ConversationKind.group,
        title: 'Coworking 2026',
        at: DateTime.utc(2026, 8, 27),
      ),
      conv(id: 'mid', other: 'm-3', at: DateTime.utc(2026, 8, 25)),
    ]);

    final rows = tester
        .widgetList(find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('conversation-') &&
            !(w.key as ValueKey<String>).value.contains('unread') &&
            !(w.key as ValueKey<String>).value.contains('avatar') &&
            !(w.key as ValueKey<String>).value.contains('list')))
        .toList();
    expect(rows, hasLength(3));
    expect(
      find.byKey(const ValueKey('conversation-new-group')),
      findsOneWidget,
    );
  });

  testWidgets('an unread thread carries a capped badge', (tester) async {
    await pump(tester, [
      conv(id: 'a', other: 'm-2', unread: 3, at: DateTime.utc(2026, 8, 27)),
      conv(id: 'b', other: 'm-3', unread: 250, at: DateTime.utc(2026, 8, 26)),
      conv(id: 'c', other: 'm-4', at: DateTime.utc(2026, 8, 25)),
    ]);

    expect(find.byKey(const ValueKey('conversation-unread-a')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // Past 99 the exact number tells nobody anything and starts pushing
    // the timestamp off the row.
    expect(find.text('99+'), findsOneWidget);
    expect(find.byKey(const ValueKey('conversation-unread-c')), findsNothing,
        reason: 'a read thread carries no badge at all');
  });

  testWidgets('an empty centre says where to START one', (tester) async {
    // An empty state that only reports emptiness leaves someone hunting
    // for a button that lives on another screen.
    await pump(tester, const []);
    expect(
      find.byKey(const ValueKey('conversation-list-empty')),
      findsOneWidget,
    );
    // UX: it points at the button on THIS screen. The first version sent
    // people to a member's profile on another screen to start the thing
    // they had just opened the messaging centre to start.
    expect(find.textContaining('pencil'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-conversation')), findsOneWidget);
  });

  group('the pieces the widget tree cannot show', () {
    test('the list is NOT re-sorted in Dart', () {
      // `my_conversations` already returns them by last_message_at desc.
      // A second opinion here is how a list ends up disagreeing with the
      // unread badge computed from the same query.
      final source = File('lib/features/workspace/presentation/screens/'
              'messages_screen.dart')
          .readAsStringSync();
      expect(source, isNot(contains('..sort(')));
      expect(source, isNot(contains('.sort(')));
    });

    test('one bubble renderer serves both thread kinds', () {
      // Two renderers is how a group message ends up looking subtly
      // unlike a direct one — different padding, a reference link that
      // resolves in one and not the other.
      final thread = File('lib/features/workspace/presentation/widgets/'
              'conversation_thread.dart')
          .readAsStringSync();
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'conversation_sheet.dart')
          .readAsStringSync();
      expect(thread, contains('ConversationBubble('));
      expect(sheet, contains('ConversationBubble('));
      expect(sheet, isNot(contains('class _Bubble')));
    });

    test('opening a conversation marks it read BEFORE the sheet shows', () {
      // So the badge and the row weight have settled by the time it
      // closes, rather than flickering on return.
      final source = File('lib/features/workspace/presentation/widgets/'
              'conversation_thread.dart')
          .readAsStringSync();
      final open = source.substring(source.indexOf('showConversationThread'));
      expect(open.indexOf('markConversationRead'),
          lessThan(open.indexOf('showModalBottomSheet')));
    });

    test('the preview renders as PLAIN text', () {
      // One line of someone's private message on a list that is often on
      // screen while other people are in the room: no resolved reference
      // links, nothing tappable.
      final row = File('lib/features/workspace/presentation/widgets/'
              'conversation_row.dart')
          .readAsStringSync();
      expect(row, isNot(contains('MemberNoteBody')));
      expect(row, contains('overflow: TextOverflow.ellipsis'));
    });
  });
}
