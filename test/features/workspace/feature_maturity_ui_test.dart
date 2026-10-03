// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1850 — the maturity badges and filter on the real Features screen.
import 'package:deskilo/features/workspace/domain/feature_lifecycle.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/screens/features_screen.dart';
import 'package:deskilo/features/workspace/presentation/widgets/feature_maturity_badge.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

// Independent fixtures: the shipped ledger classifies nothing yet, so
// the combinations the screen must render are stated here.
const _stableDeprecated = FeatureAssessment(
  maturity: FeatureMaturity.stable,
  lifecycle: FeatureLifecycle.deprecated,
  rationale: 'fixture',
  evidence: ['booking'],
  deprecatedIn: '1.4.0',
);
const _alpha = FeatureAssessment(
  maturity: FeatureMaturity.alpha,
  rationale: 'fixture',
);

final _fixture = {
  for (final f in WorkspaceFeature.values)
    f: const FeatureAssessment.unreviewed('fixture'),
  WorkspaceFeature.carnets: _stableDeprecated,
  WorkspaceFeature.services: _alpha,
};

Future<void> _pumpScreen(
  WidgetTester tester, {
  Map<WorkspaceFeature, FeatureAssessment>? assessments,
  Map<String, dynamic> featureFlags = const {},
}) async {
  tester.view.physicalSize = const Size(800, 24000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: featureFlags,
        ),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeaturesScreen(assessments: assessments ?? featureAssessments),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The screen opens on the process overview; the switches carry badges.
  await tester.tap(find.byKey(const ValueKey('features-view-switches')));
  await tester.pumpAndSettle();
}

Future<void> _filter(WidgetTester tester, FeatureMaturityFilter f) async {
  await tester.tap(find.byKey(const ValueKey('features-filter-maturity')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('features-maturity-${f.name}')).last);
  await tester.pumpAndSettle();
}

Future<void> _pumpBadge(
  WidgetTester tester,
  FeatureAssessment a, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: SizedBox(width: 200, child: FeatureMaturityBadge(assessment: a)),
      ),
    ),
  ),
);

void main() {
  testWidgets('every row of the real registry reads its assessment', (
    t,
  ) async {
    await _pumpScreen(t);
    final rows = find.byType(FeatureMaturityBadge);
    expect(rows, findsNWidgets(featureManifest.length));
    // #1850 B — the ledger-backed betas read Beta, every other row
    // Unreviewed; nothing is stable and nothing is past active.
    final beta = featureAssessments.values
        .where((a) => a.maturity == FeatureMaturity.beta)
        .length;
    expect(beta, greaterThan(0));
    expect(find.text('Beta'), findsNWidgets(beta));
    expect(
      find.text('Unreviewed'),
      findsNWidgets(featureManifest.length - beta),
    );
    expect(find.byKey(const ValueKey('feature-lifecycle')), findsNothing);
  });

  testWidgets('stable + deprecated shows both words and one sentence', (
    t,
  ) async {
    final semantics = t.ensureSemantics();
    await _pumpBadge(t, _stableDeprecated);
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Deprecated'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Maturity Stable, Deprecated'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('alpha on a switch that is off is still labelled alpha', (
    t,
  ) async {
    await _pumpScreen(
      t,
      assessments: _fixture,
      featureFlags: const {'services': false},
    );
    final tile = find.byKey(const ValueKey('feature-services'));
    expect(t.widget<SwitchListTile>(tile).value, isFalse);
    expect(
      find.descendant(of: tile, matching: find.text('Alpha')),
      findsOneWidget,
    );
  });

  testWidgets('the filter narrows the list by maturity and lifecycle', (
    t,
  ) async {
    await _pumpScreen(t, assessments: _fixture);
    await _filter(t, FeatureMaturityFilter.deprecated);
    expect(find.byType(FeatureMaturityBadge), findsOneWidget);
    expect(find.byKey(const ValueKey('feature-carnets')), findsOneWidget);

    await _filter(t, FeatureMaturityFilter.alpha);
    expect(find.byType(FeatureMaturityBadge), findsOneWidget);
    expect(find.byKey(const ValueKey('feature-services')), findsOneWidget);

    await _filter(t, FeatureMaturityFilter.beta);
    expect(find.byKey(const ValueKey('features-no-match')), findsOneWidget);

    await _filter(t, FeatureMaturityFilter.all);
    expect(
      find.byType(FeatureMaturityBadge),
      findsNWidgets(featureManifest.length),
    );
  });

  testWidgets('the shipped ledger has no stable row', (t) async {
    await _pumpScreen(t);
    await _filter(t, FeatureMaturityFilter.stable);
    expect(find.byKey(const ValueKey('features-no-match')), findsOneWidget);
  });

  testWidgets('five locales name every stage in their own words', (t) async {
    const expected = {
      'en': ('Unreviewed', 'Deprecated'),
      'fr': ('Non évaluée', 'Dépréciée'),
      'de': ('Nicht bewertet', 'Veraltet'),
      'es': ('Sin evaluar', 'Obsoleta'),
      'it': ('Non valutata', 'Deprecata'),
    };
    for (final e in expected.entries) {
      await _pumpBadge(
        t,
        const FeatureAssessment(
          maturity: FeatureMaturity.unreviewed,
          lifecycle: FeatureLifecycle.deprecated,
          deprecatedIn: '1',
          rationale: 'fixture',
        ),
        locale: Locale(e.key),
      );
      await t.pumpAndSettle();
      expect(find.text(e.value.$1), findsOneWidget, reason: e.key);
      expect(find.text(e.value.$2), findsOneWidget, reason: e.key);
    }
  });

  testWidgets('large text wraps the badges instead of overflowing', (t) async {
    await _pumpBadge(t, _stableDeprecated, textScale: 2);
    expect(t.takeException(), isNull);
  });
}
