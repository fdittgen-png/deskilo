// SPDX-License-Identifier: 0BSD
import '../../../l10n/app_localizations.dart';

/// Localized display name for a [CountryCatalog] code (#153 — shared by
/// the onboarding form and the workspace settings screen; the catalog
/// doc points here for the `countryName<CODE>` ARB convention).
String localizedCountryName(AppLocalizations? l10n, String code) {
  return switch (code) {
    'DE' => l10n?.countryNameDE ?? 'Germany',
    'CY' => l10n?.countryNameCY ?? 'Cyprus',
    'EE' => l10n?.countryNameEE ?? 'Estonia',
    'FI' => l10n?.countryNameFI ?? 'Finland',
    'GR' => l10n?.countryNameGR ?? 'Greece',
    'HR' => l10n?.countryNameHR ?? 'Croatia',
    'IE' => l10n?.countryNameIE ?? 'Ireland',
    'LT' => l10n?.countryNameLT ?? 'Lithuania',
    'LV' => l10n?.countryNameLV ?? 'Latvia',
    'MT' => l10n?.countryNameMT ?? 'Malta',
    'SI' => l10n?.countryNameSI ?? 'Slovenia',
    'SK' => l10n?.countryNameSK ?? 'Slovakia',
    'BG' => l10n?.countryNameBG ?? 'Bulgaria',
    'CZ' => l10n?.countryNameCZ ?? 'Czechia',
    'DK' => l10n?.countryNameDK ?? 'Denmark',
    'HU' => l10n?.countryNameHU ?? 'Hungary',
    'PL' => l10n?.countryNamePL ?? 'Poland',
    'RO' => l10n?.countryNameRO ?? 'Romania',
    'SE' => l10n?.countryNameSE ?? 'Sweden',
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
