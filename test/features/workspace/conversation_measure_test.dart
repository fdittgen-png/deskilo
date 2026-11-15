// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4060 — a conversation keeps the reading measure: a bubble is never wider
// than the reading column, at desk width the composer's attach menu, field and
// send are one row (on a phone the field stands above them), and the desk's
// top bar names the person the conversation is with.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/ui/adaptive/page_measures.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/widgets/conversation_thread.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

FakeWorkspaceRepository _workspace({Map<String, dynamic>? flags}) {
  final workspace =
      FakeWorkspaceRepository.withWorkspace(featureFlags: flags ?? const {})
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
        ..conversations.add(
          Conversation(
            id: 'c1',
            kind: ConversationKind.direct,
            otherMemberId: 'member-2',
            lastBody: 'hello',
            lastAt: DateTime.utc(2026, 9, 1, 9),
          ),
        );
  workspace.conversationMessages['c1'] = [
    MemberNote(
      id: 'n1',
      workspaceId: 'ws-1',
      fromMemberId: 'member-2',
      toMemberId: 'member-1',
      body: List.filled(120, 'a long line of words').join(' '),
      createdAt: DateTime.utc(2026, 9, 1, 9),
      conversationId: 'c1',
    ),
  ];
  return workspace;
}

Future<void> _pumpThread(WidgetTester tester, Size size) async {
  await pumpApp(
    tester,
    const Scaffold(body: ConversationThread(conversationId: 'c1')),
    size: size,
    overrides: standardTestOverrides(workspace: _workspace()),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the conversation page is declared in the reading measure', () {
    expect(measureOf('/conversation/c1'), PageMeasure.reading);
  });

  testWidgets('at 1440 a bubble is at most the reading column wide', (
    tester,
  ) async {
    await _pumpThread(tester, const Size(1440, 900));
    final bubble = tester.getSize(_k('bubble-n1'));
    expect(bubble.width, lessThanOrEqualTo(kReadingColumnWidth));
    expect(bubble.width, greaterThan(300), reason: 'a long message fills it');
  });

  testWidgets('at 390 a bubble keeps its share of the phone', (tester) async {
    await _pumpThread(tester, const Size(390, 800));
    expect(
      tester.getSize(_k('bubble-n1')).width,
      lessThanOrEqualTo(390 * 0.78),
    );
  });

  testWidgets('at 1440 attach, the field and send are one row', (tester) async {
    await _pumpThread(tester, const Size(1440, 900));
    final attach = tester.getRect(_k('composer-attach'));
    final field = tester.getRect(_k('member-note-body'));
    final send = tester.getRect(_k('member-note-send'));
    expect(attach.right, lessThanOrEqualTo(field.left + 1));
    expect(field.right, lessThanOrEqualTo(send.left + 1));
    expect(
      attach.top,
      lessThan(field.bottom),
      reason: 'the attach button is beside the field, not under it',
    );
    expect(send.top, lessThan(field.bottom));
  });

  testWidgets('at 390 the field stands above the controls, which stay '
      'reachable', (tester) async {
    await _pumpThread(tester, const Size(390, 800));
    final field = tester.getRect(_k('member-note-body'));
    final send = tester.getRect(_k('member-note-send'));
    expect(send.top, greaterThanOrEqualTo(field.bottom - 1));
    expect(send.bottom, lessThanOrEqualTo(800));
    expect(send.width, greaterThanOrEqualTo(kMinInteractiveDimension));
  });

  testWidgets('the desk\'s top bar names the person at 1440', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // Every feature but filming mode, which invents the people's names.
    final features = WorkspaceFeature.values.toSet()
      ..remove(WorkspaceFeature.recordingPrivacy);
    final flags = {for (final f in features) f.name: true};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(workspace: _workspace(flags: flags)),
          enabledFeaturesSyncProvider.overrideWithValue(features),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(DeskiloApp)),
    ).read(routerProvider).go('/conversation/c1');
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: _k('desk-breadcrumb'), matching: find.text('Ana')),
      findsOneWidget,
    );
  });
}
