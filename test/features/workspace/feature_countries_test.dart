// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2454 -- a feature declared for some countries is off in another one, the
// stored flag survives, null means everywhere, the requires chain still
// applies on top, and the generated registry carries the list (pgTAP 229
// proves the server's twin).
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/workspace/domain/feature_registry_sql.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/presentation/country_change_confirm.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Set<WorkspaceFeature> _allOn() => resolveEnabledFeatures({
  for (final f in WorkspaceFeature.values) f.name: true,
});

void main() {
  test('the Union is the eu_member rows, not a list typed here', () {
    expect(featureAvailableIn({featureCountriesEu}, 'fr'), isTrue);
    expect(featureAvailableIn({featureCountriesEu}, 'DE'), isTrue);
    expect(featureAvailableIn({featureCountriesEu}, 'GB'), isFalse);
    expect(featureAvailableIn({featureCountriesEu}, 'CH'), isFalse);
    expect(ActiveTaxReference.current.isEu('GR'), isTrue);
  });

  test('null restricts nothing, and an unknown country restricts nothing', () {
    expect(featureAvailableIn(null, 'GB'), isTrue);
    expect(featureAvailableIn({'FR'}, null), isTrue);
    expect(featureAvailableIn({'FR'}, ''), isTrue);
    expect(featureAvailableIn({'FR', 'DE'}, 'de'), isTrue);
    expect(featureAvailableIn({'FR', 'DE'}, 'ES'), isFalse);
  });

  test('the EC Sales List is off outside the Union and on inside it', () {
    final raw = _allOn();
    expect(effectiveFeatures(raw, country: 'FR'), contains(WorkspaceFeature.recapitulativeStatement));
    expect(effectiveFeatures(raw, country: 'DE'), contains(WorkspaceFeature.recapitulativeStatement));
    expect(effectiveFeatures(raw, country: 'GB'), isNot(contains(WorkspaceFeature.recapitulativeStatement)));
    // no country given: today's behaviour
    expect(effectiveFeatures(raw), contains(WorkspaceFeature.recapitulativeStatement));
  });

  test('the stored flag survives a country switch and every other feature is unchanged', () {
    final raw = _allOn();
    final gb = effectiveFeatures(raw, country: 'GB');
    expect(raw, contains(WorkspaceFeature.recapitulativeStatement));
    expect(gb, equals(effectiveFeatures(raw)..remove(WorkspaceFeature.recapitulativeStatement)));
    expect(effectiveFeatures(raw, country: 'FR'), equals(effectiveFeatures(raw)));
  });

  test('the generated registry carries the list for the gated feature only', () {
    final json = featureRegistryJson();
    expect(json, contains('"recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]}'));
    expect('"countries"'.allMatches(json), hasLength(featureManifest.values.where((e) => e.availableIn != null).length));
  });

  test('every country in a list is the Union token or a two-letter code', () {
    for (final e in featureManifest.values) {
      for (final c in e.availableIn ?? const <String>{}) {
        expect(c == featureCountriesEu || RegExp(r'^[A-Z]{2}$').hasMatch(c), isTrue, reason: '${e.feature.name}: $c');
      }
    }
  });

  test('moving to GB turns the EC Sales List off; moving within the Union does not', () {
    final on = effectiveFeatures(_allOn(), country: 'FR');
    expect(featuresLostInCountry(on, 'GB'), [WorkspaceFeature.recapitulativeStatement]);
    expect(featuresLostInCountry(on, 'DE'), isEmpty);
    expect(featuresLostInCountry(const [], 'GB'), isEmpty);
  });

  testWidgets('the owner is asked first, with the features named; cancel changes nothing', (tester) async {
    bool? answer;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('go'),
          onPressed: () async => answer = await confirmCountryChange(
            context,
            'GB',
            [WorkspaceFeature.recapitulativeStatement],
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('country-change-body')), findsOneWidget);
    expect(find.textContaining('United Kingdom'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('country-change-cancel')));
    await tester.pumpAndSettle();
    expect(answer, isFalse);

    await tester.tap(find.byKey(const ValueKey('go')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('country-change-confirm')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
