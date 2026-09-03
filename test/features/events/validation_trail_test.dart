// SPDX-License-Identifier: 0BSD
//
// #841 — the trail says who decided, in what order, and when. It is the
// same widget on an alert and on the document that raised it, so the two
// can never drift apart.
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/presentation/widgets/validation_trail.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EventDecision _d(String id, String member, bool accept, int minute) =>
    EventDecision(
      id: id,
      eventId: 'evt-1',
      memberId: member,
      accept: accept,
      decidedBySystem: false,
      decidedAt: DateTime.utc(2026, 3, 12, 14, minute),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<EventDecision> decisions,
  int requiredCount = 1,
  bool pending = false,
  bool sequential = false,
  String? title,
}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ValidationTrail(
        decisions: decisions,
        names: const {'m1': 'Ana', 'm2': 'Bo'},
        requiredCount: requiredCount,
        pending: pending,
        sequential: sequential,
        title: title,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('decisions are numbered in the order they happened, however '
      'they arrive', (tester) async {
    // Deliberately out of order: the trail must not trust its caller.
    await _pump(tester, decisions: [
      _d('d2', 'm2', false, 40),
      _d('d1', 'm1', true, 10),
    ]);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(texts, contains('1.'));
    expect(texts, contains('2.'));
    // Ana accepted first, Bo declined after her.
    final anaAt = texts.indexWhere((t) => t.contains('Ana'));
    final boAt = texts.indexWhere((t) => t.contains('Bo'));
    expect(anaAt, lessThan(boAt));
    expect(texts.any((t) => t.startsWith('Validated by Ana')), isTrue);
    expect(texts.any((t) => t.startsWith('Declined by Bo')), isTrue);
  });

  testWidgets('a pending event says how many validations it still owes',
      (tester) async {
    await _pump(tester,
        decisions: [_d('d1', 'm1', true, 10)],
        requiredCount: 3,
        pending: true);
    expect(find.byKey(const Key('validation-trail-awaiting')), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('nothing decided yet, and nothing pending, renders nothing',
      (tester) async {
    await _pump(tester, decisions: const []);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('nothing decided yet on a pending event says so', (tester) async {
    await _pump(tester, decisions: const [], pending: true);
    expect(find.byKey(const Key('validation-trail-none')), findsOneWidget);
    expect(find.byKey(const Key('validation-trail-awaiting')), findsOneWidget);
  });

  testWidgets('a chained rule labels steps instead of numbering peers',
      (tester) async {
    await _pump(tester,
        decisions: [_d('d1', 'm1', true, 10)], sequential: true);
    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('1.'), findsNothing);
  });

  testWidgets('a system decision names the system, not an empty person',
      (tester) async {
    await _pump(tester, decisions: [
      EventDecision(
        id: 'd1',
        eventId: 'evt-1',
        memberId: null,
        accept: true,
        decidedBySystem: true,
        decidedAt: DateTime.utc(2026, 3, 12, 14, 5),
      ),
    ]);
    expect(find.textContaining('System'), findsOneWidget);
  });

  testWidgets('on a document the trail carries its own heading',
      (tester) async {
    await _pump(tester,
        decisions: [_d('d1', 'm1', true, 10)], title: 'Validation trail');
    expect(find.text('Validation trail'), findsOneWidget);
  });
}
