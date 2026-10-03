// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1870 — the canonical accounting amount: a currency, its minor-unit
// exponent and an exact integer count of minor units. Nothing here is a
// binary floating-point number, and nothing rounds without a named
// policy.
//
// Pure Dart: the CLI, the exports and the handoff import it.

import '../../../core/i18n/currencies.dart';

/// Why an amount, a rate or a conversion was refused. Typed, so a
/// consumer can block one document instead of guessing.
enum AccountingError {
  /// A currency code with no reviewed exponent: never assumed to be 2.
  unsupportedCurrency,

  /// More than ±(2^53 − 1) minor units: JSON numbers stop being exact
  /// there, so the value cannot travel.
  outOfRange,

  /// Two amounts in different currencies met in one sum.
  currencyMismatch,

  /// A decimal string that is not plain `[-]digits[.digits]`.
  malformedDecimal,

  /// More fractional digits than the currency carries.
  excessPrecision,

  /// A conversion with no approved rate, or a rate for another pair.
  missingRate,
}

class AccountingException implements Exception {
  const AccountingException(this.error, this.detail);
  final AccountingError error;
  final String detail;

  @override
  String toString() => 'AccountingException(${error.name}: $detail)';
}

/// The largest magnitude that survives JSON (an IEEE double) exactly.
const int maxSafeMinor = 9007199254740991;

/// Currencies whose exponent was reviewed: the zero- and three-decimal
/// tables plus the two-decimal codes the app offers. Anything else is
/// refused rather than read as two decimals.
Set<String> get supportedCurrencies => {
  ...Currencies.zeroDecimal,
  ...Currencies.threeDecimal,
  ...Currencies.selectable,
};

/// The exponent of [currency], or a refusal.
int exponentOf(String currency) {
  final code = currency.trim().toUpperCase();
  if (!supportedCurrencies.contains(code)) {
    throw AccountingException(AccountingError.unsupportedCurrency, code);
  }
  return Currencies.minorDigits(code);
}

/// How a non-integer result becomes minor units. There is no default:
/// the caller names the policy its jurisdiction or channel approved.
enum RoundingPolicy {
  /// Halves away from zero (the common commercial rule).
  halfUp,

  /// Halves to the even neighbour (banker's rounding).
  halfEven,
}

BigInt _divide(BigInt numerator, BigInt denominator, RoundingPolicy policy) {
  if (denominator.isNegative) {
    numerator = -numerator;
    denominator = -denominator;
  }
  final negative = numerator.isNegative;
  final n = numerator.abs();
  var q = n ~/ denominator;
  final r = n.remainder(denominator);
  final twice = r * BigInt.two;
  final up = switch (policy) {
    RoundingPolicy.halfUp => twice >= denominator,
    RoundingPolicy.halfEven =>
      twice > denominator || (twice == denominator && q.isOdd),
  };
  if (up) q += BigInt.one;
  return negative ? -q : q;
}

/// An exact decimal: [units] / 10^[scale]. Rates, percentages and
/// exchange rates are carried this way, never as a double.
class ExactDecimal {
  const ExactDecimal._(this.units, this.scale);

  /// `9.975`, `0.90`, `-12`: plain decimal digits only.
  factory ExactDecimal.parse(String text) {
    final s = text.trim();
    final m = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(s);
    if (m == null) {
      throw AccountingException(AccountingError.malformedDecimal, text);
    }
    final fraction = m.group(3) ?? '';
    final units = BigInt.parse('${m.group(1)}${m.group(2)}$fraction');
    return ExactDecimal._(units, fraction.length);
  }

  final BigInt units;
  final int scale;

  BigInt get denominator => BigInt.from(10).pow(scale);

  /// This value read as a percentage: `9.975` → `0.09975`, exactly.
  ExactDecimal get percentAsFraction => ExactDecimal._(units, scale + 2);

  bool operator >(ExactDecimal other) =>
      units * other.denominator > other.units * denominator;

  @override
  bool operator ==(Object other) =>
      other is ExactDecimal &&
      units * other.denominator == other.units * denominator;

