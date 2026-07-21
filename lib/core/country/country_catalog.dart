// SPDX-License-Identifier: 0BSD

/// A country selectable at workspace creation. The country drives the
/// default currency and time zone (spec §3, decided 2026-07-07); both stay
/// owner-overridable in the form.
class Country {
  const Country(this.code, this.currencyCode, this.defaultTimezone);

  /// ISO 3166-1 alpha-2.
  final String code;

  /// ISO 4217.
  final String currencyCode;

  /// IANA zone id.
  final String defaultTimezone;
}

/// Launch catalog — extend freely; localized display names live in the
/// workspace ARB fragment as `countryName<CODE>` keys (all 5 locales).
abstract final class CountryCatalog {
  static const List<Country> countries = [
    Country('DE', 'EUR', 'Europe/Berlin'),
    Country('AT', 'EUR', 'Europe/Vienna'),
    Country('CH', 'CHF', 'Europe/Zurich'),
    Country('FR', 'EUR', 'Europe/Paris'),
    Country('IT', 'EUR', 'Europe/Rome'),
    Country('ES', 'EUR', 'Europe/Madrid'),
    Country('PT', 'EUR', 'Europe/Lisbon'),
    Country('NL', 'EUR', 'Europe/Amsterdam'),
    Country('BE', 'EUR', 'Europe/Brussels'),
    Country('LU', 'EUR', 'Europe/Luxembourg'),
    Country('GB', 'GBP', 'Europe/London'),
    Country('US', 'USD', 'America/New_York'),
  ];

  static Country byCode(String code) =>
      countries.firstWhere((c) => c.code == code);
}
