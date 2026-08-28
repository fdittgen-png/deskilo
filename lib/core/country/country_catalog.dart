// SPDX-License-Identifier: 0BSD

/// How a country's banks identify an account — the shape the payment
/// instructions take (#711).
enum BankingScheme {
  /// IBAN (+ BIC): the euro area, Switzerland, Norway and the UK's IBAN
  /// form. One field, checksummed.
  sepa,

  /// Sort code + account number.
  uk,

  /// ABA routing number + account number.
  us,

  /// Transit number + institution number + account number.
  ca,
}

/// One country the app knows how to bill in (spec §3).
class Country {
  const Country(
    this.code,
    this.currencyCode,
    this.defaultTimezone, {
    this.scheme = BankingScheme.sepa,
  });

  /// ISO 3166-1 alpha-2.
  final String code;

  /// The ISO 4217 code a workspace here bills in by default.
  final String currencyCode;

  /// The IANA zone a workspace here keeps time in by default — the
  /// capital's. A country spanning several (US, CA, AU) gets the one
  /// most of its coworkings sit in; the owner picks another if not.
  final String defaultTimezone;

  final BankingScheme scheme;
}

/// The countries a workspace may be in (#711 — 32, aligned with the VAT
/// catalogue so every country the app can DECLARE tax for is a country
/// it can be BASED in; the earlier 13 left an owner in Dublin or
/// Warsaw picking a neighbour and typing the rest by hand).
abstract final class CountryCatalog {
  static const List<Country> countries = [
    // ── euro area ──
    Country('AT', 'EUR', 'Europe/Vienna'),
    Country('BE', 'EUR', 'Europe/Brussels'),
    Country('CY', 'EUR', 'Asia/Nicosia'),
    Country('DE', 'EUR', 'Europe/Berlin'),
    Country('EE', 'EUR', 'Europe/Tallinn'),
    Country('ES', 'EUR', 'Europe/Madrid'),
    Country('FI', 'EUR', 'Europe/Helsinki'),
    Country('FR', 'EUR', 'Europe/Paris'),
    Country('GR', 'EUR', 'Europe/Athens'),
    Country('HR', 'EUR', 'Europe/Zagreb'),
    Country('IE', 'EUR', 'Europe/Dublin'),
    Country('IT', 'EUR', 'Europe/Rome'),
    Country('LT', 'EUR', 'Europe/Vilnius'),
    Country('LU', 'EUR', 'Europe/Luxembourg'),
    Country('LV', 'EUR', 'Europe/Riga'),
    Country('MT', 'EUR', 'Europe/Malta'),
    Country('NL', 'EUR', 'Europe/Amsterdam'),
    Country('PT', 'EUR', 'Europe/Lisbon'),
    Country('SI', 'EUR', 'Europe/Ljubljana'),
    Country('SK', 'EUR', 'Europe/Bratislava'),
    // ── EU, own currency ──
    Country('BG', 'BGN', 'Europe/Sofia'),
    Country('CZ', 'CZK', 'Europe/Prague'),
    Country('DK', 'DKK', 'Europe/Copenhagen'),
    Country('HU', 'HUF', 'Europe/Budapest'),
    Country('PL', 'PLN', 'Europe/Warsaw'),
    Country('RO', 'RON', 'Europe/Bucharest'),
    Country('SE', 'SEK', 'Europe/Stockholm'),
    // ── Europe, outside the EU ──
    Country('CH', 'CHF', 'Europe/Zurich'),
    Country('NO', 'NOK', 'Europe/Oslo'),
    Country('GB', 'GBP', 'Europe/London', scheme: BankingScheme.uk),
    // ── North America ──
    Country('US', 'USD', 'America/New_York', scheme: BankingScheme.us),
    Country('CA', 'CAD', 'America/Toronto', scheme: BankingScheme.ca),
  ];

  /// The catalog entry for [code]; an unknown code (old data, hand-typed
  /// import) reads as a euro/Paris workspace rather than crashing a form.
  static Country byCode(String code) => countries.firstWhere(
        (c) => c.code == code.toUpperCase(),
        orElse: () => countries.firstWhere((c) => c.code == 'FR'),
      );

  static bool isKnown(String code) =>
      countries.any((c) => c.code == code.toUpperCase());
}
