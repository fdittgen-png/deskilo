// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
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
  FakeWorkspaceRepository? workspace,
}) async {
  money ??= FakeMoneyRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides:
          standardTestOverrides(money: money, workspace: workspace),
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

  testWidgets(
      'VAT-charging regime: every row names its rate — own rate, or the '
      'workspace default (#537)', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] =
        workspace.workspaces[0].copyWith(vatRegime: 'vat_registered');
    final money = FakeMoneyRepository()
      ..vatRates = [
        const VatRate(
            id: 'vat-1', label: 'Standard', percent: 20, isDefault: true),
        const VatRate(id: 'vat-2', label: 'Reduced', percent: 5.5),
      ];
    // Seed BEFORE the pump — the provider caches its first read.
    money.services.clear();
    money.services.addAll([
      const ServiceItem(
          id: 's1',
          workspaceId: 'ws-1',
          name: 'Coffee',
          priceCents: 2000,
          active: true,
          vatRateId: 'vat-2'),
      const ServiceItem(
          id: 's2',
          workspaceId: 'ws-1',
          name: 'Locker',
          priceCents: 1000,
          active: true,
          vatRateId: ''),
    ]);
    await pumpServices(tester, money: money, workspace: workspace);

    expect(find.textContaining('incl. VAT 5.5 %'), findsOneWidget);
    expect(find.textContaining('incl. VAT 20 %'), findsOneWidget);
  });

  testWidgets('no VAT regime → prices stay bare (#537)', (tester) async {
    await pumpServices(tester);
    expect(find.textContaining('incl. VAT'), findsNothing);
  });
}
