// SPDX-License-Identifier: 0BSD
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../country/country_catalog.dart';

part 'device_locale.g.dart';

/// #1303 S1 — the locale the DEVICE reports, not the app's language
/// override: where the person creating a workspace most likely is.
///
/// A provider so a test can set it; the app reads the platform.
@Riverpod(keepAlive: true)
Locale deviceLocale(Ref ref) => PlatformDispatcher.instance.locale;

/// The country a new workspace starts from, derived from [device].
///
/// The device's own region when the catalog knows it (`fr_CH` → CH); else
/// a language spoken as the main language of exactly one catalog country
/// (`de` → DE, `it` → IT); else the catalog's own fallback, France — the
/// same answer `CountryCatalog.byCode` gives an unknown code. Never inferred
/// further: currency and time zone follow the country and stay editable,
/// and nothing legal or fiscal is derived from a locale.
Country initialCountryFor(Locale? device) {
  final region = device?.countryCode;
  if (region != null && CountryCatalog.isKnown(region)) {
    return CountryCatalog.byCode(region);
  }
  final byLanguage = switch (device?.languageCode) {
    'fr' => 'FR',
    'de' => 'DE',
    'es' => 'ES',
    'it' => 'IT',
    'nl' => 'NL',
    'pt' => 'PT',
    'pl' => 'PL',
    _ => null,
  };
  return CountryCatalog.byCode(byLanguage ?? 'FR');
}
