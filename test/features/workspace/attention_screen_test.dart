// SPDX-License-Identifier: 0BSD
//
// #1247 — the decision surface, as a person meets it.
//
// The ranking itself is pinned on plain Dart in
// `attention_ranking_test.dart`; this is the screen: that the order
// survives to the list, that the empty state is an ANSWER rather than
// an empty list, and that one line stands for a whole decision.
//
// The flag is Platform and OFF by default, so these switch it on
// explicitly — which is also the proof that a space which never asked
// for the surface does not get one.
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/presentation/screens/attention_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

final _now = DateTime.utc(2026, 9, 19, 12);

Attention _item(AttentionKind kind, {int days = 0, int count = 1}) => Attention(
      kind: kind,
      subject: kind.name,
      decision: 'decide ${kind.name}',
      waitingSince: _now.subtract(Duration(days: days)),
      count: count,
    );

Future<void> _pump(WidgetTester tester, List<Attention> items) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        // The ranking is the provider's job and is tested there; the
        // screen is handed a settled list so its own behaviour is what
        // fails when something here breaks.
        attentionProvider.overrideWith((ref) async => rankAttention(items)),
      ],
      child: const MaterialApp(home: AttentionScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nothing waiting is an answer, not an empty list',
      (tester) async {
    await _pump(tester, const []);

    expect(find.byKey(AttentionScreen.emptyKey), findsOneWidget);
    expect(find.text('Nothing needs you'), findsOneWidget);
    expect(find.byKey(AttentionScreen.listKey), findsNothing,
        reason: 'an empty list leaves a person to work out whether it is '
            'empty because everything is done or because something '
            'failed');
  });

  testWidgets('the order a person meets them is the ranked order',
      (tester) async {
    // Handed in backwards, so a screen that ignored the ranking would
    // show them backwards.
    await _pump(tester, [
      _item(AttentionKind.configuration),
      _item(AttentionKind.month),
      _item(AttentionKind.money),
    ]);

    final rows = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.subtitle! as Text).data)
        .toList();

    expect(rows, ['money', 'month', 'configuration'],
        reason: 'by what the delay costs — cash first, then a month that '
            'closes, then configuration that is not doing what it says');
  });

  testWidgets('one line stands for a whole decision', (tester) async {
    await _pump(tester, [_item(AttentionKind.month, count: 7)]);

    expect(find.byType(ListTile), findsOneWidget,
        reason: 'issue for 7 members is ONE decision, not seven lines');
    expect(find.textContaining('7'), findsOneWidget);
  });

  testWidgets('nothing on it is a number nobody can act on',
      (tester) async {
    // The rule the design turns on: occupancy, balances and unread
    // counts stay on the screens that own them. The surface has no way
    // to show them — there is no kind for them — and this is the
    // assertion that says so out loud.
    expect(
      AttentionKind.values.map((k) => k.name),
      ['money', 'person', 'month', 'instance', 'configuration'],
      reason: 'five kinds, each of them something somebody must decide '
          'or act on. A sixth for "information" is the change this test '
          'exists to make somebody argue for',
    );
  });
}
