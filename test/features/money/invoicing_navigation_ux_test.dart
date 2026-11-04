// SPDX-License-Identifier: AGPL-3.0-or-later
// Invoicing navigation separates personal finances from workspace setup and
// keeps each process stage reachable on a narrow, large-text screen.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakeMoneyRepository money,
  Map<String, dynamic> flags = const {},
  Set<WorkspacePermission>? permissions,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final workspace = FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(money: money, workspace: workspace),
        if (permissions != null)
          myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('My finances'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
  await tester.pumpAndSettle();
  await openMoneyWorkspaceTools(tester);
  await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
  await tester.tap(find.byKey(const ValueKey('invoices-button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the process remains readable and navigable on a narrow screen', (
    tester,
  ) async {
    final money = FakeMoneyRepository();
    await money.createInvoice(
      workspaceId: 'ws-1',
      memberId: 'member-1',
      period: kTestPeriod,
    );
    await _pump(tester, money: money);
    tester.view.physicalSize = const Size(360, 850);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('invoice-stages-scroll')), findsOneWidget);
    final tile = tester.getSize(
      find.byKey(const ValueKey('invoice-stage-issue')),
    );
    expect(tile.width, greaterThanOrEqualTo(150));
    await tester.drag(
      find.byKey(const ValueKey('invoice-stages-scroll')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invoice-stage-closed')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('invoice-count')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('invoice-archive-filters-scroll')),
      findsOneWidget,
    );
  });

  testWidgets(
    'personal finances opens across spaces and setup stays a workspace action',
    (tester) async {
      final money = FakeMoneyRepository();
      await _pump(tester, money: money, flags: const {'setupGuide': true});
      expect(
        find.byKey(const ValueKey('invoicing-setup-guide')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('invoicing-personal-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('finances-tabs')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-finances-finances-workspace-filter')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('personal-invoice-process')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('invoice-process-sheet')),
        findsOneWidget,
      );
      for (final step in InvoiceStep.values) {
        expect(
          find.byKey(ValueKey('invoice-process-step-${step.name}')),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('setup shortcut opens the guide', (tester) async {
    await _pump(
      tester,
      money: FakeMoneyRepository(),
      flags: const {'setupGuide': true},
    );
    await tester.tap(find.byKey(const ValueKey('invoicing-setup-guide')));
    await tester.pumpAndSettle();
    expect(find.text('Setup guide'), findsWidgets);
  });

  testWidgets('workspace settings remain reachable when the guide is off', (
    tester,
  ) async {
    await _pump(
      tester,
      money: FakeMoneyRepository(),
      flags: const {'setupGuide': false},
      permissions: {
        WorkspacePermission.issueInvoices,
        WorkspacePermission.workspaceSettings,
      },
    );
    final button = find.byKey(const ValueKey('invoicing-setup-guide'));
    expect(button, findsOneWidget);
    final router = GoRouter.of(tester.element(button));
    await tester.tap(button);
    await tester.pump();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/workspace-settings',
    );
  });

  testWidgets('an issuer without configuration access has no setup shortcut', (
    tester,
  ) async {
    await _pump(
      tester,
      money: FakeMoneyRepository(),
      flags: const {'setupGuide': true},
      permissions: {WorkspacePermission.issueInvoices},
    );
    expect(find.byKey(const ValueKey('invoicing-setup-guide')), findsNothing);
    expect(
      find.byKey(const ValueKey('invoicing-personal-action')),
      findsOneWidget,
    );
  });
}
