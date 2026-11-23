// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- the factor of a group's default purchase unit, typed as one number a person writes: `12` (a carton of
// twelve), `0.5` or the fraction `1/3` (a third of a litre). The server keeps it exact as two whole numbers; this
// reads the text into them and writes them back, never through a double.
typedef PurchaseFactor = ({int num, int den});

int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

/// [text] as a factor above zero in lowest terms, or null when it is not one: a whole number, a decimal with a point or a
/// comma (at most six decimals) or `a/b`.
PurchaseFactor? parsePurchaseFactor(String text) {
  final t = text.trim().replaceAll(',', '.');
  final fraction = RegExp(r'^([0-9]{1,9})\s*/\s*([0-9]{1,9})$').firstMatch(t);
  int? num;
  int? den;
  if (fraction != null) {
    num = int.parse(fraction[1]!);
    den = int.parse(fraction[2]!);
  } else {
    final decimal = RegExp(r'^([0-9]{1,9})(?:\.([0-9]{1,6}))?$').firstMatch(t);
    if (decimal == null) return null;
    final fractionDigits = decimal[2] ?? '';
    num = int.parse('${decimal[1]}$fractionDigits');
    den = int.parse('1${'0' * fractionDigits.length}');
  }
  if (num <= 0 || den <= 0) return null;
  final g = _gcd(num, den);
  return (num: num ~/ g, den: den ~/ g);
}

/// The text a factor is shown and edited as: a whole number when it is one, else `a/b`.
String purchaseFactorText(int num, int den) => den == 1 ? '$num' : '$num/$den';
