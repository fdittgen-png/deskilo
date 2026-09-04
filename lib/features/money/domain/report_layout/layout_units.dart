// SPDX-License-Identifier: 0BSD
//
// #875 — lengths a report layout is written in.
//
// A design that STATES its geometry needs a unit vocabulary the author
// already thinks in: millimetres for the envelope spec, centimetres for
// a ruler, CSS pixels for anyone coming from the web, points for the
// PDF-native, and percentages for "half of whatever this sits in".
// Everything resolves to PostScript points once, here, so the renderer
// and the on-screen mirror can never disagree about what "45mm" is.

/// What happened when a layout could not be read. Mirrors
/// `ReportDesignError` so the two exchange formats fail the same way.
enum LayoutError {
  /// Not XML at all, or not well-formed.
  malformed,

  /// Well-formed XML, but not a `<report-layout>` document.
  notALayout,

  /// A schema version this app does not read.
  unsupportedVersion,

  /// An element the vocabulary does not have.
  unknownElement,

  /// An attribute value that does not parse (a length, an enum…).
  badAttribute,

  /// A length with a unit this engine does not know.
  badUnit,

  /// The Liquid pass produced text that is no longer XML.
  liquid,
}

class LayoutException implements Exception {
  const LayoutException(this.error, this.detail, {this.cause, this.stackTrace});

  final LayoutError error;

  /// Where and what — an element path or an attribute — so the failure
  /// can be read back without reproducing it.
  final String detail;

  /// The underlying failure when one exists (the Liquid engine's own
  /// error, the XML parser's), and where it was thrown from. A trace
  /// that names only the symptom is a trace someone has to reproduce.
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      'LayoutException(${error.name}: $detail'
      '${cause == null ? '' : ' — caused by $cause'})';
}

/// The units a length may carry. Order is the order `describe` lists.
enum LengthUnit { mm, cm, px, pt, percent }

/// PostScript points per millimetre.
const double pointsPerMm = 72 / 25.4;

/// A CSS pixel is 1/96 inch, so 0.75 pt — the web's px, not a screen's.
const double pointsPerPx = 72 / 96;

/// One length as written — the number and its unit — resolvable against
/// the extent of whatever contains it.
class Length {
  const Length(this.value, this.unit);

  final double value;
  final LengthUnit unit;

  /// Parses `12mm`, `2.5cm`, `40px`, `10pt`, `30%`; a bare number is
  /// MILLIMETRES, because that is what the envelope spec is written in
  /// and what a ruler shows. Whitespace around the number is tolerated;
  /// anything else is a [LayoutError.badUnit] naming [attribute].
  static Length parse(String raw, {String attribute = 'length'}) {
    final text = raw.trim();
    final match = _pattern.firstMatch(text);
    if (match == null) {
      throw LayoutException(
          LayoutError.badUnit, '$attribute="$raw" is not a length');
    }
    final number = double.tryParse(match.group(1)!);
    if (number == null) {
      throw LayoutException(
          LayoutError.badAttribute, '$attribute="$raw" has no number');
    }
    final suffix = match.group(2) ?? '';
    final unit = switch (suffix) {
      '' || 'mm' => LengthUnit.mm,
      'cm' => LengthUnit.cm,
      'px' => LengthUnit.px,
      'pt' => LengthUnit.pt,
      '%' => LengthUnit.percent,
      _ => throw LayoutException(
          LayoutError.badUnit, '$attribute="$raw": unknown unit "$suffix"'),
    };
    return Length(number, unit);
  }

  static Length? tryParse(String? raw, {String attribute = 'length'}) =>
      raw == null || raw.trim().isEmpty
          ? null
          : parse(raw, attribute: attribute);

  static final _pattern = RegExp(r'^(-?\d+(?:\.\d+)?)\s*(mm|cm|px|pt|%)?$');

  /// The length in points. [parentPt] is the extent a percentage refers
  /// to: the parent's WIDTH for x and w, its HEIGHT for y and h. Every
  /// absolute unit ignores it.
  double resolve(double parentPt) => switch (unit) {
        LengthUnit.mm => value * pointsPerMm,
        LengthUnit.cm => value * 10 * pointsPerMm,
        LengthUnit.px => value * pointsPerPx,
        LengthUnit.pt => value,
        LengthUnit.percent => parentPt * value / 100,
      };

  bool get isRelative => unit == LengthUnit.percent;

  /// The canonical spelling, which is also what serialises back out:
  /// `12mm`, `2.5cm`, `30%`. A bare number never survives a round trip —
  /// it comes back as explicit millimetres, so the file says what it
  /// means.
  @override
  String toString() {
    final n = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    return switch (unit) {
      LengthUnit.mm => '${n}mm',
      LengthUnit.cm => '${n}cm',
      LengthUnit.px => '${n}px',
      LengthUnit.pt => '${n}pt',
      LengthUnit.percent => '$n%',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Length && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
}

/// Where an element sits inside its parent. A frame with neither `x`
/// nor `y` FLOWS — it is stacked after its siblings; one with either is
/// ABSOLUTE within the parent box. Width and height apply to both.
class LayoutFrame {
  const LayoutFrame({this.x, this.y, this.w, this.h});

  static const LayoutFrame flow = LayoutFrame();

  final Length? x;
  final Length? y;
  final Length? w;
  final Length? h;

  bool get isPositioned => x != null || y != null;

  bool get isEmpty => x == null && y == null && w == null && h == null;

  @override
  bool operator ==(Object other) =>
      other is LayoutFrame &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}
