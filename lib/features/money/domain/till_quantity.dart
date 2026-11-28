// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- a quantity at the till is an exact decimal: up to twelve whole digits and six decimals, above zero, kept as
// TEXT so a weighed 0.350 kg is never a float. The server reads the same shape (`^[0-9]{1,12}(\.[0-9]{1,6})?$`).

final RegExp _quantityShape = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');
const int _scale = 1000000;

/// [typed] as the exact quantity text the server takes (a comma reads as the point), or null when it is not above
/// zero or has more than six decimals.
String? tillQuantityOf(String typed) {
  final text = typed.trim().replaceAll(',', '.');
  if (!_quantityShape.hasMatch(text)) return null;
  return _units(text) == 0 ? null : _text(_units(text));
}

/// [a] plus [b], both quantity texts, exactly; null when either is not a quantity.
String? tillQuantitySum(String a, String b) {
  if (!_quantityShape.hasMatch(a) || !_quantityShape.hasMatch(b)) return null;
  return _text(_units(a) + _units(b));
}

/// A quantity in millionths: whole and fraction read from the text, no floating point.
int _units(String text) {
  final parts = text.split('.');
  final fraction = parts.length == 2 ? parts[1].padRight(6, '0') : '000000';
  return int.parse(parts[0]) * _scale + int.parse(fraction);
}

/// The shortest exact text of [units]: `1`, `0.35`, `12.5`.
String _text(int units) {
  final whole = units ~/ _scale;
  final fraction = (units % _scale).toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

/// What [unitMinor] (minor units of one unit) times [quantity] (an exact quantity text) comes to, rounded half up once;
/// null when [quantity] is not a quantity. The server rounds a line the same way (`half_up_per_line`).
int? tillLineAmount(int unitMinor, String quantity) {
  if (!_quantityShape.hasMatch(quantity)) return null;
  final scaled = unitMinor * _units(quantity);
  return (scaled + _scale ~/ 2) ~/ _scale;
}

/// The cash a customer may hand over for [totalMinor], from the currency's own decimal structure and not a table of
/// notes: the amount itself, then the total rounded up to the next whole 1, 2, 5, 10, 20, 50, 100... units of the
/// currency, the nearest first, without repeats; at most [count] amounts. [minorDigits] is the currency's decimals.
///
/// #4511 -- with the currency's [notes] (smallest first), the amount, then the total rounded up to the next whole note
/// of each value: what a customer hands over in the notes that exist.
List<int> tillCashSuggestions(int totalMinor, {required int minorDigits, int count = 4, List<int> notes = const []}) {
  if (totalMinor <= 0 || minorDigits < 0 || count < 1) return const [];
  if (notes.isNotEmpty) {
    final out = <int>[totalMinor];
    for (final note in notes) {
      if (out.length == count) break;
      final up = ((totalMinor + note - 1) ~/ note) * note;
      if (!out.contains(up)) out.add(up);
    }
    return out..sort();
  }
  var unit = 1;
  for (var i = 0; i < minorDigits; i++) {
    unit *= 10;
  }
  final out = <int>[totalMinor];
  // 1-2-5 steps of a whole currency unit, up to a thousand times the total's own size
  var decade = 1;
  while (out.length < count && decade <= totalMinor * 10) {
    for (final step in const [1, 2, 5]) {
      final size = step * decade * unit;
      final up = ((totalMinor + size - 1) ~/ size) * size;
      if (!out.contains(up)) out.add(up);
      if (out.length == count) break;
    }
    decade *= 10;
  }
  out.sort();
  return out;
}
