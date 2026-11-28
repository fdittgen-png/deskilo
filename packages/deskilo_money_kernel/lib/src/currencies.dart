// SPDX-License-Identifier: AGPL-3.0-or-later

/// #4501 (MD-06) -- one currency of the reference: its ISO 4217 [code], the [minorDigits] an amount in it carries,
/// whether a business may keep its books in it ([business], the subset the pickers offer) and, for a currency its
/// country replaced, the day it stopped being legal tender ([withdrawnOn]; a business that still holds it keeps it).
final class CurrencyRef {
  const CurrencyRef(this.code, this.minorDigits, {this.business = false, this.withdrawnOn});

  final String code;
  final int minorDigits;
  final bool business;
  final String? withdrawnOn;
}

/// #4501 (MD-06) -- THE currency reference: the currencies of ISO 4217 a business or a person may hold amounts in (the
/// funds, metals and testing codes left out), with their minor digits, in the order of their codes. The
/// server holds the same rows (`public.currency_reference`, migration 0993; test/lint/currency_reference_parity_test.dart
/// keeps the two equal, and the edge functions' `_shared/money.ts` tables). A code outside it is refused, never read
/// as two decimals.
const List<CurrencyRef> currencyReference = [
  CurrencyRef('AED', 2),
  CurrencyRef('AFN', 2),
  CurrencyRef('ALL', 2),
  CurrencyRef('AMD', 2),
  CurrencyRef('ANG', 2),
  CurrencyRef('AOA', 2),
  CurrencyRef('ARS', 2),
  CurrencyRef('AUD', 2, business: true),
  CurrencyRef('AWG', 2),
  CurrencyRef('AZN', 2),
  CurrencyRef('BAM', 2),
  CurrencyRef('BBD', 2),
  CurrencyRef('BDT', 2),
  CurrencyRef('BGN', 2, business: true, withdrawnOn: '2026-01-01'),
  CurrencyRef('BHD', 3),
  CurrencyRef('BIF', 0),
  CurrencyRef('BMD', 2),
  CurrencyRef('BND', 2),
  CurrencyRef('BOB', 2),
  CurrencyRef('BRL', 2, business: true),
  CurrencyRef('BSD', 2),
  CurrencyRef('BTN', 2),
  CurrencyRef('BWP', 2),
  CurrencyRef('BYN', 2),
  CurrencyRef('BZD', 2),
  CurrencyRef('CAD', 2, business: true),
  CurrencyRef('CDF', 2),
  CurrencyRef('CHF', 2, business: true),
  CurrencyRef('CLP', 0),
  CurrencyRef('CNY', 2, business: true),
  CurrencyRef('COP', 2),
  CurrencyRef('CRC', 2),
  CurrencyRef('CUP', 2),
  CurrencyRef('CVE', 2),
  CurrencyRef('CZK', 2, business: true),
  CurrencyRef('DJF', 0),
  CurrencyRef('DKK', 2, business: true),
  CurrencyRef('DOP', 2),
  CurrencyRef('DZD', 2),
  CurrencyRef('EGP', 2),
  CurrencyRef('ERN', 2),
  CurrencyRef('ETB', 2),
  CurrencyRef('EUR', 2, business: true),
  CurrencyRef('FJD', 2),
  CurrencyRef('FKP', 2),
  CurrencyRef('GBP', 2, business: true),
  CurrencyRef('GEL', 2),
  CurrencyRef('GHS', 2),
  CurrencyRef('GIP', 2),
  CurrencyRef('GMD', 2),
  CurrencyRef('GNF', 0),
  CurrencyRef('GTQ', 2),
  CurrencyRef('GYD', 2),
  CurrencyRef('HKD', 2, business: true),
  CurrencyRef('HNL', 2),
  CurrencyRef('HRK', 2, business: true, withdrawnOn: '2023-01-01'),
  CurrencyRef('HTG', 2),
  CurrencyRef('HUF', 2, business: true),
  CurrencyRef('IDR', 2),
  CurrencyRef('ILS', 2, business: true),
  CurrencyRef('INR', 2, business: true),
  CurrencyRef('IQD', 3),
  CurrencyRef('IRR', 2),
  CurrencyRef('ISK', 0, business: true),
  CurrencyRef('JMD', 2),
  CurrencyRef('JOD', 3),
  CurrencyRef('JPY', 0, business: true),
  CurrencyRef('KES', 2),
  CurrencyRef('KGS', 2),
  CurrencyRef('KHR', 2),
  CurrencyRef('KMF', 0),
  CurrencyRef('KPW', 2),
  CurrencyRef('KRW', 0, business: true),
  CurrencyRef('KWD', 3),
  CurrencyRef('KYD', 2),
  CurrencyRef('KZT', 2),
  CurrencyRef('LAK', 2),
  CurrencyRef('LBP', 2),
  CurrencyRef('LKR', 2),
  CurrencyRef('LRD', 2),
  CurrencyRef('LSL', 2),
  CurrencyRef('LYD', 3),
  CurrencyRef('MAD', 2),
  CurrencyRef('MDL', 2),
  CurrencyRef('MGA', 2),
  CurrencyRef('MKD', 2),
  CurrencyRef('MMK', 2),
  CurrencyRef('MNT', 2),
  CurrencyRef('MOP', 2),
  CurrencyRef('MRU', 2),
  CurrencyRef('MUR', 2),
  CurrencyRef('MVR', 2),
  CurrencyRef('MWK', 2),
  CurrencyRef('MXN', 2, business: true),
  CurrencyRef('MYR', 2),
  CurrencyRef('MZN', 2),
  CurrencyRef('NAD', 2),
  CurrencyRef('NGN', 2),
  CurrencyRef('NIO', 2),
  CurrencyRef('NOK', 2, business: true),
  CurrencyRef('NPR', 2),
  CurrencyRef('NZD', 2, business: true),
  CurrencyRef('OMR', 3),
  CurrencyRef('PAB', 2),
  CurrencyRef('PEN', 2),
  CurrencyRef('PGK', 2),
  CurrencyRef('PHP', 2),
  CurrencyRef('PKR', 2),
  CurrencyRef('PLN', 2, business: true),
  CurrencyRef('PYG', 0),
  CurrencyRef('QAR', 2),
  CurrencyRef('RON', 2, business: true),
  CurrencyRef('RSD', 2),
  CurrencyRef('RUB', 2),
  CurrencyRef('RWF', 0),
  CurrencyRef('SAR', 2),
  CurrencyRef('SBD', 2),
  CurrencyRef('SCR', 2),
  CurrencyRef('SDG', 2),
  CurrencyRef('SEK', 2, business: true),
  CurrencyRef('SGD', 2, business: true),
  CurrencyRef('SHP', 2),
  CurrencyRef('SLE', 2),
  CurrencyRef('SOS', 2),
  CurrencyRef('SRD', 2),
  CurrencyRef('SSP', 2),
  CurrencyRef('STN', 2),
  CurrencyRef('SVC', 2),
  CurrencyRef('SYP', 2),
  CurrencyRef('SZL', 2),
  CurrencyRef('THB', 2),
  CurrencyRef('TJS', 2),
  CurrencyRef('TMT', 2),
  CurrencyRef('TND', 3),
  CurrencyRef('TOP', 2),
  CurrencyRef('TRY', 2, business: true),
  CurrencyRef('TTD', 2),
  CurrencyRef('TWD', 2),
  CurrencyRef('TZS', 2),
  CurrencyRef('UAH', 2),
  CurrencyRef('UGX', 0),
  CurrencyRef('USD', 2, business: true),
  CurrencyRef('UYU', 2),
  CurrencyRef('UZS', 2),
  CurrencyRef('VES', 2),
  CurrencyRef('VND', 0),
  CurrencyRef('VUV', 0),
  CurrencyRef('WST', 2),
  CurrencyRef('XAF', 0),
  CurrencyRef('XCD', 2),
  CurrencyRef('XCG', 2),
  CurrencyRef('XOF', 0),
  CurrencyRef('XPF', 0),
  CurrencyRef('YER', 2),
  CurrencyRef('ZAR', 2, business: true),
  CurrencyRef('ZMW', 2),
  CurrencyRef('ZWG', 2),
];

