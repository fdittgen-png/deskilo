// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4055 — in the Alerts view a decision's sentence wraps, never cut: the
// cut-text guard walks the Demo's own decisions at 320 and 390 px wide,
// with text at 1.0 and 1.3, the Alerts opened from the one "Decisions" row.
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart' show pumpDemo;
import 'experience_guards.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  for (final width in const [320.0, 390.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('at ${width.toInt()} px and text $scale a decision in '
          'Alerts is never cut', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpDemo(tester, openHub: false, size: Size(width, 844));
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(routerProvider)
            .go('/calendar');
        await _settle(tester);
        final entry = find.byKey(const ValueKey('calendar-decisions-entry'));
        expect(entry, findsOneWidget, reason: 'the Demo has decisions');
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await _settle(tester);
        expect(
          find.byKey(const ValueKey('pending-decisions'), skipOffstage: false),
          findsOneWidget,
          reason: 'the decisions are in the Alerts view',
        );
        // A decision's sentence has no line limit and no ellipsis: it wraps
        // however long it is (the Demo's own fit in two lines).
        final texts = tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(
              const ValueKey('pending-decisions'),
              skipOffstage: false,
            ),
            matching: find.byType(Text, skipOffstage: false),
          ),
        );
        expect(texts, isNotEmpty);
        for (final t in texts) {
          expect(t.maxLines, isNull, reason: '${t.data}');
          expect(t.overflow, isNot(TextOverflow.ellipsis), reason: '${t.data}');
        }
        final details = <String>[];
        expect(
          cutInformationProblems(details: details),
          isEmpty,
          reason: details.join('\n'),
        );
      });
    }
  }
}
