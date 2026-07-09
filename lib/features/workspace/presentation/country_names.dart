// SPDX-License-Identifier: MIT
import '../../../l10n/app_localizations.dart';

/// Localized display name for a [CountryCatalog] code (#153 — shared by
/// the onboarding form and the workspace settings screen; the catalog
/// doc points here for the `countryName<CODE>` ARB convention).
String localizedCountryName(AppLocalizations? l10n, String code) {
  return switch (code) {
    'DE' => l10n?.countryNameDE ?? 'Germany',
    'AT' => l10n?.countryNameAT ?? 'Austria',
    'CH' => l10n?.countryNameCH ?? 'Switzerland',
    'FR' => l10n?.countryNameFR ?? 'France',
    'IT' => l10n?.countryNameIT ?? 'Italy',
    'ES' => l10n?.countryNameES ?? 'Spain',
    'PT' => l10n?.countryNamePT ?? 'Portugal',
    'NL' => l10n?.countryNameNL ?? 'Netherlands',
    'BE' => l10n?.countryNameBE ?? 'Belgium',
    'LU' => l10n?.countryNameLU ?? 'Luxembourg',
    'GB' => l10n?.countryNameGB ?? 'United Kingdom',
    'US' => l10n?.countryNameUS ?? 'United States',
    _ => code,
  };
}
