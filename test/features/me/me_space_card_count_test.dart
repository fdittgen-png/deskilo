// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4071 — a business's row on Me says what its count counts: in words beside
// the label from the desk's width, to a screen reader everywhere, and the
// row's height does not depend on whether the business has a test side.
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _phone = Size(390, 1800);
const _desk = Size(1440, 1200);

/// ws-1 (production) and ws-2 (its test side) are one business; ws-3 is a
/// production-only one.
FakeWorkspaceRepository _spaces() {
  final repo = twoSpaces(serverDefault: null);
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    environment: 'prod',
    pairId: 'pair-1',
  );
  repo.workspaces[1] = repo.workspaces[1].copyWith(
    environment: 'dev',
    pairId: 'pair-1',
  );
  repo.workspaces.add(
    repo.workspaces[0].copyWith(
      id: 'ws-3',
      name: 'Third Space',
      pairId: '',
      inviteCode: 'THIRD99999',
    ),
  );
  repo.extraMyMemberships.add(
    const Member(
      id: 'member-c',
      workspaceId: 'ws-3',
      userId: 'user-1',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ),
  );
  return repo;
}

Future<void> _open(WidgetTester tester, Size size) async {
  final messenger = FakeMessengerRepository()
    ..inboxRows.add({
      'context_kind': 'space',
      'context_id': 'c1',
      'workspace_id': 'ws-2',
      'unread': 2,
      'last_at': '2026-07-15T08:00:00Z',
    });
  await pumpMeApp(
    tester,
    workspace: _spaces(),
    messenger: messenger,
    size: size,
  );
}

double _height(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).height;

void main() {
  testWidgets('phone: the button names its count to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, _phone);
    final node = tester.getSemantics(
      find.byKey(const ValueKey('me-space-ws-2')),
    );
    expect(node.label, contains('2 notifications wait here'));
    expect(node.label, contains('Test business'));
    // The bare number is not read on its own.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('me-space-badge-ws-2')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('me-space-count-ws-2')), findsNothing);
    handle.dispose();
  });

  testWidgets('desk: the count is written out beside the label', (
    tester,
  ) async {
    await _open(tester, _desk);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('me-space-count-ws-2')))
          .data,
      '2 notifications wait here',
    );
    expect(find.byKey(const ValueKey('me-space-count-ws-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('me-space-count-ws-1')), findsNothing);
    final badge = tester.widget<Badge>(
      find.byKey(const ValueKey('me-space-badge-ws-2')),
    );
    expect(badge.isLabelVisible, isFalse);
  });

  for (final (label, size) in [('390', _phone), ('1440', _desk)]) {
    testWidgets('$label px: a row with a test side and one without are the '
        'same height (side by side), and the detail stays on one line', (
      tester,
    ) async {
      await _open(tester, size);
      // At phone width the two buttons stack when a word would not fit, and
      // the pair is then taller by one button (#4131).
      if (size == _desk) {
        expect(
          _height(tester, 'me-space-pair-pair-1'),
          _height(tester, 'me-space-pair-ws-3'),
        );
      }
      final detail = tester.widget<Text>(find.textContaining('Germany').first);
      expect(detail.maxLines, 1);
    });
  }
}
