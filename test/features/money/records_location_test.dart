// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2378 item 4 — where the records are kept, as far as anyone declared it.
// The operator states the hosting country in the platform setting
// `records.hosting_country`; a Canadian space states its CRA authorisation
// in `records.cra_authorisation_reference`. Nothing declared is said as
// nothing declared, never inferred. A Canadian space whose records are not
// declared in Canada sees the ETA s.286 / ITA s.230 notice in its
// accounting settings; any other space does not. Expectations by hand.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/settings/active_settings.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/money/domain/records_location.dart';
import 'package:deskilo/features/money/presentation/widgets/records_location_tile.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The shipped registry with [values] in force.
SettingsSet _settings([Map<String, Object> values = const {}]) {
  final rows = jsonDecode(
    File('assets/instance/settings_registry.json').readAsStringSync(),
  ) as List;
  final base = SettingsSet.defaults([
    for (final r in rows) SettingDefinition.fromJson(r),
  ]);
  return SettingsSet(base.definitions, {...base.effective, ...values});
}

const _hosting = 'records.hosting_country';
const _cra = 'records.cra_authorisation_reference';

RecordsLocation _of(String country, [Map<String, Object> values = const {}]) =>
    RecordsLocation.fromSettings(_settings(values), issuerCountry: country);

void main() {
  group('the declaration', () {
    test('the registry ships both settings, empty: nothing declared', () {
      final s = _settings();
      expect(s.definitions[_hosting]!.scopes, [SettingScope.platform]);
      expect(s.definitions[_cra]!.scopes, [SettingScope.workspace]);
      final l = _of('CA');
      expect(l.hostingCountry, isNull);
      expect(l.craReference, isEmpty);
    });

    test(
      'the operator\'s country is read as a code, trimmed and upper case',
      () {
        expect(_of('fr', {_hosting: ' de '}).hostingCountry, 'DE');
        expect(_of('FR', {_hosting: 'DE'}).issuerCountry, 'FR');
      },
    );

    test('anything that is not a two-letter code declares nothing', () {
      for (final typed in ['Frankfurt', 'eu-central-1', 'D', 'DEU', '']) {
        expect(
          _of('CA', {_hosting: typed}).hostingCountry,
          isNull,
          reason: typed,
        );
      }
    });

    test('an older registry without the keys declares nothing', () {
      final l = RecordsLocation.fromSettings(
        SettingsSet(const {}, const {}),
        issuerCountry: 'CA',
      );
      expect(l.hostingCountry, isNull);
      expect(l.craNotice, isTrue);
      expect(
        RecordsLocation.fromSettings(null, issuerCountry: 'CA').hostingCountry,
        isNull,
      );
    });
  });

  group('the Canadian notice', () {
    test('a Canadian space on an installation declared elsewhere', () {
      expect(_of('CA', {_hosting: 'DE'}).craNotice, isTrue);
    });

    test('a Canadian space on an installation that declared nothing', () {
      expect(_of('CA').craNotice, isTrue);
    });

    test('a Canadian space on an installation declared in Canada', () {
      expect(_of('CA', {_hosting: 'CA'}).craNotice, isFalse);
    });

    test('a space of another country, wherever it is hosted', () {
      expect(_of('GB', {_hosting: 'DE'}).craNotice, isFalse);
      expect(_of('US').craNotice, isFalse);
    });
  });

  group('the accounting settings', () {
    late AppLocalizations l10n;
    setUpAll(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    Future<String> shown(
      WidgetTester tester,
      String? country, [
      Map<String, Object> values = const {},
    ]) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeSettingsProvider.overrideWithValue(_settings(values)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: RecordsLocationTile(country: country)),
          ),
        ),
      );
      final text = find.byKey(const ValueKey('records-location-text'));
      return text.evaluate().isEmpty ? '' : tester.widget<Text>(text).data!;
    }

    testWidgets(
      'a Canadian space on an EU-hosted installation sees the notice',
      (tester) async {
        final text = await shown(tester, 'CA', {_hosting: 'DE'});
        expect(text.split('\n'), [
          l10n.recordsLocationHosted('DE'),
          l10n.recordsLocationCraOutside,
          l10n.recordsLocationCraNone,
        ]);
      },
    );

    testWidgets(
      'a Canadian space on an installation that declared nothing says so',
      (tester) async {
        final text = await shown(tester, 'CA');
        expect(text.split('\n'), [
          l10n.recordsLocationUndeclared,
          l10n.recordsLocationCraNotice,
          l10n.recordsLocationCraNone,
        ]);
      },
    );

    testWidgets('its recorded authorisation is shown with it', (tester) async {
      final text = await shown(tester, 'CA', {
        _hosting: 'DE',
        _cra: 'CRA-2026-0042',
      });
      expect(text, contains(l10n.recordsLocationCraReference('CRA-2026-0042')));
    });

    testWidgets('nothing declared is said as nothing declared', (tester) async {
      final text = await shown(tester, 'FR');
      expect(text, l10n.recordsLocationUndeclared);
    });

    testWidgets('a Canadian space hosted in Canada reads no notice', (
      tester,
    ) async {
      final text = await shown(tester, 'CA', {_hosting: 'CA'});
      expect(text, l10n.recordsLocationHosted('CA'));
    });

    testWidgets('no country known yet, no tile', (tester) async {
      await shown(tester, null);
      expect(find.byKey(const ValueKey('records-location')), findsNothing);
    });
  });
}
