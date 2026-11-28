// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- "scan the place, then the items". A session turns the resolutions of a run of scans into what a
// goods sheet does: a place code sets the CURRENT place (it stays until another place is scanned), an item,
// variant or package-unit code adds a line -- or one more to the line it already has -- in the exact factor of
// the package unit, and a code that names nothing, or that this sheet cannot use, is said in words. It is pure: the
// sheet decides what a place or a line is, so the same rules serve the move, take-out, put-away and count sheets.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity, ExactQuantityResult;

import 'stock_code_resolver.dart';

/// What one scan did.
enum ScanOutcome {
  /// A place was set as the current place.
  place,

  /// A line was added or incremented.
  line,

  /// The code names nothing in this business.
  unknown,

  /// It names something this sheet cannot use (a lot or a tag of no item, a place that takes no goods).
  refused,

  /// A tag read a second time in this sheet: ignored.
  alreadyRead,

  /// #4495 -- the code is carried by several places: the person is asked which one.
  askPlace,
}

/// A counted line: an item (and variant) with an exact quantity in its inventory unit, as a fraction.
class ScanLine {
  ScanLine({required this.itemId, required this.itemName, required this.unit, this.variantId, this.variantLabel, this.lotCode, this.expiresOn});

  final String itemId;
  final String itemName;
  final String unit;
  final String? variantId;
  final String? variantLabel;
  final String? lotCode;

  /// The expiry day (`YYYY-MM-DD`) a GS1 code carried, when it did.
  String? expiresOn;

  /// The quantity so far, as `num / den` of [unit].
  int num = 0;
  int den = 1;

  /// How many scans made it (for a banner).
  int scans = 0;

  bool same(ScanLine other) => itemId == other.itemId && variantId == other.variantId && lotCode == other.lotCode;

  void add(int n, int d) {
    // a/b + n/d
    final g = _gcd(den, d);
    final common = den ~/ g * d;
    num = num * (common ~/ den) + n * (common ~/ d);
    den = common;
    final r = _gcd(num.abs(), den);
    if (r > 1) {
      num ~/= r;
      den ~/= r;
    }
    scans += 1;
  }

  static int _gcd(int a, int b) => b == 0 ? (a == 0 ? 1 : a) : _gcd(b, a % b);

  /// #4393 -- the quantity, exactly, or the reason it has none: three scans of
  /// a third of a box are one box; one scan of it has no six-decimal value.
  ExactQuantityResult get quantity => ExactQuantity.parse('$num').scaled(1, den);

  /// The quantity for a quantity field: exact decimal text, or null when it
  /// has none (the sheet then asks the person for the quantity). Never `n/d`.
  String? get quantityText => quantity.value?.text;

  /// The quantity for a banner: exact, or rounded as the ledger rounds an
  /// entered quantity, marked as such.
  String get shownQuantity => quantityText ?? '≈ ${ExactQuantity.parse('$num').scaled(1, den, round: true).value?.text ?? ''}';
}

/// The result of one scan, for the sheet to show.
class ScanResult {
  const ScanResult(this.outcome, {this.line, this.place, this.choices = const [], this.code, this.asksQuantity = false, this.fromTag = false});

  final ScanOutcome outcome;
  final ScanLine? line;
  final ScannedPlace? place;

  /// The places a code several places carry names, for [ScanOutcome.askPlace].
  final List<ScannedPlace> choices;
  final String? code;

  /// The business asks for the quantity of a repeated scan (`stock.repeated_scan` = ask_quantity): the line was
  /// not counted again, the sheet puts the person on its quantity field.
  final bool asksQuantity;

  /// The code was read from a tag by NFC, not typed by a scanner (the words differ: "Unknown tag").
  final bool fromTag;
}

/// A run of scans in one sheet.
class StockScanSession {
  StockScanSession({this.addsOne = true});

  /// The business's `stock.repeated_scan`: a repeated scan adds one (true) or asks for the quantity (false, which
  /// the sheet handles by opening its quantity field instead of counting).
  final bool addsOne;

  ScannedPlace? current;
  final List<ScanLine> lines = [];

  /// Applies [resolution]; [placeAllowed] says whether this sheet may use a place (a virtual or a supplier place
  /// may not take goods, say).
  ScanResult apply(
    StockCodeResolution resolution, {
    bool Function(ScannedPlace place)? placeAllowed,
    bool Function(ScannedItem item)? itemAllowed,
    bool fromTag = false,
    ({String? lot, String? expiresOn})? gs1,
  }) {
    // a tag bound to a place names that place, like its barcode does
    if (resolution.asksWhichPlace) {
      return ScanResult(ScanOutcome.askPlace, choices: resolution.placeChoices, code: resolution.code, fromTag: fromTag);
    }
    final place = resolution.place;
    final namesPlace = resolution.kind == ScannedKind.place || (resolution.kind == ScannedKind.tag && resolution.item == null);
    if (namesPlace && place != null) {
      if (placeAllowed != null && !placeAllowed(place)) {
        return ScanResult(ScanOutcome.refused, place: place, code: resolution.code, fromTag: fromTag);
      }
      current = place;
      return ScanResult(ScanOutcome.place, place: place, code: resolution.code, fromTag: fromTag);
    }
    switch (resolution.kind) {
      case ScannedKind.unknown || ScannedKind.place:
        return ScanResult(ScanOutcome.unknown, code: resolution.code, fromTag: fromTag);
      case ScannedKind.item || ScannedKind.variant || ScannedKind.lot || ScannedKind.tag:
        final item = resolution.item;
        if (item == null || item.id.isEmpty || (itemAllowed != null && !itemAllowed(item))) {
          return ScanResult(ScanOutcome.refused, code: resolution.code, fromTag: fromTag);
        }
        final candidate = ScanLine(
          itemId: item.id,
          itemName: item.name,
          unit: item.unit,
          variantId: resolution.variantId,
          variantLabel: resolution.variantLabel,
          lotCode: gs1?.lot ?? resolution.lotCode,
          expiresOn: gs1?.expiresOn,
        );
        final existing = lines.where(candidate.same).firstOrNull;
        // a repeat scan of a labelled unit gives an expiry to a line that had none
        if (existing != null && existing.expiresOn == null) existing.expiresOn = candidate.expiresOn;
        if (existing != null && !addsOne) {
          return ScanResult(ScanOutcome.line, line: existing, code: resolution.code, asksQuantity: true, fromTag: fromTag);
        }
        final line = existing ?? candidate;
        if (existing == null) lines.add(line);
        final unit = resolution.unit;
        line.add(unit?.factorNum ?? 1, unit?.factorDen ?? 1);
        return ScanResult(ScanOutcome.line, line: line, code: resolution.code, fromTag: fromTag);
    }
  }
}
