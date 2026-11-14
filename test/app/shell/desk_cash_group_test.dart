// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3926 — at the desk, cash is a menu group: Finance holds a Cash group
// whose entries are the cash page's doors — money in and out, and the bank
// statements — each shown only with its own right and flag, the group absent
// when neither shows. The cash page goes to the first door the person may
// open (in and out, else the purchases, else the money page). On a phone the
// menu keeps its Cash entry and the page stays.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/app/shell/shell_drawer_tiles.dart';
import 'package:deskilo/features/money/presentation/widgets/bank_statements_sheet.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _cashFeatures = {
  WorkspaceFeature.moneyTab,
  WorkspaceFeature.workspaceStatus,
  WorkspaceFeature.bankImport,
  WorkspaceFeature.purchases,
};

class _Person implements AccessContext {
  _Person(this.permissions, {this.features = _cashFeatures});

  final Set<WorkspaceFeature> features;
  @override
  final Set<WorkspacePermission> permissions;
  @override
  bool get actsAsOwner => false;
  @override
  bool get canAdminister => false;
  @override
  bool get hasPairedTwin => false;
  @override
  bool get isAdmin => false;
  @override
  Set<WorkspaceFeature> get enabledFeatures => features;
  @override
  bool featureEnabled(WorkspaceFeature feature) => features.contains(feature);
}

Finder _group(String id) => find.byWidgetPredicate(
  (widget) => widget is DrawerGroup && widget.id == id,
);

Future<void> _openGroup(WidgetTester tester, String id) async {
  final group = _group(id);
  expect(group, findsOneWidget);
  final title = tester.widget<DrawerGroup>(group).title;
  final heading = find.descendant(of: group, matching: find.text(title)).first;
  await tester.ensureVisible(heading);
  await tester.tap(heading);
  await tester.pumpAndSettle();
}

Future<void> _pumpMenu(
  WidgetTester tester, {
  required bool permanent,
  required Set<WorkspacePermission> permissions,
  Size size = const Size(1440, 2400),
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.myMember = workspace.myMember.copyWith(
    isOwner: false,
    isAdmin: true,
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: SizedBox(
            width: 320,
            child: ShellDrawer(
              permanent: permanent,
              tabTitles: const [],
              visibleBranches: const [],
              currentIndex: 0,
              onBranch: (_) {},
              pendingEvents: 0,
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpApp(
    tester,
    null,
    router: router,
    size: size,
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      enabledFeaturesSyncProvider.overrideWithValue(_cashFeatures),
      myPermissionsProvider.overrideWithValue(permissions),
    ],
  );
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required Size size,
  required Set<WorkspacePermission> permissions,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in _cashFeatures) f.name: true},
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(_cashFeatures),
        myPermissionsProvider.overrideWithValue(permissions),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider);
}

void main() {
  group('the cash page at the desk goes to the first door the person may '
      'open', () {
    test('money in and out, for who reads the finances', () {
      expect(
        cashDeskLanding(_Person({WorkspacePermission.viewFinances})),
        '/money/status',
      );
    });
    test('the purchases, for who manages them only', () {
      expect(
        cashDeskLanding(_Person({WorkspacePermission.managePurchases})),
        '/money/purchases',
      );
    });
    test('the money page, for who may open neither', () {
      expect(
        cashDeskLanding(_Person({WorkspacePermission.manageBilling})),
        '/money',
      );
      expect(
        cashDeskLanding(
          _Person(
            {WorkspacePermission.viewFinances},
            features: {WorkspaceFeature.moneyTab},
          ),
        ),
        '/money',
        reason: 'a door whose feature is off is not one to open',
      );
    });
  });

  for (final role in [
    (
      name: 'a finance reader',
      rights: {WorkspacePermission.viewFinances},
      entries: {'drawer-cash-in-out', 'drawer-bank-statements'},
    ),
    (
      name: 'an invoicer',
      rights: {WorkspacePermission.issueInvoices},
      entries: {'drawer-bank-statements'},
    ),
    (
      name: 'a buyer',
      rights: {WorkspacePermission.managePurchases},
      entries: <String>{},
    ),
  ]) {
    testWidgets('at the desk ${role.name} finds exactly the cash doors their '
        'rights open', (tester) async {
      await _pumpMenu(tester, permanent: true, permissions: role.rights);
      if (role.entries.isEmpty) {
        expect(_group('cash'), findsNothing);
      } else {
        await _openGroup(tester, 'finance');
        await _openGroup(tester, 'cash');
      }
      for (final key in const [
        'drawer-cash-in-out',
        'drawer-bank-statements',
      ]) {
        expect(
          find.byKey(ValueKey(key)),
          role.entries.contains(key) ? findsOneWidget : findsNothing,
          reason: key,
        );
      }
      expect(find.byKey(const ValueKey('drawer-cash')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on a phone the menu keeps its Cash entry and no Cash group', (
    tester,
  ) async {
    await _pumpMenu(
      tester,
      permanent: false,
      permissions: {WorkspacePermission.viewFinances},
    );
    expect(_group('cash'), findsNothing);
    await _openGroup(tester, 'finance');
    expect(find.byKey(const ValueKey('drawer-cash')), findsOneWidget);
  });

  // The statements open as a sheet over the desk: at 1024 as at 1440 it
  // lies within the window and nothing in it overflows.
  for (final size in const [Size(1024, 768), Size(1440, 900)]) {
    testWidgets('at ${size.width.toInt()} the bank entry opens the '
        'statements over the page, whole', (tester) async {
      await _pumpMenu(
        tester,
        permanent: true,
        permissions: {WorkspacePermission.viewFinances},
        size: size,
      );
      await _openGroup(tester, 'finance');
      await _openGroup(tester, 'cash');
      await tester.tap(find.byKey(const ValueKey('drawer-bank-statements')));
      await tester.pumpAndSettle();
      final sheet = find.byType(BankStatementsView);
      expect(sheet, findsOneWidget);
      final rect = tester.getRect(sheet);
      expect(
        (Offset.zero & size).intersect(rect),
        rect,
        reason: 'the sheet lies within the window',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('at 1440 the cash page goes to money in and out; a phone '
      'keeps it', (tester) async {
    final desk = await _pumpApp(
      tester,
      size: const Size(1440, 900),
      permissions: {WorkspacePermission.viewFinances},
    );
    desk.go('/money/cash');
    await tester.pumpAndSettle();
    expect(desk.routeInformationProvider.value.uri.path, '/money/status');
  });

  testWidgets('on a phone the cash page stays', (tester) async {
    final phone = await _pumpApp(
      tester,
      size: const Size(390, 844),
      permissions: {WorkspacePermission.viewFinances},
    );
    phone.go('/money/cash');
    await tester.pumpAndSettle();
    expect(phone.routeInformationProvider.value.uri.path, '/money/cash');
  });
}
