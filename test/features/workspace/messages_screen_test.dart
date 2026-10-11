// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #687 / #702 — the workspace conversation THREAD, the one every surface
// opens. The list that once led to it is gone (#2383): discussions are
// listed in the Me messenger (`unified_inbox_test.dart`), and the thread's
// behaviour is driven in `messages_hub_test.dart` and
// `member_note_flow_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the pieces the widget tree cannot show', () {
    test('ONE thread serves every surface (#702)', () {
      // There were two: this one, by conversation id, and an older sheet
      // that rebuilt a 1:1 thread by filtering every note the viewer
      // could see. They did not just look different — they marked READ
      // by different mechanisms, so a conversation read from a member's
      // profile stayed bold in the inbox with its badge intact.
      expect(
        File('lib/features/workspace/presentation/widgets/'
                'conversation_sheet.dart')
            .existsSync(),
        isFalse,
        reason: 'the second thread implementation is gone, not just unused',
      );
      final thread = File('lib/features/workspace/presentation/widgets/'
              'conversation_thread.dart')
          .readAsStringSync();
      expect(thread, contains('ConversationBubble('));
      // Every entry point that used to open the old sheet now resolves a
      // conversation id first.
      for (final path in const [
        'lib/features/members/presentation/screens/directory_screen.dart',
        'lib/features/events/presentation/widgets/note_row.dart',
        'lib/features/workspace/presentation/screens/members_screen.dart',
        'lib/features/workspace/presentation/widgets/member_note_sheet.dart',
        'lib/features/reservations/presentation/widgets/message_reserver.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('openDirectConversation('), reason: path);
        expect(source, isNot(contains('showConversationSheet(')), reason: path);
      }
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
  });
}
