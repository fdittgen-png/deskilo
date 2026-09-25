// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: explicit progress and immediate, single-step interaction during motion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_layout_test.dart' show pumpOnboardingLayout;

void main() {
  testWidgets('suggested steps are skipped, not falsely completed', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpOnboardingLayout(tester);
    await tester.enterText(find.byKey(const ValueKey('onboarding-name')), 'Draft');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-use-suggested')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('wizard-progress-overview')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSemantics(find.byKey(const ValueKey('wizard-step-name')))
        .getSemanticsData().value, 'Completed');
    expect(tester.getSemantics(find.byKey(const ValueKey('wizard-step-where')))
        .getSemanticsData().value, 'Skipped — suggested settings');
    await tester.ensureVisible(find.byKey(const ValueKey('wizard-step-name')));
    await tester.tap(find.byKey(const ValueKey('wizard-step-name')));
    await tester.pump();
    expect(tester.widget<TextFormField>(find.byKey(
      const ValueKey('onboarding-name'))).controller!.text, 'Draft');
    semantics.dispose();
  });

  for (final (animations, reduced) in [(true, false), (false, false), (true, true)]) {
    testWidgets('motion=$animations reduced=$reduced: rapid Next/Back keeps one current form', (tester) async {
      await pumpOnboardingLayout(tester, animations: animations, reducedMotion: reduced);
      await tester.enterText(find.byKey(const ValueKey('onboarding-name')), 'Draft');
      await tester.tap(find.byKey(const ValueKey('wizard-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(const ValueKey('onboarding-name')), findsNothing);
      final currency = find.byKey(const ValueKey('onboarding-currency'));
      expect(currency, findsOneWidget);
      expect(tester.widget<EditableText>(find.descendant(of: currency,
        matching: find.byType(EditableText))).focusNode.hasFocus, isTrue);
      await tester.enterText(currency, 'CHF');
      await tester.tap(find.byKey(const ValueKey('wizard-back')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wizard-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<TextFormField>(currency).controller!.text, 'CHF');
      expect(find.byKey(const ValueKey('onboarding-name')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