  @override
  int get hashCode {
    // Equal values hash alike whatever their scale: 0.90 and 0.9.
    var u = units;
    var s = scale;
    while (s > 0 && u.remainder(BigInt.from(10)) == BigInt.zero) {
      u = u ~/ BigInt.from(10);
      s--;
    }
    return Object.hash(u, s);
  }

  @override
  String toString() {
    if (scale == 0) return units.toString();
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    final sign = units.isNegative ? '-' : '';
    return '$sign${digits.substring(0, digits.length - scale)}.'
        '${digits.substring(digits.length - scale)}';
  }
}

/// An exact amount of money.
class AccountingAmount {
  AccountingAmount._(this.currency, this.exponent, this.minor);

  /// [minor] units of [currency]; refused when the currency has no
  /// reviewed exponent or the value cannot travel exactly.
  factory AccountingAmount(String currency, int minor) {
    final code = currency.trim().toUpperCase();
    final exponent = exponentOf(code);
    _checkRange(BigInt.from(minor), code);
    return AccountingAmount._(code, exponent, minor);
  }

  /// A major-unit decimal string (`120.00`, `1149.75`, `5000`), exact:
  /// more fractional digits than the currency carries are refused, not
  /// rounded.
  factory AccountingAmount.parse(String currency, String major) {
    final code = currency.trim().toUpperCase();
    final exponent = exponentOf(code);
    final d = ExactDecimal.parse(major);
    if (d.scale > exponent) {
      throw AccountingException(
        AccountingError.excessPrecision,
        '$major $code',
      );
    }
    final minor = d.units * BigInt.from(10).pow(exponent - d.scale);
    _checkRange(minor, code);
    return AccountingAmount._(code, exponent, minor.toInt());
  }

  /// The wire form: the minor units travel as a STRING, so no JSON
  /// reader can round them, beside the currency and its exponent.
  factory AccountingAmount.fromJson(Map<String, Object?> json) {
    final code = '${json['currency']}';
    final amount = AccountingAmount(
      code,
      _parseMinor('${json['minor']}', code),
    );
    if (json['exponent'] != amount.exponent) {
      throw AccountingException(
        AccountingError.unsupportedCurrency,
        '$code with exponent ${json['exponent']}',
      );
    }
    return amount;
  }

  final String currency;
  final int exponent;
  final int minor;

  static int _parseMinor(String text, String code) {
    if (!RegExp(r'^-?\d+$').hasMatch(text)) {
      throw AccountingException(AccountingError.malformedDecimal, text);
    }
    final v = BigInt.parse(text);
    _checkRange(v, code);
    return v.toInt();
  }

  static void _checkRange(BigInt minor, String code) {
    if (minor.abs() > BigInt.from(maxSafeMinor)) {
      throw AccountingException(AccountingError.outOfRange, '$minor $code');
    }
  }

  Map<String, Object> toJson() => {
    'currency': currency,
    'exponent': exponent,
    'minor': '$minor',
  };

  void _same(AccountingAmount other) {
    if (other.currency != currency) {
      throw AccountingException(
        AccountingError.currencyMismatch,
        '$currency vs ${other.currency}',
      );
    }
  }

  AccountingAmount operator +(AccountingAmount other) {
    _same(other);
    final sum = BigInt.from(minor) + BigInt.from(other.minor);
    _checkRange(sum, currency);
    return AccountingAmount._(currency, exponent, sum.toInt());
  }

  AccountingAmount operator -(AccountingAmount other) => this + -other;

  AccountingAmount operator -() =>
      AccountingAmount._(currency, exponent, -minor);

  /// This amount times [rate] (a fraction, e.g. `0.09975`), rounded once
  /// by [policy].
  AccountingAmount times(ExactDecimal rate, RoundingPolicy policy) {
    final v = _divide(
      BigInt.from(minor) * rate.units,
      rate.denominator,
      policy,
    );
    _checkRange(v, currency);
    return AccountingAmount._(currency, exponent, v.toInt());
  }

  /// [numerator] / [denominator] in minor units, rounded once by
  /// [policy] — for callers that hold an exact ratio (#1870).
  int roundedQuotient(
    BigInt numerator,
    BigInt denominator,
    RoundingPolicy policy,
  ) {
    final v = _divide(numerator, denominator, policy);
    _checkRange(v, currency);
    return v.toInt();
  }

