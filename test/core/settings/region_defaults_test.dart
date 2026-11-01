// SPDX-License-Identifier: AGPL-3.0-or-later
// #2488 -- the display and creation fallbacks are platform settings: a
// stored platform value changes a device with no workspace and nothing
// else; a workspace's own currency still wins; the seeded choices cover
// exactly the catalogue and the format locales the app knows.
import 'dart:io';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/workspace_currency.dart';
import 'package:deskilo/core/locale/device_locale.dart';
import 'package:deskilo/core/settings/region_defaults.dart';
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/settings/seed.dart';

SettingsSet _stored({String? currency, String? country, String? locale}) {
  final defs = {
    for (final s in settingSeeds.where((s) => s.row.key.startsWith('locale.default_')))
      s.row.key: SettingDefinition(
        key: s.row.key,
        type: SettingType.choice,
        defaultValue: s.row.defaultValue as String,
        group: 'region',
        scopes: {SettingScope.platform},
        choices: [for (final c in s.row.choices ?? const <String>[]) c],
      ),
  };
  return SettingsSet(defs, {
    'locale.default_currency': currency ?? 'EUR',
    'locale.default_country': country ?? 'FR',
    'locale.default_locale': locale ?? 'en_US',
  });
}

List<String> _choices(String key) =>
    [for (final c in settingSeeds.singleWhere((s) => s.row.key == key).row.choices!) c];

void main() {
  test('the registry defaults are what the app used until now', () {
    expect(SettingDefaults.localeDefaultCurrency, 'EUR');
    expect(SettingDefaults.localeDefaultCountry, 'FR');
    expect(SettingDefaults.localeDefaultLocale, 'en_US');
    expect(RegionDefaults.fromSettings(null).currency, 'EUR');
    expect(AppFormat.fallback.currencyCode, 'EUR');
    expect(AppFormat.fallback.locale, 'en_US');
    WorkspaceCurrency.reset();
    expect(WorkspaceCurrency.code, 'EUR');
  });

  test('the platform default currency is the ambient grain until a workspace installs its own', () {
    WorkspaceCurrency.installDefault('JPY');
    expect(WorkspaceCurrency.code, 'JPY');
    expect(WorkspaceCurrency.minorPerMajor, 1);
    WorkspaceCurrency.install('CHF');
    expect(WorkspaceCurrency.code, 'CHF');
    WorkspaceCurrency.reset();
    expect(WorkspaceCurrency.code, 'EUR');
  });

  test('a stored platform value is read; an older server keeps the defaults', () {
    final d = RegionDefaults.fromSettings(
        _stored(currency: 'CHF', country: 'CH', locale: 'de_CH'));
    expect((d.currency, d.country, d.locale), ('CHF', 'CH', 'de_CH'));
    final old = RegionDefaults.fromSettings(SettingsSet(const {}, const {}));
    expect(old.currency, 'EUR');
  });

  test('the default country starts a device whose region and language say nothing', () {
    const unknown = Locale('sw', 'KE');
    expect(initialCountryFor(unknown).code, 'FR');
    expect(initialCountryFor(unknown, fallbackCountry: 'DE').code, 'DE');
    expect(initialCountryFor(const Locale('fr', 'CH'), fallbackCountry: 'DE').code,
        'CH',
        reason: 'the device region still wins');
    expect(initialCountryFor(const Locale('it'), fallbackCountry: 'DE').code, 'IT');
  });

  test('every catalogue country and currency is a choice, and nothing else is', () {
    expect(_choices('locale.default_country'),
        [for (final c in CountryCatalog.countries) c.code]);
    expect(_choices('locale.default_currency').toSet(),
        {for (final c in CountryCatalog.countries) c.currencyCode});
    expect(_choices('locale.default_locale'), kFormatLocales);
    for (final key in ['locale.default_country', 'locale.default_currency', 'locale.default_locale']) {
      final row = settingSeeds.singleWhere((s) => s.row.key == key).row;
      expect(_choices(key), contains(row.defaultValue), reason: key);
    }
  });

  test('the setup questionnaire offers the same format locales', () {
    final js = File('web/setup_params.js').readAsStringSync();
    final listed = RegExp(r"const FORMAT_LOCALES=\[(.*?)\]").firstMatch(js)!.group(1)!;
    expect(RegExp(r"'([a-zA-Z_]+)'").allMatches(listed).map((m) => m.group(1)).toList(),
        kFormatLocales);
  });
}
