// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2875 — with invoicing not chosen the guide never asks for VAT,
// numbering or e-invoicing, and says what that means. A step applies when
// its feature is effective (`feature_effective`: on, with every feature it
// requires); every Grow step's feature requires invoicing, so with
// invoicing off none of them applies even where its own switch is stored
// on. The demo derives the status by the server's rules; the guide over it
// lists none of the three in any section, explains why with a way to
// /setup/levels, and lists them again once invoicing is on.
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/seed/demo_setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _grow = ['vat', 'numbering', 'einvoicing'];

/// The stored switches of a space that keeps the three Grow features on
/// and decides invoicing with [invoicing].
Map<String, Object?> _flags({required bool invoicing}) => {
  ...platformFeaturesOnByDefault,
  WorkspaceFeature.invoicing.dbKey: invoicing,
  WorkspaceFeature.vatManagement.dbKey: true,
  WorkspaceFeature.numberSequences.dbKey: true,
  WorkspaceFeature.einvoiceCustomerDelivery.dbKey: true,
};

Set<WorkspaceFeature> _effective(Map<String, Object?> flags) =>
    effectiveFeatures(resolveEnabledFeatures(flags));

Future<List<String>> _guide(
  WidgetTester tester, {
  required bool invoicing,
}) async {
  tester.view.physicalSize = const Size(800, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final flags = _flags(invoicing: invoicing);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SetupGuideScreen()),
      GoRoute(
        path: '/setup/levels',
        builder: (_, _) {
          pushed.add('/setup/levels');
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          localSetup: FakeLocalSetupRepository(
            status: demoSetupStatus(flags, ready: const {'basics'}),
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(_effective(flags)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
  // Every folded section open: "anywhere in the plan".
  for (final id in ['waiting', 'later', 'optional', 'deferred', 'done']) {
    final fold = find.byKey(ValueKey('setup-guide-$id'));
    if (fold.evaluate().isEmpty) continue;
    await tester.tap(fold);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  return pushed;
}

bool _listed(String step) =>
    find.byKey(ValueKey('setup-step-$step')).evaluate().isNotEmpty ||
    find.byKey(ValueKey('setup-guide-next-$step')).evaluate().isNotEmpty;

void main() {
  test('every Grow step needs invoicing', () {
    final grow = [
      for (final s in setupSteps)
        if (s.group == SetupGroup.grow) s,
    ];
    expect(grow.map((s) => s.id), containsAll(_grow));
    for (final s in grow) {
      final feature = s.feature;
      expect(feature, isNotNull, reason: s.id);
      expect(
        feature == WorkspaceFeature.invoicing ||
            requirementChain(feature!).contains(WorkspaceFeature.invoicing),
        isTrue,
        reason: '${s.id} applies without invoicing',
      );
    }
  });

  test('with invoicing off the three are not effective, whatever their own '
      'switch; with it on they are', () {
    const three = {
      WorkspaceFeature.vatManagement,
      WorkspaceFeature.numberSequences,
      WorkspaceFeature.einvoiceCustomerDelivery,
    };
    expect(_effective(_flags(invoicing: false)).intersection(three), isEmpty);
    expect(_effective(_flags(invoicing: true)), containsAll(three));
  });

  test('the status by the server\'s rules: not applicable without invoicing, '
      'and the invoice milestone does not apply', () {
    SetupStatus status({required bool invoicing}) =>
        demoSetupStatus(_flags(invoicing: invoicing), ready: const {});
    final off = status(invoicing: false);
    for (final step in _grow) {
      expect(
        off.steps.singleWhere((s) => s.step == step).state,
        SetupStepState.notApplicable,
        reason: step,
      );
    }
    expect(
      off.milestones.singleWhere((m) => m.milestone == 'invoice').applies,
      isFalse,
    );
    final on = status(invoicing: true);
    for (final step in _grow) {
      expect(
        on.steps.singleWhere((s) => s.step == step).state,
        isNot(SetupStepState.notApplicable),
        reason: step,
      );
    }
  });

  testWidgets('invoicing off: no VAT, numbering or e-invoicing anywhere, the '
      'reason shown, and it leads to what the space does', (tester) async {
    final pushed = await _guide(tester, invoicing: false);
    for (final step in _grow) {
      expect(_listed(step), isFalse, reason: step);
    }
    final banner = find.byKey(const ValueKey('setup-guide-no-invoicing'));
    expect(
      find.descendant(
        of: banner,
        matching: find.text(
          'Invoicing is not chosen: members get statements of what they owe '
          'and pay against them. No VAT, numbering or e-invoicing is needed, '
          'so the guide does not ask for them.',
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: banner,
        matching: find.byKey(const ValueKey('inline-banner-action')),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(pushed, ['/setup/levels']);
  });

  testWidgets('invoicing on: the three are in the plan and nothing explains '
      'their absence', (tester) async {
    await _guide(tester, invoicing: true);
    for (final step in _grow) {
      expect(_listed(step), isTrue, reason: step);
    }
    expect(
      find.byKey(const ValueKey('setup-guide-no-invoicing')),
      findsNothing,
    );
  });
}
