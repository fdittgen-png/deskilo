// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1851 — off stops NEW business; existing work stays serviceable. The
// matrix below is written out by hand and is the same one pgTAP 110 asks
// the server.
import 'dart:io';

import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
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

  test('the newest migration of each classified function gates it with '
      'exactly its classes', () {
    // #1851 C — the server half of the matrix: for each function, the
    // newest migration that patches it, and the classes its gate names.
    final migrations = Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    final classes = <String, Set<String>>{};
    final feature = <String, String>{};
    for (final e in featureOperationClasses.entries) {
      for (final op in e.value.entries) {
        final fn = op.key.split('#').first;
        (classes[fn] ??= {}).add(op.value.wire);
        feature[fn] = e.key.name;
      }
    }
    for (final fn in classes.keys) {
      String? patch;
      for (final f in migrations) {
        final sql = f.readAsStringSync();
        final at = sql.indexOf("pg_get_functiondef('public.$fn(");
        if (at < 0) continue;
        final end = sql.indexOf('pg_get_functiondef(', at + 20);
        patch = sql.substring(at, end < 0 ? sql.length : end);
        break;
      }
      expect(patch, isNotNull, reason: '$fn is not patched');
      final gated = RegExp(
        "feature_operation_allowed\\([^,]+, '${feature[fn]}',",
      ).hasMatch(patch!);
      expect(gated, isTrue, reason: '$fn is not gated by ${feature[fn]}');
      final named = {
        for (final m in RegExp(
          "'(accept_new|service_existing|suspended)'",
        ).allMatches(patch))
          m.group(1)!,
      };
      expect(named, classes[fn], reason: fn);
    }
  });

  test('only a server at least as new as this build is said to keep work', () {
    for (final f in featureOperationClasses.keys) {
      expect(
        serverKeepsExistingWork(f, SchemaCompatibility.current),
        isTrue,
        reason: '${f.name}: this build needs its classes',
      );
      expect(serverKeepsExistingWork(f, SchemaCompatibility.ahead), isTrue);
      for (final c in [
        SchemaCompatibility.behind,
        SchemaCompatibility.unknown,
        null,
      ]) {
        expect(serverKeepsExistingWork(f, c), isFalse, reason: '$c');
      }
    }
    expect(
      serverKeepsExistingWork(
        WorkspaceFeature.kioskMode,
        SchemaCompatibility.current,
      ),
      isFalse,
      reason: 'an unclassified feature claims nothing',
    );
  });

  test('every classified feature says from which server schema it holds', () {
    expect(
      featureOperationSince.keys.toSet(),
      featureOperationClasses.keys.toSet(),
    );
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
      SchemaCompatibility compatibility = SchemaCompatibility.current,
    }) async {
      tester.view.physicalSize = const Size(800, 24000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: flags,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...standardTestOverrides(workspace: workspace),
            schemaCompatibilityProvider.overrideWith(
              (_) async => compatibility,
            ),
          ],
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
          matching: find.textContaining('can still be answered and closed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an older or silent server is not claimed to keep open work', (
      tester,
    ) async {
      for (final c in [SchemaCompatibility.behind, SchemaCompatibility.unknown]) {
        await pump(
          tester,
          flags: const {'customRoles': false},
          compatibility: c,
        );
        final note = find.descendant(
          of: tile(WorkspaceFeature.customRoles),
          matching: find.textContaining('could not confirm'),
        );
        expect(note, findsOneWidget, reason: c.name);
        expect(
          find.descendant(
            of: tile(WorkspaceFeature.customRoles),
            matching: find.textContaining('can still be answered'),
          ),
          findsNothing,
          reason: c.name,
        );
      }
    });
  });
}
