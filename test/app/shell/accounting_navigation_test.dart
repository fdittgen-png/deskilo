// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Accounting navigation follows each destination's own rights and feature,
// in both the drawer and the permanent sidebar. No unrelated administration
// entry may be required to reach an authorized financial destination.
import 'package:deskilo/app/route_access.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/app/shell/shell_drawer_entries.dart';
import 'package:deskilo/app/shell/shell_drawer_tiles.dart';
import 'package:deskilo/features/money/presentation/screens/legal_identity_screen.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/screens/workspace_settings_screen.dart';
import '../../helpers/section_jump.dart';

const _accountingFeatures = {
  WorkspaceFeature.moneyTab,
  WorkspaceFeature.invoicing,
  WorkspaceFeature.vatManagement,
  WorkspaceFeature.vatDeclarations,
  WorkspaceFeature.accountingBook,
  WorkspaceFeature.accountingConnectors,
};

const _movedRoutes = {
  'drawer-accounting': '/money/accounting',
  'drawer-accounting-export': '/invoice-register',
  'drawer-vat': '/vat',
  'drawer-vat-declarations': '/vat-declarations',
  'drawer-legal-identity': '/legal-identity',
};

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

Future<void> _pumpDrawer(
  WidgetTester tester, {
  required bool permanent,
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
  bool owner = false,
  bool manager = true,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.myMember = workspace.myMember.copyWith(
    isOwner: owner,
    isAdmin: manager,
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
    size: const Size(800, 2400),
    overrides: [
      ...standardTestOverrides(workspace: workspace),
      enabledFeaturesSyncProvider.overrideWithValue(features),
      myPermissionsProvider.overrideWithValue(permissions),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final permanent in [false, true]) {
    for (final role in [
      (
        name: 'owner',
        owner: true,
        manager: true,
        rights: WorkspacePermission.values.toSet(),
        entries: _movedRoutes.keys.toSet(),
      ),
      (
        name: 'finance manager',
        owner: false,
        manager: true,
        rights: {
          WorkspacePermission.viewFinances,
          WorkspacePermission.manageBilling,
        },
        entries: {
          'drawer-accounting',
          'drawer-accounting-export',
          'drawer-vat',
          'drawer-vat-declarations',
        },
      ),
      (
        name: 'member',
        owner: false,
        manager: false,
        rights: {
          WorkspacePermission.makeReservations,
          WorkspacePermission.viewMyMoney,
        },
        entries: <String>{},
      ),
      (
        name: 'manager without financial rights',
        owner: false,
        manager: true,
        rights: <WorkspacePermission>{},
        entries: <String>{},
      ),
    ]) {
      testWidgets(
        '${role.name} sees only authorized accounting entries; sidebar=$permanent',
        (tester) async {
          await _pumpDrawer(
            tester,
            permanent: permanent,
            features: _accountingFeatures,
            permissions: role.rights,
            owner: role.owner,
            manager: role.manager,
          );
          if (role.entries.isEmpty) {
            expect(_group('accounting'), findsNothing);
          } else {
            await _openGroup(tester, 'finance');
            await _openGroup(tester, 'accounting');
          }
          for (final key in _movedRoutes.keys) {
            expect(
              find.byKey(ValueKey(key)),
              role.entries.contains(key) ? findsOneWidget : findsNothing,
              reason: key,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'disabled accounting features remove their entries; sidebar=$permanent',
      (tester) async {
        await _pumpDrawer(
          tester,
          permanent: permanent,
          features: const {},
          permissions: WorkspacePermission.values.toSet(),
          owner: true,
        );
        expect(_group('accounting'), findsNothing);
        for (final key in _movedRoutes.keys) {
          expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
        }
      },
    );

    testWidgets(
      'an export-only reader reaches accounting without administration; sidebar=$permanent',
      (tester) async {
        await _pumpDrawer(
          tester,
          permanent: permanent,
          features: {
            WorkspaceFeature.moneyTab,
            WorkspaceFeature.invoicing,
            WorkspaceFeature.accountingBook,
            WorkspaceFeature.accountingConnectors,
          },
          permissions: {WorkspacePermission.exportData},
        );
        await _openGroup(tester, 'finance');
        await _openGroup(tester, 'accounting');
        expect(find.byKey(const ValueKey('drawer-vat')), findsNothing);
        expect(find.byKey(const ValueKey('drawer-accounting')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('drawer-legal-identity')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'every moved accounting door keeps its canonical registered route and permission',
    (tester) async {
      late List<DrawerEntry> entries;
      final opened = <String>[];
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            entries = DrawerEntries(
              context: context,
              features: _accountingFeatures,
              permissions: WorkspacePermission.values.toSet(),
              accountMenu: false,
              permanent: true,
              visibleBranches: const [],
              tabTitles: const [],
              currentIndex: 0,
              onBranch: (_) {},
              go: (route, {push = true}) => opened.add(route),
            ).accounting();
            return const SizedBox();
          },
        ),
      );
      expect({
        for (final entry in entries) entry.key: entry.route,
      }, _movedRoutes);
      final registered = {for (final rule in routeRules) rule.pattern};
      for (final entry in entries) {
        expect(registered, contains(entry.route));
        expect(
          mayOpen(entry.route!, WorkspacePermission.values.toSet()),
          isTrue,
        );
        expect(mayOpen(entry.route!, const {}), isFalse);
        entry.onTap();
      }
      expect(opened, _movedRoutes.values.toList());
    },
  );

  testWidgets(
    'configuration retains one link to the sole legal and VAT editor',
    (tester) async {
      await pumpWorkspaceSettings(tester, expand: false);
      await tapSection(tester, 'workspace-section-payments');
      await tester.pumpAndSettle();
      final link = find.byKey(const Key('workspaceSettingsLegalIdentity'));
      expect(link, findsOneWidget);
      expect(find.byKey(const ValueKey('legal-identity-regime')), findsNothing);
      expect(find.byKey(const ValueKey('legal-identity-vat-id')), findsNothing);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(LegalIdentityScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('legal-identity-regime')),
        findsOneWidget,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(link, findsOneWidget);
      expect(find.byType(LegalIdentityScreen), findsNothing);
      expect(find.byKey(const Key('workspaceSettingsSave')), findsOneWidget);
    },
  );
}
