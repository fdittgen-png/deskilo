// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../l10n/app_localizations.dart';

/// Localized display name for a [CountryCatalog] code (#153 — shared by
/// the onboarding form and the workspace settings screen; the catalog
/// doc points here for the `countryName<CODE>` ARB convention).
String localizedCountryName(AppLocalizations l10n, String code) {
  return switch (code) {
    'DE' => l10n.countryNameDE,
    'CA' => l10n.countryNameCA,
    'NO' => l10n.countryNameNO,
    'MX' => l10n.countryNameMX,
    'AU' => l10n.countryNameAU,
    'JP' => l10n.countryNameJP,
    'CY' => l10n.countryNameCY,
    'EE' => l10n.countryNameEE,
    'FI' => l10n.countryNameFI,
    'GR' => l10n.countryNameGR,
    'HR' => l10n.countryNameHR,
    'IE' => l10n.countryNameIE,
    'LT' => l10n.countryNameLT,
    'LV' => l10n.countryNameLV,
    'MT' => l10n.countryNameMT,
    'SI' => l10n.countryNameSI,
    'SK' => l10n.countryNameSK,
    'BG' => l10n.countryNameBG,
    'CZ' => l10n.countryNameCZ,
    'DK' => l10n.countryNameDK,
    'HU' => l10n.countryNameHU,
    'PL' => l10n.countryNamePL,
    'RO' => l10n.countryNameRO,
    'SE' => l10n.countryNameSE,
    'AT' => l10n.countryNameAT,
    'CH' => l10n.countryNameCH,
    'FR' => l10n.countryNameFR,
    'IT' => l10n.countryNameIT,
    'ES' => l10n.countryNameES,
    'PT' => l10n.countryNamePT,
    'NL' => l10n.countryNameNL,
    'BE' => l10n.countryNameBE,
    'LU' => l10n.countryNameLU,
    'GB' => l10n.countryNameGB,
    'US' => l10n.countryNameUS,
    _ => code,
  };
}

/// The language half of a format-locale label (#713): `fr` → « Français »
/// in the reader's own UI language. The 17 languages `kFormatLocales`
/// pairs with a region.
String localizedLanguageName(AppLocalizations l10n, String code) =>
    switch (code) {
      'de' => l10n.languageNameDE,
      'en' => l10n.languageNameEN,
      'es' => l10n.languageNameES,
      'fr' => l10n.languageNameFR,
      'it' => l10n.languageNameIT,
      'nl' => l10n.languageNameNL,
      'pt' => l10n.languageNamePT,
      'pl' => l10n.languageNamePL,
      'sv' => l10n.languageNameSV,
      'da' => l10n.languageNameDA,
      'nb' => l10n.languageNameNB,
      'fi' => l10n.languageNameFI,
      'cs' => l10n.languageNameCS,
      'hu' => l10n.languageNameHU,
      'ro' => l10n.languageNameRO,
      'el' => l10n.languageNameEL,
      'ja' => l10n.languageNameJA,
      _ => code,
    };
