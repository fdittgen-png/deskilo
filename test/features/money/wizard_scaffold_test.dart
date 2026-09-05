// SPDX-License-Identifier: 0BSD
//
// #872 — the one wizard chrome every guided invoicing flow runs in:
// numbered steps, Back disabled on the first, Next until the last, then
// Finish (or nothing, when the last step brings its own action).
import 'package:deskilo/features/money/presentation/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const steps = <WizardStepSpec>[
    (name: 'one', label: 'One'),
    (name: 'two', label: 'Two'),
    (name: 'three', label: 'Three'),
  ];

  testWidgets('steps, back, next and finish behave as one idiom',
      (tester) async {
    var index = 0;
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => WizardScaffold(
          title: 'Assistant',
          steps: steps,
          index: index,
          body: Text('step $index'),
          onStepTap: (i) => setState(() => index = i),
          onBack: () => setState(() => index--),
          onNext: () => setState(() => index++),
          onFinish: () => finished = true,
          finishLabel: 'Book',
        ),
      ),
    ));
    for (final s in steps) {
      expect(find.byKey(ValueKey('wizard-step-${s.name}')), findsOneWidget);
    }
    expect(
        tester.widget<TextButton>(find.byKey(const ValueKey('wizard-back'))).onPressed,
        isNull,
        reason: 'nowhere to go back to on the first step');
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('step 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-step-three')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wizard-next')), findsNothing);
    expect(find.text('Book'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-finish')));
    expect(finished, isTrue);
    await tester.tap(find.byKey(const ValueKey('wizard-back')));
    await tester.pumpAndSettle();
    expect(find.text('step 1'), findsOneWidget);
  });

  testWidgets('a disabled Next keeps the person on the step; no Finish when '
      'the last step brings its own action', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: WizardScaffold(
        title: 'Assistant',
        steps: steps,
        index: 2,
        body: Text('last'),
        nextEnabled: false,
      ),
    ));
    expect(find.byKey(const ValueKey('wizard-finish')), findsNothing);
    expect(find.byKey(const ValueKey('wizard-next')), findsNothing);
  });
}
