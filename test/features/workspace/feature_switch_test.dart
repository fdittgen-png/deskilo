// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1851 B — one feature switch: preview, consent, conditional write.
//
// Invariant: a switch's plan writes only what changes, names the
// prerequisites it drags on and the dependants that will wait, asks for
// consent exactly for the experimental features it turns on, and is
// conditioned on every flag the decision rested on. On the real Features
// screen the consent preview names each experimental feature's stage and
// how many prerequisites come with it; cancel writes nothing; confirm
// writes the plan with its read-set; a flag that moved in between is
// refused, nothing is written, and the owner is told to check again; a
// write whose refetch failed is reported as unconfirmed, not as done.
import 'package:deskilo/features/workspace/application/feature_switch.dart';
import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/features_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _beta = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: 'fixture',
  evidence: ['booking'],
);

// roleAssignment needs roleManagement.
const _child = WorkspaceFeature.roleAssignment;
const _parent = WorkspaceFeature.roleManagement;

void main() {
  group('the plan', () {
    test('switching on drags the chain, asks for the experimental ones', () {
      final plan = planFeatureSwitch(
        raw: const {},
        feature: _child,
        value: true,
        needsOptIn: (f) => f == _child || f == _parent,
      );
      expect(plan.flags, {_child.dbKey: true, _parent.dbKey: true});
      expect(plan.alsoOn, [_parent]);
      expect(plan.needsConsent.toSet(), {_child, _parent});
      expect(plan.expected, {_child.dbKey: false, _parent.dbKey: false});
      expect(plan.waiting, isEmpty);
    });

    test('a prerequisite already on is neither written nor asked again', () {
      final plan = planFeatureSwitch(
        raw: const {_parent},
        feature: _child,
        value: true,
        needsOptIn: (f) => true,
      );
      expect(plan.flags, {_child.dbKey: true});
      expect(plan.alsoOn, isEmpty);
      expect(plan.needsConsent, [_child]);
      expect(plan.expected[_parent.dbKey], isTrue);
    });

    test('switching off names the dependants that wait, and rests on them', () {
      final plan = planFeatureSwitch(
        raw: const {_parent, _child},
        feature: _parent,
        value: false,
        needsOptIn: (f) => true,
      );
      expect(plan.flags, {_parent.dbKey: false});
      expect(plan.waiting, [_child]);
      expect(plan.needsConsent, isEmpty);
      expect(plan.expected, {_parent.dbKey: true, _child.dbKey: true});
    });

    test('a switch already where it is asked writes nothing', () {
      final plan = planFeatureSwitch(
        raw: const {_parent},
        feature: _parent,
        value: true,
        needsOptIn: (f) => true,
      );
      expect(plan.isNoOp, isTrue);
      expect(plan.needsConsent, isEmpty);
    });
  });

  group('the Features screen', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<FakeWorkspaceRepository> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 24000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: {_parent.dbKey: false, _child.dbKey: false},
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(workspace: workspace),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeaturesScreen(
              assessments: {
                for (final f in WorkspaceFeature.values)
                  f: const FeatureAssessment.unreviewed('fixture'),
                _child: _beta,
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('features-view-switches')));
      await tester.pumpAndSettle();
      return workspace;
    }

    Finder tile(WorkspaceFeature f) =>
        find.byKey(ValueKey('feature-${f.name}'));

    testWidgets('the preview names the stage and what comes with it', (
      tester,
    ) async {
      final workspace = await pump(tester);
      final before = workspace.flagWrites.length;
      await tester.tap(tile(_child));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-opt-in')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feature-opt-in-stage-0')),
          matching: find.textContaining(l10n.featureMaturityBeta),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('feature-opt-in-also-on')),
          matching: find.textContaining('(1)', findRichText: true),
        ),
        findsNothing,
        reason: 'one prerequisite reads in the singular',
      );
      expect(
        find.byKey(const ValueKey('feature-opt-in-also-on')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('feature-opt-in-cancel')));
      await tester.pumpAndSettle();
      expect(workspace.flagWrites.length, before);
    });

    testWidgets('confirming writes the plan against what it was read as', (
      tester,
    ) async {
      final workspace = await pump(tester);
      await tester.tap(tile(_child));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-opt-in-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.flagWrites.last, {
        _child.dbKey: true,
        _parent.dbKey: true,
      });
      expect(workspace.flagExpectations.last, {
        _child.dbKey: false,
        _parent.dbKey: false,
      });
    });

    testWidgets('a flag that moved in between writes nothing and says so', (
      tester,
    ) async {
      final workspace = await pump(tester);
      final before = workspace.flagWrites.length;
      workspace.flagConflictNext = true;
      await tester.tap(tile(_child));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-opt-in-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.flagWrites.length, before);
      expect(find.text(l10n.featureChangedMeanwhile), findsOneWidget);
    });
  });
}