final Map<String, CurrencyRef> _byCode = {for (final c in currencyReference) c.code: c};

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
/// carry?" — answered here and nowhere else, from [currencyReference]. A code
/// it does not hold has no digits: it is refused (#4501), never read as two.
abstract final class Currencies {
  /// Codes with NO minor unit: 1 unit of storage = 1 unit of money.
  static final Set<String> zeroDecimal = {
    for (final c in currencyReference)
      if (c.minorDigits == 0) c.code,
  };

  /// Codes with THREE minor digits (1 000 fils to the dinar).
  static final Set<String> threeDecimal = {
    for (final c in currencyReference)
      if (c.minorDigits == 3) c.code,
  };

  /// How many digits after the decimal separator [code] carries.
  /// A code the reference does not hold is refused with an [ArgumentError].
  static int minorDigits(String code) {
    final known = _byCode[code.trim().toUpperCase()];
    if (known == null) throw ArgumentError.value(code, 'code', 'a currency the reference does not hold');
    return known.minorDigits;
  }

  /// Whether the reference holds [code].
  static bool isKnown(String code) => _byCode.containsKey(code.trim().toUpperCase());

  /// The day [code] stopped being legal tender, or null.
  static String? withdrawnOn(String code) => _byCode[code.trim().toUpperCase()]?.withdrawnOn;

  /// Minor units per major unit: 100 for the euro, 1 for the yen, 1 000
  /// for the dinar.
  static int minorPerMajor(String code) => switch (minorDigits(code)) {
    0 => 1,
    3 => 1000,
    _ => 100,
  };

  /// A stored minor-unit amount as a major-unit number: 1 250 EUR-cents
  /// → 12.5; 1 250 JPY → 1 250.
  static double toMajor(int minor, String code) => minor / minorPerMajor(code);

  /// A major-unit number to storage, rounded to the currency's grain.
  static int toMinor(double major, String code) => (major * minorPerMajor(code)).round();

  /// The currencies an owner may pick for a workspace: every currency of
  /// a country the app knows (see `CountryCatalog`) plus the majors a
  /// community in one of those countries plausibly bills in. Ordered by
  /// code; the picker shows the symbol beside it.
  static final List<String> selectable = [
    for (final c in currencyReference)
      if (c.business) c.code,
  ];

  /// A code is well-formed: three ASCII capitals. The server enforces the
  /// same shape (0132); this lets a form say so before the round trip.
  static bool isWellFormed(String code) => RegExp(r'^[A-Z]{3}$').hasMatch(code);
}
