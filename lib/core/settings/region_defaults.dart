// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2488 (S5 of #2483) -- the currency, country and format locale a screen
// falls back to when a workspace or a device says nothing. They are the
// registry's platform rows (`locale.default_currency`, `locale.default_country`,
// `locale.default_locale`), read here once; the compile-time copy of the
// registry's own defaults stands in while the settings load or when the
// server cannot be reached. They are DISPLAY and CREATION defaults: a
// missing financial fact (an issuer country, a money currency) is never
// filled in from them.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_settings.dart';
import 'setting_defaults.g.dart';
import 'settings.dart';

class RegionDefaults {
  const RegionDefaults({
    this.currency = SettingDefaults.localeDefaultCurrency,
    this.country = SettingDefaults.localeDefaultCountry,
    this.locale = SettingDefaults.localeDefaultLocale,
  });

  static const defaults = RegionDefaults();

  final String currency;
  final String country;
  final String locale;

  /// A registry that predates a key (an older server) keeps its default.
  factory RegionDefaults.fromSettings(SettingsSet? settings) {
    if (settings == null) return defaults;
    String read(String key, String fallback) =>
        settings.definitions.containsKey(key) ? settings.read<String>(key) : fallback;
    return RegionDefaults(
      currency: read('locale.default_currency', SettingDefaults.localeDefaultCurrency),
      country: read('locale.default_country', SettingDefaults.localeDefaultCountry),
      locale: read('locale.default_locale', SettingDefaults.localeDefaultLocale),
    );
  }
}

/// The platform's region defaults; the registry defaults while loading.
final regionDefaultsProvider = Provider<RegionDefaults>(
  (ref) => RegionDefaults.fromSettings(ref.watch(platformSettingsProvider).value),
);
