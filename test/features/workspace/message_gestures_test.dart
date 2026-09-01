// SPDX-License-Identifier: 0BSD
//
// #798 — the two swipes on a message everyone already knows from their
// phone: RIGHT quotes it into the reply, LEFT takes it back while it is
// still unread.
//
// The read stamp is the whole rule for the second one. Once someone has
// read a message, the words have landed; a delete then only hides the
// evidence from one side of a conversation the other still remembers.
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/member_note_refs.dart';
import 'package:deskilo/features/workspace/presentation/widgets/conversation_thread.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

MemberNote note({
  required String id,
  String from = 'member-1',
  String? to = 'member-2',
  String body = 'hello',
  DateTime? readAt,
}) =>
    MemberNote(
      id: id,
      workspaceId: 'ws-1',
      fromMemberId: from,
      toMemberId: to,
      body: body,
      createdAt: DateTime.utc(2026, 9, 1, 9),
      readAt: readAt,
      conversationId: 'c1',
    );

Future<FakeWorkspaceRepository> pumpThread(
  WidgetTester tester,
  List<MemberNote> messages, {
  bool gestures = true,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: gestures ? const {} : const {'messageGestures': false},
  )
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..conversations.add(Conversation(
      id: 'c1',
      kind: ConversationKind.direct,
      otherMemberId: 'member-2',
      lastBody: 'hello',
      lastAt: DateTime.utc(2026, 9, 1, 9),
    ));
  workspace.conversationMessages['c1'] = [...messages];
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const MaterialApp(
        home: Scaffold(body: ConversationThread(conversationId: 'c1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return workspace;
}

Future<void> swipe(WidgetTester tester, String noteId, double dx) async {
  await tester.drag(find.byKey(ValueKey('swipe-$noteId')), Offset(dx, 0));
  await tester.pumpAndSettle();
}

void main() {
  group('the quote token', () {
    test('round-trips through the body grammar', () {
      final body = '${quoteToken('note-1', 'the original')}\nmy answer';
      final split = splitLeadingQuote(body);
      expect(split.quote?.id, 'note-1');
      expect(split.quote?.preview, 'the original');
      expect(split.rest, 'my answer');
    });

    test('a long quote is trimmed to one line so it cannot swallow the '
        'reply', () {
      final token = quoteToken('note-1', 'a' * 200);
      expect(token.length, lessThan(120));
      expect(token, contains('…'));
      expect(quoteToken('note-1', 'two\nlines'), contains('two lines'));
    });

    test('the inbox preview shows the REPLY, not the quoted message', () {
      final body = '${quoteToken('note-1', 'what time?')}\nat nine';
      // Every chat app's list shows what this message says. Repeating
      // the quoted line would make a thread of replies unreadable.
      expect(notePreview(body), 'at nine');
    });

    test('a body with no quote is untouched', () {
      final split = splitLeadingQuote('just text');
      expect(split.quote, isNull);
      expect(split.rest, 'just text');
    });
  });

  testWidgets('swiping right quotes the message into the composer, and the '
      'sent body carries the quote', (tester) async {
    final workspace = await pumpThread(tester, [
      note(id: 'note-1', from: 'member-2', to: 'member-1', body: 'what time?'),
    ]);

    await swipe(tester, 'note-1', 250);
    expect(find.byKey(const ValueKey('composer-quote')), findsOneWidget);
    expect(find.text('what time?'), findsWidgets);

    await tester.enterText(
        find.byKey(const ValueKey('member-note-body')), 'at nine');
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();

    expect(workspace.sentMessages.single.body,
        '${quoteToken('note-1', 'what time?')}\nat nine');
    // The chip clears once the reply is gone.
    expect(find.byKey(const ValueKey('composer-quote')), findsNothing);
  });

  testWidgets('the quote chip can be cancelled without sending',
      (tester) async {
    await pumpThread(tester, [note(id: 'note-1', body: 'hello')]);
    await swipe(tester, 'note-1', 250);
    expect(find.byKey(const ValueKey('composer-quote')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('composer-quote-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-quote')), findsNothing);
  });

  testWidgets('swiping left takes back MY UNREAD message, after confirming',
      (tester) async {
    final workspace = await pumpThread(tester, [note(id: 'note-1')]);

    await swipe(tester, 'note-1', -400);
    // Destructive: it asks first, every path.
    expect(find.byKey(const ValueKey('note-delete-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();

    expect(workspace.deletedNotes, ['note-1']);
    expect(workspace.conversationMessages['c1'], isEmpty);
  });

  testWidgets('cancelling the confirmation keeps the message', (tester) async {
    final workspace = await pumpThread(tester, [note(id: 'note-1')]);
    await swipe(tester, 'note-1', -400);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workspace.deletedNotes, isEmpty);
  });

  testWidgets('a READ message cannot be taken back, and says why',
      (tester) async {
    final workspace = await pumpThread(tester, [
      note(id: 'note-1', readAt: DateTime.utc(2026, 9, 1, 10)),
    ]);

    await swipe(tester, 'note-1', -400);
    expect(find.byKey(const ValueKey('note-delete-confirm')), findsNothing);
    expect(find.textContaining('no longer be taken back'), findsOneWidget);
    expect(workspace.deletedNotes, isEmpty);
  });

  testWidgets("someone ELSE's message cannot be taken back", (tester) async {
    final workspace = await pumpThread(tester, [
      note(id: 'note-1', from: 'member-2', to: 'member-1'),
    ]);

    await swipe(tester, 'note-1', -400);
    expect(find.textContaining('Only the sender'), findsOneWidget);
    expect(workspace.deletedNotes, isEmpty);
  });

  testWidgets('with the feature off the bubble does not swipe at all',
      (tester) async {
    await pumpThread(tester, [note(id: 'note-1')], gestures: false);
    expect(find.byKey(const ValueKey('swipe-note-1')), findsNothing);
    // The historical long-press delete is still there.
    expect(find.byKey(const ValueKey('bubble-note-1')), findsOneWidget);
  });
}