  /// Splits this amount over [weights] exactly: the parts always add up
  /// to the whole, and the remainder units go, one each, to the largest
  /// fractional shares (ties to the earlier weight). A negative amount
  /// splits as the mirror of its positive.
  List<AccountingAmount> allocate(List<int> weights) {
    if (weights.isEmpty ||
        weights.any((w) => w < 0) ||
        weights.every((w) => w == 0)) {
      throw ArgumentError.value(weights, 'weights');
    }
    final total = BigInt.from(weights.fold<int>(0, (a, w) => a + w));
    final whole = BigInt.from(minor.abs());
    final parts = <BigInt>[];
    final remainders = <(BigInt, int)>[];
    for (var i = 0; i < weights.length; i++) {
      final exact = whole * BigInt.from(weights[i]);
      parts.add(exact ~/ total);
      remainders.add((exact.remainder(total), i));
    }
    var left = whole - parts.fold(BigInt.zero, (a, p) => a + p);
    remainders.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    for (final (_, i) in remainders) {
      if (left == BigInt.zero) break;
      parts[i] += BigInt.one;
      left -= BigInt.one;
    }
    return [
      for (final p in parts)
        AccountingAmount._(
          currency,
          exponent,
          minor.isNegative ? -p.toInt() : p.toInt(),
        ),
    ];
  }

  /// The major-unit string with exactly [exponent] decimals, from the
  /// integer digits: `12000` EUR → `120.00`, `5000` JPY → `5000`.
  String toDecimalString() =>
      ExactDecimal._(BigInt.from(minor), exponent).toString();

  @override
  bool operator ==(Object other) =>
      other is AccountingAmount &&
      other.currency == currency &&
      other.minor == minor;

  @override
  int get hashCode => Object.hash(currency, minor);

  @override
  String toString() => '${toDecimalString()} $currency';
}

/// An approved exchange rate: how many [quote] units one [base] unit is
/// worth, with where it came from. A conversion never runs without one.
class FxRate {
  const FxRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.source,
    required this.date,
    required this.version,
  });

  final String base;
  final String quote;
  final ExactDecimal rate;

  /// Who approved it (`accountant`, `ECB reference`, …) — evidence, not
  /// a feed.
  final String source;
  final DateTime date;
  final String version;
}

/// [amount] in [rate]'s quote currency, rounded once by [policy]. The
/// exponents differ by currency, so the factor carries them.
AccountingAmount convert(
  AccountingAmount amount,
  FxRate? rate,
  RoundingPolicy policy,
) {
  if (rate == null ||
      rate.base.toUpperCase() != amount.currency ||
      !supportedCurrencies.contains(rate.quote.toUpperCase())) {
    throw AccountingException(
      AccountingError.missingRate,
      '${amount.currency}→${rate?.quote ?? '?'}',
    );
  }
  final quote = rate.quote.toUpperCase();
  final quoteExp = exponentOf(quote);
  final numerator =
      BigInt.from(amount.minor) *
      rate.rate.units *
      BigInt.from(10).pow(quoteExp);
  final denominator =
      rate.rate.denominator * BigInt.from(10).pow(amount.exponent);
  final v = _divide(numerator, denominator, policy);
  AccountingAmount._checkRange(v, quote);
  return AccountingAmount._(quote, quoteExp, v.toInt());
}

/// What settling a foreign-currency document at another rate means in
/// the functional currency: the amount it was booked at, the amount it
/// settled at, and the difference as an exchange gain (positive) or
/// loss — never as extra revenue.
({
  AccountingAmount booked,
  AccountingAmount settled,
  AccountingAmount fxDifference,
})
settleForeign(
  AccountingAmount document, {
  required FxRate? bookedAt,
  required FxRate? settledAt,
  required RoundingPolicy policy,
}) {
  final booked = convert(document, bookedAt, policy);
  final settled = convert(document, settledAt, policy);
  return (booked: booked, settled: settled, fxDifference: settled - booked);
}
