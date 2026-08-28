// SPDX-License-Identifier: 0BSD

/// ISO 4217, as much of it as an amount needs (#711).
///
/// THE APP STORES MONEY IN MINOR UNITS — every `_cents` column, every
/// `amountCents` field. That name was honest for the euro and wrong for
/// a third of the world: a yen has no minor unit, a dinar has three.
/// Rendering, parsing and the payment gateways all divided by 100
/// unconditionally, which is a 100× error in a Japanese workspace and
/// a 10× one in a Kuwaiti one.
///
/// One table, one question — "how many minor digits does this code
/// carry?" — answered here and nowhere else. Anything not listed is 2,
/// which is what ISO says for the overwhelming majority.
abstract final class Currencies {
  /// Codes with NO minor unit: 1 unit of storage = 1 unit of money.
  static const Set<String> zeroDecimal = {
    'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', 'PYG', 'RWF',
    'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF',
  };

  /// Codes with THREE minor digits (1 000 fils to the dinar).
  static const Set<String> threeDecimal = {
    'BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND',
  };

  /// How many digits after the decimal separator [code] carries.
  static int minorDigits(String code) {
    final upper = code.toUpperCase();
    if (zeroDecimal.contains(upper)) return 0;
    if (threeDecimal.contains(upper)) return 3;
    return 2;
  }

  /// Minor units per major unit: 100 for the euro, 1 for the yen, 1 000
  /// for the dinar.
  static int minorPerMajor(String code) => switch (minorDigits(code)) {
        0 => 1,
        3 => 1000,
        _ => 100,
      };

  /// A stored minor-unit amount as a major-unit number: 1 250 EUR-cents
  /// → 12.5; 1 250 JPY → 1 250.
  static double toMajor(int minor, String code) =>
      minor / minorPerMajor(code);

  /// A major-unit number to storage, rounded to the currency's grain.
  static int toMinor(double major, String code) =>
      (major * minorPerMajor(code)).round();

  /// The currencies an owner may pick for a workspace: every currency of
  /// a country the app knows (see `CountryCatalog`) plus the majors a
  /// community in one of those countries plausibly bills in. Ordered by
  /// code; the picker shows the symbol beside it.
  static const List<String> selectable = [
    'AUD', 'BGN', 'BRL', 'CAD', 'CHF', 'CNY', 'CZK', 'DKK', 'EUR', 'GBP',
    'HKD', 'HRK', 'HUF', 'ILS', 'INR', 'ISK', 'JPY', 'KRW', 'MXN', 'NOK',
    'NZD', 'PLN', 'RON', 'SEK', 'SGD', 'TRY', 'USD', 'ZAR',
  ];

  /// A code is well-formed: three ASCII capitals. The server enforces the
  /// same shape (0132); this lets a form say so before the round trip.
  static bool isWellFormed(String code) => RegExp(r'^[A-Z]{3}$').hasMatch(code);
}
