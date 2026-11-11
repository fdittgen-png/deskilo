// SPDX-License-Identifier: AGPL-3.0-or-later
// Invoicing navigation separates personal finances from workspace setup and
// keeps the invoicing home's figures, filters and lines reachable on a
// narrow, large-text screen.
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
  bool openMore = true,
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
  // #3587 — the tools are entries of the worded More menu.
  if (!openMore) return;
  await tester.tap(find.byKey(const ValueKey('invoicing-tools')));
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
    await _pump(tester, money: money, openMore: false);
    tester.view.physicalSize = const Size(360, 850);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // #3587 — the home in place of the stage strip: what is owed, the
    // list's filters and the switch to one line per invoice, each
    // reachable at 2x text on a phone without anything overflowing.
    final home = find.byKey(const ValueKey('invoicing-home'));
    expect(home, findsOneWidget);
    expect(find.byKey(const ValueKey('invoicing-owed')), findsOneWidget);
    final scrollable =
        find.descendant(of: home, matching: find.byType(Scrollable)).first;
    Future<void> reach(Finder target) async {
      await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await reach(find.byKey(const ValueKey('invoicing-filter-paid')));
    await tester.tap(find.byKey(const ValueKey('invoicing-filter-paid')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('invoicing-filter-open')));
    await tester.pumpAndSettle();
    final byInvoice = find.descendant(
      of: find.byKey(const ValueKey('invoicing-view')),
      matching: find.text('Invoices'),
    );
    await reach(byInvoice);
    await tester.tap(byInvoice);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final row =
        find.byKey(ValueKey('invoicing-row-${money.invoices.single.id}'));
    await reach(row);
    expect(row, findsOneWidget);
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
