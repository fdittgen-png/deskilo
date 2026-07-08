// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpPlans(
  WidgetTester tester, {
  FakeMoneyRepository? money,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/plans');
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('the editor lists every plan with price and quota',
      (tester) async {
    await pumpPlans(tester);

    expect(find.text('Full'), findsOneWidget);
    expect(find.textContaining('unlimited half-days'), findsOneWidget);
    expect(find.text('Half'), findsOneWidget);
    expect(find.textContaining('22 half-days'), findsOneWidget);
    expect(find.textContaining('/extra half-day'), findsNWidgets(2));
  });

  testWidgets('creating a plan persists name, fees and quota (#105)',
      (tester) async {
    final money = await pumpPlans(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'), 'Quarter');
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly base fee'), '75.50');
    await tester.enterText(
      find.widgetWithText(TextField, 'Included half-days'), '11');
    await tester.enterText(
      find.widgetWithText(TextField, 'Price per extra half-day'), '9');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final created = money.plans.singleWhere((p) => p.name == 'Quarter');
    expect(created.baseFeeCents, 7550);
    expect(created.includedHalfDays, 11);
    expect(created.overageFeeCents, 900);
    expect(created.active, isTrue);
    expect(find.text('Quarter'), findsOneWidget);
  });

  testWidgets('editing a plan updates price and can deactivate it',
      (tester) async {
    final money = await pumpPlans(tester);

    await tester.tap(find.text('Half'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly base fee'), '175');
    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = money.plans.singleWhere((p) => p.name == 'Half');
    expect(updated.baseFeeCents, 17500);
    expect(updated.active, isFalse);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('an empty quota means unlimited', (tester) async {
    final money = await pumpPlans(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'), 'All-in');
    await tester.enterText(
      find.widgetWithText(TextField, 'Monthly base fee'), '300');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final created = money.plans.singleWhere((p) => p.name == 'All-in');
    expect(created.includedHalfDays, isNull);
  });
}
