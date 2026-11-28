// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4516 -- the number a person types in "1 box = [n] pieces": a positive number of at most three decimals, kept as the fraction the item's
// conversion stores (2.5 is 5/2, 12 is 12/1).

/// The fraction [text] reads as, reduced, or null when it is not a positive number with at most three decimals ('.' or ',').
({int num, int den})? parseConversionFactor(String text) {
  final m = RegExp(r'^(\d{1,9})(?:[.,](\d{1,3}))?$').firstMatch(text.trim());
  if (m == null) return null;
  final decimals = m.group(2) ?? '';
  var den = 1;
  for (var i = 0; i < decimals.length; i++) {
    den *= 10;
  }
  var num = int.parse('${m.group(1)}$decimals');
  if (num <= 0) return null;
  var a = num;
  var b = den;
  while (b != 0) {
    final t = a % b;
    a = b;
    b = t;
  }
  num ~/= a;
  den ~/= a;
  return (num: num, den: den);
}
