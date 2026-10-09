// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — each side of my spaces on Me › Home carries the count of what
// waits for me there, so the app icon's number can be traced to its space
// and environment.
import 'package:deskilo/core/demo/data/messenger_repository.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/me/providers/space_attention_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

Map<String, dynamic> _row(
  String id,
  String workspace,
  int unread, {
  bool muted = false,
}) => {
  'context_kind': 'space',
  'context_id': id,
  'workspace_id': workspace,
  'unread': unread,
  'last_at': '2026-07-15T08:00:00Z',
  if (muted) ...{'pinned': false, 'muted': true, 'archived': false},
};

void main() {
  group('spaceAttention', () {
    final inbox = mergeInboxes({
      '': [
        _row('c1', 'ws-2', 2),
        _row('c2', 'ws-2', 1),
        _row('c3', 'ws-3', 4, muted: true),
        _row('c4', 'ws-1', 5),
      ],
    });

    test('other spaces count their unread conversations, muted ones '
        'stay quiet', () {
      expect(spaceAttention(inbox: inbox), {'ws-2': 3, 'ws-1': 5});
    });

    test('the space I am in shows exactly the app icon count', () {
      expect(spaceAttention(inbox: inbox, activeId: 'ws-1', activeCount: 1), {
        'ws-2': 3,
        'ws-1': 1,
      });
      expect(spaceAttention(inbox: inbox, activeId: 'ws-1'), {'ws-2': 3});
    });
  });

  testWidgets('Me › Home: the count sits on the side it belongs to', (
    tester,
  ) async {
    final messenger = FakeMessengerRepository()
      ..inboxRows.add(_row('c1', 'ws-2', 2));
    await pumpMeApp(
      tester,
      workspace: twoSpaces(serverDefault: null),
      messenger: messenger,
    );

    Badge badge(String id) =>
        tester.widget<Badge>(find.byKey(ValueKey('me-space-badge-$id')));
    expect(badge('ws-2').isLabelVisible, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('me-space-badge-ws-2')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(badge('ws-1').isLabelVisible, isFalse);
  });
}
