// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpServices(
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
  GoRouter.of(context).push('/services');
  await tester.pumpAndSettle();
  return money;
}

void main() {
  testWidgets('the catalog lists every service with price, inactive marked',
      (tester) async {
    await pumpServices(tester);

    expect(find.text('Coffee'), findsOneWidget);
    expect(find.textContaining('1.50'), findsOneWidget);
    expect(find.text('Printing'), findsOneWidget);
    expect(find.textContaining('0.20'), findsOneWidget);
    expect(find.text('Locker'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('an empty catalog shows the empty state', (tester) async {
    await pumpServices(tester, money: FakeMoneyRepository()..services.clear());

    expect(find.text('No services yet.'), findsOneWidget);
  });

  testWidgets('creating a service persists name and price (#123)',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Day pass');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '2.50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final created = money.services.singleWhere((s) => s.name == 'Day pass');
    expect(created.priceCents, 250);
    expect(created.active, isTrue);
    expect(find.text('Day pass'), findsOneWidget);
  });

  testWidgets('editing a service updates price and can deactivate it',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.text('Coffee'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Price'), '3');
    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = money.services.singleWhere((s) => s.name == 'Coffee');
    expect(updated.priceCents, 300);
    expect(updated.active, isFalse);
    expect(find.text('Inactive'), findsNWidgets(2));
  });

  testWidgets('a deactivated service can be reactivated, never deleted',
      (tester) async {
    final money = await pumpServices(tester);

    await tester.tap(find.text('Locker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Active'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final updated = money.services.singleWhere((s) => s.name == 'Locker');
    expect(updated.active, isTrue);
    expect(money.services.length, 3);
    expect(find.text('Inactive'), findsNothing);
  });

  testWidgets('workers get no services entry in settings', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..myMember = const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: workspace),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Services'), findsNothing);
  });
}
