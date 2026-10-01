// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1851 — off stops NEW business; existing work stays serviceable. The
// matrix below is written out by hand and is the same one pgTAP 110 asks
// the server.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/feature_operation.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/features_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _f = WorkspaceFeature.spaceInquiries;

const _alpha = FeatureAssessment(
  maturity: FeatureMaturity.alpha,
  rationale: 'fixture',
);

void main() {
  group('the class matrix (same rows as pgTAP 110)', () {
    final rows = <(bool on, FeatureOperation op, bool expected)>[
      (true, FeatureOperation.acceptNew, true),
      (true, FeatureOperation.serviceExisting, true),
      (true, FeatureOperation.suspended, false),
      (false, FeatureOperation.acceptNew, false),
      (false, FeatureOperation.serviceExisting, true),
      (false, FeatureOperation.suspended, false),
    ];
    for (final (on, op, expected) in rows) {
      test('${on ? 'on' : 'off'} · ${op.wire} → $expected', () {
        expect(
          featureOperationAllowed(
            effective: on ? {_f} : const {},
            feature: _f,
            operation: op,
          ),
          expected,
        );
      });
    }

    test('an unknown feature takes nothing new; unknown classes are null', () {
      expect(
        featureOperationAllowed(
          effective: WorkspaceFeature.values.toSet(),
          feature: null,
          operation: FeatureOperation.acceptNew,
        ),
        isFalse,
      );
      expect(featureOperationFromWire('reopen'), isNull);
      expect(
        featureOperationFromWire('service_existing'),
        FeatureOperation.serviceExisting,
      );
    });
  });

  test('the migration gates each classified function with the same class', () {
    final sql = File('supabase/migrations/0324_feature_operation_classes.sql')
        .readAsStringSync();
    for (final feature in featureOperationClasses.entries) {
      for (final op in feature.value.entries) {
        final at = sql.indexOf("'public.${op.key}(");
        expect(at, greaterThan(0), reason: '${op.key} is not patched');
        final gate = RegExp(
          "feature_operation_allowed\\([^,]+, '${feature.key.name}', "
          "'([a-z_]+)'\\)",
        ).firstMatch(sql.substring(at));
        expect(gate?.group(1), op.value.wire, reason: op.key);
      }
    }
  });

  test('only alpha and beta ask for an explicit opt-in', () {
    Map<WorkspaceFeature, FeatureAssessment> as(FeatureMaturity m) => {
      _f: FeatureAssessment(maturity: m, rationale: 'x', evidence: ['booking']),
    };
    expect(
      featureNeedsOptIn(_f, assessments: as(FeatureMaturity.unreviewed)),
      isFalse,
    );
    expect(
      featureNeedsOptIn(_f, assessments: as(FeatureMaturity.alpha)),
      isTrue,
    );
    expect(
      featureNeedsOptIn(_f, assessments: as(FeatureMaturity.beta)),
      isTrue,
    );
    expect(
      featureNeedsOptIn(_f, assessments: as(FeatureMaturity.stable)),
      isFalse,
    );
  });

  test('an alpha may not be on by default', () {
    final defaultOn = featureManifest.values.firstWhere((e) => e.defaultOn);
    final problems = validateFeatureAssessments(
      assessments: {
        for (final f in WorkspaceFeature.values)
          f: const FeatureAssessment.unreviewed('x'),
        defaultOn.feature: _alpha,
      },
      retired: const {},
      evidenceIds: const {},
    );
    expect(problems, ['${defaultOn.feature.name}: alpha but on by default']);
  });

  test('the opt-in never changes what is effective', () {
    // Maturity is not an input of the resolver: the same stored map gives
    // the same effective set whatever the ledger says.
    final raw = resolveEnabledFeatures(const {'accessorySupplements': true});
    expect(
      effectiveFeatures(raw),
      contains(WorkspaceFeature.accessorySupplements),
    );
  });

  group('the Features screen', () {
    Future<FakeWorkspaceRepository> pump(
      WidgetTester tester, {
      Map<String, dynamic> flags = const {},
    }) async {
      tester.view.physicalSize = const Size(800, 24000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: flags,
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
                WorkspaceFeature.accessorySupplements: _alpha,
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

    testWidgets('switching on an alpha asks first; cancel writes nothing', (
      tester,
    ) async {
      final workspace = await pump(tester);
      final before = workspace.flagWrites.length;
      await tester.tap(tile(WorkspaceFeature.accessorySupplements));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-opt-in')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feature-opt-in-cancel')));
      await tester.pumpAndSettle();
      expect(workspace.flagWrites.length, before);
      expect(
        tester
            .widget<SwitchListTile>(tile(WorkspaceFeature.accessorySupplements))
            .value,
        isFalse,
      );
    });

    testWidgets('confirming writes the switch the owner chose', (tester) async {
      final workspace = await pump(tester);
      await tester.tap(tile(WorkspaceFeature.accessorySupplements));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feature-opt-in-confirm')));
      await tester.pumpAndSettle();
      expect(workspace.flagWrites.last['accessorySupplements'], isTrue);
    });

    testWidgets('an unreviewed feature switches without a question', (
      tester,
    ) async {
      final workspace = await pump(tester);
      final before = workspace.flagWrites.length;
      await tester.tap(tile(WorkspaceFeature.adminSeatBlocking));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('feature-opt-in')), findsNothing);
      expect(workspace.flagWrites.length, before + 1);
    });

    testWidgets('inquiries off says open ones can still be closed', (
      tester,
    ) async {
      await pump(tester, flags: const {'spaceInquiries': false});
      expect(
        find.descendant(
          of: tile(WorkspaceFeature.spaceInquiries),
          matching: find.textContaining('nothing new starts'),
        ),
        findsOneWidget,
      );
    });
  });
}
