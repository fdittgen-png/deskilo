// SPDX-License-Identifier: AGPL-3.0-or-later
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
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/presentation/screens/attention_screen.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

final _now = DateTime.utc(2026, 9, 19, 12);

// Each kind carries a different event so the rendered order is readable
// off the titles.
const _subjectOf = {
  AttentionKind.money: 'service_charge',
  AttentionKind.person: 'member_join',
  AttentionKind.month: 'expense',
  AttentionKind.instance: 'payment',
  AttentionKind.configuration: 'reservation',
};

Attention _item(AttentionKind kind, {int days = 0, int count = 1}) => Attention(
      kind: kind,
      subject: _subjectOf[kind]!,
      action: AttentionAction.decide,
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
        .map((t) => (t.title! as Text).data)
        .toList();

    expect(rows, ['Decide: Service', 'Decide: Expense', 'Decide: Reservation'],
        reason: 'by what the delay costs — cash first, then a month that '
            'closes, then configuration that is not doing what it says');
  });

  testWidgets('one line stands for a whole decision', (tester) async {
    await _pump(tester, [
      Attention(
        kind: AttentionKind.month,
        subject: 'invoicing',
        action: AttentionAction.issue,
        waitingSince: _now,
        count: 7,
      ),
    ]);

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

  testWidgets('every line reads as a sentence, never as a wire word', (
    tester,
  ) async {
    // #2326: the demo showed `decide` / `service_charge` and `admit` /
    // `members`. Each action, and each event type, must reach a label.
    await _pump(tester, [
      Attention(
        kind: AttentionKind.person,
        subject: 'members',
        action: AttentionAction.admit,
        waitingSince: _now,
        count: 2,
      ),
      Attention(
        kind: AttentionKind.month,
        subject: 'invoicing',
        action: AttentionAction.issue,
        waitingSince: _now,
        count: 3,
      ),
      _item(AttentionKind.money),
    ]);

    final texts = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .expand((t) => [(t.title! as Text).data!, (t.subtitle! as Text).data!])
        .toList();
    expect(texts, contains('Admit 2 people asking to join'));
    expect(texts, contains('Invoice 3 members for the month'));
    expect(texts, contains('Decide: Service'));
    for (final text in texts) {
      expect(
        text,
        isNot(matches(RegExp(r'\b[a-z]+_[a-z_]+\b'))),
        reason: 'snake_case is a wire word: $text',
      );
      expect(
        text,
        isNot(matches(RegExp(r'\b[a-z]+[A-Z][A-Za-z]*\b'))),
        reason: 'camelCase is an enum name: $text',
      );
    }
  });

  test('every event type has a label of its own', () {
    // A new EventType without a label would print its wire name on this
    // surface; the switch is exhaustive, and this proves no arm falls
    // back to the name.
    for (final type in EventType.values) {
      final label = eventTypeLabel(null, type);
      expect(label, isNot(type.dbName), reason: type.name);
      expect(label, isNot(type.name), reason: type.name);
      expect(label, isNot(contains('_')), reason: type.name);
    }
  });

  testWidgets('a tap opens the screen where the decision is made', (
    tester,
  ) async {
    final opened = <String>[];
    final router = GoRouter(
      initialLocation: '/attention',
      routes: [
        GoRoute(
          path: '/attention',
          builder: (context, state) => const AttentionScreen(),
        ),
        for (final path in ['/events', '/members', '/invoicing/wizard'])
          GoRoute(
            path: path,
            builder: (context, state) {
              opened.add(path);
              return const Scaffold();
            },
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(),
          attentionProvider.overrideWith(
            (ref) async => [
              Attention(
                kind: AttentionKind.person,
                subject: 'members',
                action: AttentionAction.admit,
                waitingSince: _now,
              ),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(opened, ['/members']);
    expect(attentionRoute(AttentionAction.decide), '/events');
    expect(attentionRoute(AttentionAction.issue), '/invoicing/wizard');
  });
}
