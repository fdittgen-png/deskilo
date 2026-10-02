// SPDX-License-Identifier: AGPL-3.0-or-later
// #1653: real create fields and actions stay reachable with constrained space.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/onboarding_layout.dart';

void main() {
  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale: large text, keyboard, editable draft and Next/Back', (tester) async {
      await pumpOnboardingLayout(tester, scale: 2, locale: locale, keyboard: 260);
      final name = find.byKey(const ValueKey('onboarding-name'));
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Independent expected name');
      final next = find.byKey(const ValueKey('wizard-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-currency')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final back = find.byKey(const ValueKey('wizard-back'));
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pump();
      expect(tester.widget<TextFormField>(name).controller!.text,
        'Independent expected name');
      expect(tester.takeException(), isNull);
    });
  }
  for (final size in [const Size(740, 320), const Size(1200, 800)]) {
    testWidgets('$size: error, field and primary action can be reached', (tester) async {
      await pumpOnboardingLayout(tester, size: size);
      final next = find.byKey(const ValueKey('wizard-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      final name = find.byKey(const ValueKey('onboarding-name'));
      expect(tester.widget<EditableText>(find.descendant(of: name,
        matching: find.byType(EditableText))).focusNode.hasFocus, isTrue);
      await tester.ensureVisible(name);
      await tester.enterText(name, 'My space');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.byKey(const ValueKey('onboarding-timezone')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
