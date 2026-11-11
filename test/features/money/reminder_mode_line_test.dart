// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the line that says how reminders go out ("by themselves, in
// the app" or "by hand") tells the truth of the stored rules, makes no claim
// before they are read, and "Rules" opens the existing rules dialog.
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/presentation/invoicing/reminder_mode_line.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, DunningRules rules) async {
  await pumpApp(
    tester,
    const Scaffold(body: ReminderModeLine()),
    size: const Size(390, 400),
    overrides: [
      ...standardTestOverrides(),
      dunningRulesProvider.overrideWith((ref) async => rules),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('automatic rules: the line says reminders go out by themselves', (
    tester,
  ) async {
    await _pump(tester, const DunningRules(automatic: true));
    expect(
      find.text('Reminders go out by themselves, in the app.'),
      findsOneWidget,
    );
    expect(find.text('Reminders are shared by hand.'), findsNothing);
  });

  testWidgets('rules by hand: the line says so', (tester) async {
    await _pump(tester, const DunningRules());
    expect(find.text('Reminders are shared by hand.'), findsOneWidget);
  });

  testWidgets('Rules opens the reminder rules dialog', (tester) async {
    await _pump(tester, const DunningRules());
    await tester.tap(find.byKey(const ValueKey('reminder-mode-rules')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
