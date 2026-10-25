// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2521 — five workspace routes that opened with their feature off now
// belong to the feature that already owned their entry point: a deep link
// redirects while the flag is off, opens while it is on, and every link to
// the route disappears with the flag.
import 'package:deskilo/app/shell/shell_drawer_entries.dart';
import 'package:deskilo/core/help/help_tips.dart';
import 'package:deskilo/features/profile/presentation/widgets/settings_task_section.dart';
import 'package:deskilo/features/profile/presentation/widgets/settings_workspace_sections.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';
import '../helpers/router_paths.dart';
import '../helpers/screens/members_screen.dart';
import '../helpers/screens/workspace_settings_screen.dart';

/// Each route, the flag that owns it, and the flags it also needs on to
/// open (a default-off owner is switched on explicitly).
const _owned = <(String, WorkspaceFeature)>[
  ('/money/repartition', WorkspaceFeature.expenseRepartition),
  ('/money/settlement', WorkspaceFeature.invoiceSettlement),
  ('/settings/public-page', WorkspaceFeature.publicListings),
  ('/payment-methods', WorkspaceFeature.moneyTab),
  ('/billing', WorkspaceFeature.moneyTab),
];

Map<String, dynamic> _on(WorkspaceFeature owner) => {
  for (final f in WorkspaceFeature.values) f.dbKey: true,
  owner.dbKey: true,
};

Map<String, dynamic> _off(WorkspaceFeature owner) => {
  ..._on(owner),
  owner.dbKey: false,
};

void main() {
  group('the route follows its flag', () {
    for (final (path, owner) in _owned) {
      testWidgets('$path redirects with ${owner.dbKey} off', (tester) async {
        final app = await bootRouter(tester, featureFlags: _off(owner));
        expect(await resolveRoute(app, path), isNot(path));
      });
      testWidgets('$path opens with ${owner.dbKey} on', (tester) async {
        final app = await bootRouter(tester, featureFlags: _on(owner));
        expect(await resolveRoute(app, path), path);
      });
    }
  });

  group('the links follow the flag', () {
    Future<List<String>> drawerKeys(
      WidgetTester tester,
      Set<WorkspaceFeature> features,
    ) async {
      late List<String> keys;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            keys = [
              for (final e in DrawerEntries(
                context: context,
                features: features,
                permissions: WorkspacePermission.values.toSet(),
                accountMenu: false,
                permanent: false,
                visibleBranches: const [],
                tabTitles: const [],
                currentIndex: 0,
                onBranch: (_) {},
                go: (_, {push = false}) {},
              ).administration())
                e.key,
            ];
            return const SizedBox();
          },
        ),
      );
      return keys;
    }

    testWidgets('the drawer drops billing and payment methods without '
        'moneyTab', (tester) async {
      final all = WorkspaceFeature.values.toSet();
      final on = await drawerKeys(tester, all);
      expect(on, containsAll(['drawer-billing', 'drawer-payment-methods']));
      final off = await drawerKeys(
        tester,
        all.difference({WorkspaceFeature.moneyTab}),
      );
      expect(off, isNot(contains('drawer-billing')));
      expect(off, isNot(contains('drawer-payment-methods')));
    });

    Future<List<String>> settingsKeys(
      WidgetTester tester,
      Set<WorkspaceFeature> features,
    ) async {
      late List<Widget> sections;
      await pumpApp(
        tester,
        Consumer(
          builder: (context, ref, _) {
            sections = workspaceSettingsTiles(
              context,
              ref,
              l10n: AppLocalizations.of(context)!,
              canAdminister: true,
              perms: WorkspacePermission.values.toSet(),
              features: features,
              isOwner: true,
              hasTwin: false,
            );
            return const SizedBox();
          },
        ),
      );
      return [
        for (final s in sections.whereType<SettingsTaskSection>())
          for (final t in s.children)
            if (t.key case ValueKey<String>(:final value)) value,
      ];
    }

    testWidgets('Settings drops billing and payment methods without '
        'moneyTab', (tester) async {
      final all = WorkspaceFeature.values.toSet();
      final on = await settingsKeys(tester, all);
      expect(
        on,
        containsAll([
          'settings-workspace-sections-billing-title',
          'settings-payment-methods',
        ]),
      );
      final off = await settingsKeys(
        tester,
        all.difference({WorkspaceFeature.moneyTab}),
      );
      expect(off, isNot(contains('settings-workspace-sections-billing-title')));
      expect(off, isNot(contains('settings-payment-methods')));
    });

    test('the tips that link to billing and payment methods need moneyTab', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final linked = [
        for (final id in HelpHintId.values)
          for (final tip in helpHintTips(l10n, id))
            if (tip.route == '/billing' || tip.route == '/payment-methods') tip,
      ];
      expect(linked, isNotEmpty);
      for (final tip in linked) {
        expect(tip.feature, WorkspaceFeature.moneyTab.dbKey, reason: tip.route);
      }
    });

    for (final money in [true, false]) {
      testWidgets('Members offers the billing shortcut only with moneyTab; '
          'moneyTab=$money', (tester) async {
        await pumpMembers(tester, featureFlags: {'moneyTab': money});
        expect(
          find.byKey(const ValueKey('members-billing-title')),
          money ? findsOneWidget : findsNothing,
        );
      });

      testWidgets('workspace settings link payment methods only with '
          'moneyTab; moneyTab=$money', (tester) async {
        await pumpWorkspaceSettings(
          tester,
          repository: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'moneyTab': money},
          ),
        );
        expect(
          find.byKey(const Key('workspaceSettingsPaymentMethods')),
          money ? findsOneWidget : findsNothing,
        );
      });
    }

    for (final listed in [true, false]) {
      testWidgets('workspace settings link the public page only with '
          'publicListings; publicListings=$listed', (tester) async {
        await pumpWorkspaceSettings(
          tester,
          repository: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {'publicListings': listed},
          ),
        );
        expect(
          find.byKey(const ValueKey('workspace-settings-portal-publication')),
          listed ? findsOneWidget : findsNothing,
        );
      });
    }
  });
}
