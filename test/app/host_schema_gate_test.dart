// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — the installation hosting the workspace is judged on its own.
// Below what the app needs, the workspace's routes show the update screen
// (its missing migrations for whoever runs it) and the account's own pages
// stay; an installation that is current changes nothing. Below what one
// FEATURE needs, only that feature (and what is under it) is not offered:
// not as a switch, not as an effective feature, not through its route.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/backend/installation_schema.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/features_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';
import '../helpers/pump_app.dart';

const _update = ValueKey('schema-update');

Future<void> _boot(
  WidgetTester tester,
  InstallationSchemaSource source, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(installationSchema: source),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets(
      'at ${size.width.toInt()}: a host below what the app needs shows the '
      'update screen, with the migrations it lacks',
      (tester) async {
        const running = appNeedsSchemaVersion - 2;
        await _boot(
          tester,
          const FixedInstallationSchemaSource(number: running),
          size: size,
        );
        expect(find.byKey(_update), findsOneWidget);
        expect(find.byKey(const ValueKey('schema-update-missing')),
            findsOneWidget);
        expect(
          find.textContaining(
            'migrations ${running + 1} to $appNeedsSchemaVersion',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('a host without a marker is behind too', (tester) async {
    await _boot(tester, const FixedInstallationSchemaSource(number: null));
    expect(find.byKey(_update), findsOneWidget);
  });

  testWidgets('a current host and an unreadable host change nothing',
      (tester) async {
    for (final source in const [
      FixedInstallationSchemaSource(),
      FixedInstallationSchemaSource(unavailable: true),
    ]) {
      await _boot(tester, source);
      expect(find.byKey(_update), findsNothing);
    }
  });

  testWidgets('an old host closes the workspace, never the account: Me opens',
      (tester) async {
    await _boot(
      tester,
      const FixedInstallationSchemaSource(number: appNeedsSchemaVersion - 1),
    );
    final router = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
    ).read(routerProvider);
    expect(find.byKey(_update), findsOneWidget);
    router.go('/me');
    await tester.pumpAndSettle();
    expect(find.byKey(_update), findsNothing, reason: 'Me is the account\'s');
    router.go('/reserve');
    await tester.pumpAndSettle();
    expect(find.byKey(_update), findsOneWidget);
  });

  group('a feature the installation is too old for', () {
    const flags = {'services': true, 'stockManagement': true};

    Future<ProviderContainer> boot(
      WidgetTester tester,
      InstallationSchemaSource source,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(
            installationSchema: source,
            workspace: FakeWorkspaceRepository.withWorkspace(
              featureFlags: flags,
            ),
          ),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
    }

    testWidgets('is not effective below its since, and is at it', (tester) async {
      var c = await boot(tester, const FixedInstallationSchemaSource(number: 747));
      expect(c.read(enabledFeaturesSyncProvider),
          isNot(contains(WorkspaceFeature.stockManagement)));
      expect(c.read(enabledFeaturesSyncProvider),
          contains(WorkspaceFeature.services));

      await tester.pumpWidget(const SizedBox());
      c = await boot(tester, const FixedInstallationSchemaSource(number: 748));
      expect(c.read(enabledFeaturesSyncProvider),
          contains(WorkspaceFeature.stockManagement));
    });

    testWidgets('an unreadable installation withholds nothing', (tester) async {
      final c = await boot(
        tester,
        const FixedInstallationSchemaSource(unavailable: true),
      );
      expect(c.read(enabledFeaturesSyncProvider),
          contains(WorkspaceFeature.stockManagement));
    });

    testWidgets('the Features screen says why to an administrator', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 30000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        const FeaturesScreen(),
        overrides: standardTestOverrides(
          installationSchema: const FixedInstallationSchemaSource(number: 747),
          workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: flags),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('features-view-switches')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feature-stockManagement')),
          matching: find.textContaining('too old for this feature'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feature-accessorySupplements')),
          matching: find.textContaining('too old for this feature'),
        ),
        findsNothing,
      );
    });
  });
}
