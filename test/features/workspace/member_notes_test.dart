// SPDX-License-Identifier: 0BSD
//
// Member notes (#456): a member notifies another member from the member
// sheet; admins broadcast to all admins incl. the owner. The server
// (0089 send_member_note) re-validates everything — these tests pin the
// client affordances and the wire call.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import 'package:deskilo/core/storage/note_seen_store.dart';
import '../../helpers/fake_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'co_owner_test.dart' show pumpMembersWithAna;

void main() {
  group('MemberNote (#456)', () {
    test('round-trips a row; broadcast = null recipient', () {
      final note = MemberNote.fromRow(const {
        'id': 'n1',
        'workspace_id': 'ws-1',
        'from_member_id': 'member-1',
        'to_member_id': null,
        'body': 'Team meeting at 3',
        'created_at': '2026-08-04T12:00:00Z',
      });
      expect(note.isBroadcast, isTrue);
      expect(note.body, 'Team meeting at 3');
    });

    test('read receipts (0105): read_at round-trips; absent = delivered',
        () {
      final read = MemberNote.fromRow(const {
        'id': 'n1',
        'workspace_id': 'ws-1',
        'from_member_id': 'member-1',
        'to_member_id': 'member-2',
        'body': 'hi',
        'created_at': '2026-08-09T12:00:00Z',
        'read_at': '2026-08-09T12:30:00Z',
      });
      expect(read.readAt, DateTime.utc(2026, 8, 9, 12, 30));
      final delivered = MemberNote.fromRow(const {
        'id': 'n2',
        'workspace_id': 'ws-1',
        'from_member_id': 'member-1',
        'to_member_id': 'member-2',
        'body': 'hi',
        'created_at': '2026-08-09T12:00:00Z',
        'read_at': null,
      });
      expect(delivered.readAt, isNull);
    });

    test('pins the read-receipt contract against migration 0105', () {
      final sql = File('supabase/migrations/0105_member_note_read_receipts.sql')
          .readAsStringSync();
      expect(sql, contains('add column read_at'));
      expect(sql, contains('mark_member_notes_read'));
      expect(sql, contains('to_member_id = v_me.id'));
      expect(sql, contains('read_at is null'));
      expect(sql, contains('revoke execute'));
    });

    test('pins the 500-char cap against migration 0089', () {
      expect(MemberNoteRules.maxLength, 500);
      final sql = File('supabase/migrations/0089_member_notes.sql')
          .readAsStringSync();
      expect(sql, contains('between 1 and 500'));
      expect(sql, contains('send_member_note'));
      expect(sql, contains('only admins may notify all admins'));
    });
  });

  testWidgets('the member sheet offers Messages and the CONVERSATION '
      'sends the note (#456, refactor)', (tester) async {
    final workspace = await pumpMembersWithAna(tester);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Your desk lamp is still on!',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();

    expect(workspace.memberNotes.single.toMemberId, 'member-2');
    expect(workspace.memberNotes.single.body, 'Your desk lamp is still on!');
    // The message lands as a bubble in the open thread.
    expect(find.byKey(const ValueKey('bubble-note-1')), findsOneWidget);
  });

  testWidgets('the app bar broadcast sends to ALL admins (null recipient) '
      '(#456)', (tester) async {
    final workspace = await pumpMembersWithAna(tester);

    await tester
        .tap(find.byKey(const ValueKey('members-notify-admins')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Printer is out of toner.',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();

    expect(workspace.memberNotes.single.toMemberId, isNull);
    expect(workspace.memberNotes.single.body, 'Printer is out of toner.');
  });

  testWidgets('the Events screen shows the readable Messages inbox — '
      'received notes with their FULL text, sent notes with their '
      'direction (#460)', (tester) async {
    // Seed BEFORE the pump (the providers cache their first read): a
    // note FROM Ana to me, one from me to Ana, and my broadcast.
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
      )
      ..memberNotes.addAll([
        MemberNote(
          id: 'note-in',
          workspaceId: 'ws-1',
          fromMemberId: 'member-2',
          toMemberId: 'member-1',
          body: 'Your desk lamp is still on!',
          createdAt: DateTime.utc(2026, 8, 4, 9),
        ),
        MemberNote(
          id: 'note-out',
          workspaceId: 'ws-1',
          fromMemberId: 'member-1',
          toMemberId: 'member-2',
          body: 'Thanks, turning it off.',
          createdAt: DateTime.utc(2026, 8, 4, 10),
        ),
        MemberNote(
          id: 'note-cast',
          workspaceId: 'ws-1',
          fromMemberId: 'member-1',
          toMemberId: null,
          body: 'Printer is out of toner.',
          createdAt: DateTime.utc(2026, 8, 4, 11),
        ),
      ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    // #687 — the ADMIN BROADCAST is the one message kind that is still
    // a notification: it is a fan-out to whoever is an admin at read
    // time, not a conversation, so it has no thread to live in and
    // stays on the bell.
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Printer is out of toner.'), findsOneWidget);

    // The one-to-one exchange is NOT here any more — neither the
    // received side nor the sent one. It was the sent side that made
    // this feed an inbox reporting your own outbox.
    expect(find.text('Your desk lamp is still on!'), findsNothing);
    expect(find.text('Thanks, turning it off.'), findsNothing);
  });

  testWidgets('CATCH-UP (#464/#687): a note sent while the app was '
      'closed is announced on next start — WITH the message text — and '
      'does NOT land on the bell', (tester) async {
    final notifications = FakeNotificationService();
    final noteSeen = InMemoryNoteSeenStore();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
      )
      ..memberNotes.add(
        MemberNote(
          id: 'note-offline',
          workspaceId: 'ws-1',
          fromMemberId: 'member-2',
          toMemberId: 'member-1',
          body: 'Your desk lamp is still on!',
          createdAt: DateTime.utc(2026, 8, 4, 9),
        ),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: workspace,
          notifications: notifications,
          noteSeen: noteSeen,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The device announced the note ONCE, with sender AND text.
    expect(notifications.shown, hasLength(1));
    expect(notifications.shown.single.title, 'Message from Ana');
    expect(notifications.shown.single.body, 'Your desk lamp is still on!');
    expect(noteSeen.notified, DateTime.utc(2026, 8, 4, 9));

    // #687 — THE BELL DOES NOT COUNT IT. Messages are not notifications
    // any more: the count belongs to the Messages destination, which is
    // where tapping it leads. A bell that counted them sent people to a
    // feed to find a conversation that was one tab away.
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('1'),
      ),
      findsNothing,
    );

    // The ANNOUNCEMENT is the part that matters and it survives: the
    // device told them, once, with sender and text. Catch-up on next
    // start is why #464 exists, and moving the surface must not lose it.
    expect(notifications.shown, hasLength(1));
  });

  testWidgets('REPLY AND DELETE (#467/#687): the row opens the thread, '
      'the composer sends, a long-press deletes', (tester) async {
    // The swipe gestures lived on the events-inbox row and retired with
    // it: the centre lists CONVERSATIONS, and a swipe there would mean
    // something else. Both capabilities survive — tapping a row opens
    // the thread, long-pressing a bubble deletes the message.
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
      ..otherMembers.add(
        const Member(
          id: 'member-2',
          workspaceId: 'ws-1',
          userId: 'user-2',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
      )
      ..memberNotes.add(
        MemberNote(
          id: 'note-in',
          workspaceId: 'ws-1',
          fromMemberId: 'member-2',
          toMemberId: 'member-1',
          body: 'Lamp is on.',
          createdAt: DateTime.utc(2026, 8, 4, 9),
        ),
      );
    workspace
      ..conversationMessages['conv-ana'] = [...workspace.memberNotes]
      ..conversations.add(Conversation(
        id: 'conv-ana',
        kind: ConversationKind.direct,
        otherMemberId: 'member-2',
        lastBody: 'Lamp is on.',
        lastFromMemberId: 'member-2',
        lastAt: DateTime.utc(2026, 8, 4, 9),
        unread: 1,
      ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tapNavIcon(tester, Icons.forum_outlined);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('conversation-conv-ana')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conversation-thread')), findsOneWidget);

    // Reply from the thread's own composer.
    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Turning it off now.',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    expect(workspace.sentMessages.single.body, 'Turning it off now.');

    // And a long-press deletes the received one, confirmed (#523).
    await tester.longPress(find.byKey(const ValueKey('bubble-note-in')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes.where((n) => n.id == 'note-in'), isEmpty);
  });

  testWidgets('feature OFF hides every affordance (#456)', (tester) async {
    await pumpMembersWithAna(
      tester,
      featureFlags: const {'memberNotifications': false},
    );

    expect(
        find.byKey(const ValueKey('members-notify-admins')), findsNothing);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Messages'), findsNothing);
  });
}
