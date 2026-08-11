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
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../helpers/mock_providers.dart';
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
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    // Received: sender named, text fully readable.
    expect(find.text('Message from Ana'), findsOneWidget);
    expect(find.text('Your desk lamp is still on!'), findsOneWidget);
    // Sent: direction visible, text too — the sender can verify what
    // went out.
    expect(find.text('To Ana'), findsOneWidget);
    expect(find.text('Thanks, turning it off.'), findsOneWidget);
    expect(find.text('To all admins'), findsOneWidget);
    expect(find.text('Printer is out of toner.'), findsOneWidget);
  });

  testWidgets('CATCH-UP (#464): a note sent while the app was closed is '
      'announced on next start — WITH the message text — and counts on '
      'the bell until Events is opened', (tester) async {
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

    // The bell counts it as unread…
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // …opening Events shows it (and stamps the broadcast-seen store)
    // but a DIRECT note stays unread until its CONVERSATION opens
    // (#539) — the bell keeps counting it.
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();
    expect(find.text('Your desk lamp is still on!'), findsOneWidget);
    expect(noteSeen.seen, DateTime.utc(2026, 8, 4, 9));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );

    // Opening the conversation reads it — NOW the bell clears.
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-dismiss-note-offline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byTooltip('Events'),
        matching: find.text('1'),
      ),
      findsNothing,
    );
    // And it is never announced twice.
    expect(notifications.shown, hasLength(1));
  });

  testWidgets('SWIPE (#467): left deletes a received note; right opens '
      'the CONVERSATION with the sender (refactor)', (tester) async {
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Events'));
    await tester.pumpAndSettle();

    // Swipe RIGHT → Ana's CONVERSATION opens; the row never dismisses.
    await tester.drag(
      find.byKey(const ValueKey('note-dismiss-note-in')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('conversation-sheet')), findsOneWidget);
    // Her message reads IN FULL as a bubble of the thread.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('conversation-sheet')),
            matching: find.text('Lamp is on.', findRichText: true)),
        findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Turning it off now.',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();
    expect(workspace.memberNotes.last.toMemberId, 'member-2');
    expect(workspace.memberNotes.last.body, 'Turning it off now.');
    // Close the thread to get back to the inbox rows.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Swipe LEFT → confirmation first (#523), then the note is deleted.
    await tester.drag(
      find.byKey(const ValueKey('note-dismiss-note-in')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Message deleted.'), findsOneWidget);
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
