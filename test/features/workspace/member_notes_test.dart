// SPDX-License-Identifier: 0BSD
//
// Member notes (#456): a member notifies another member from the member
// sheet; admins broadcast to all admins incl. the owner. The server
// (0089 send_member_note) re-validates everything — these tests pin the
// client affordances and the wire call.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:flutter/material.dart';
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

    test('pins the 500-char cap against migration 0089', () {
      expect(MemberNoteRules.maxLength, 500);
      final sql = File('supabase/migrations/0089_member_notes.sql')
          .readAsStringSync();
      expect(sql, contains('between 1 and 500'));
      expect(sql, contains('send_member_note'));
      expect(sql, contains('only admins may notify all admins'));
    });
  });

  testWidgets('the member sheet offers Send notification and the dialog '
      'sends the note (#456)', (tester) async {
    final workspace = await pumpMembersWithAna(tester);

    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send notification'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('member-note-body')),
      'Your desk lamp is still on!',
    );
    await tester.tap(find.byKey(const ValueKey('member-note-send')));
    await tester.pumpAndSettle();

    expect(workspace.memberNotes.single.toMemberId, 'member-2');
    expect(workspace.memberNotes.single.body, 'Your desk lamp is still on!');
    expect(find.text('Notification sent.'), findsOneWidget);
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

  testWidgets('feature OFF hides every affordance (#456)', (tester) async {
    await pumpMembersWithAna(
      tester,
      featureFlags: const {'memberNotifications': false},
    );

    expect(
        find.byKey(const ValueKey('members-notify-admins')), findsNothing);
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();
    expect(find.text('Send notification'), findsNothing);
  });
}
