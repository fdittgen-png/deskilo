// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4364 (G15) -- a UHF reader in keyboard mode types every tag it sees, often the same one many times a second. A bulk
// read collects what it types, locally and bounded (the setting `stock.tag_read_max_tags`), de-duplicated on the tag as
// the server normalises it; stopping freezes the tally; nothing is sent to the server until the person confirms. This file
// is pure: the collector, the tally of what the server resolved, and the comparison of a delivery with what was read.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// A UHF tag as a reader types it: hexadecimal of 24 characters or more (an EPC), told apart from a barcode by its form.
bool looksLikeUhfTag(String code) => RegExp(r'^[0-9A-Fa-f]{24,128}$').hasMatch(code.trim());

/// The code as the server normalises it: upper case, without spaces, `:` or `-`.
String normaliseTag(String code) => code.replaceAll(RegExp(r'[\s:\-]'), '').toUpperCase();

/// What adding one typed code did.
enum BulkAdd {
  /// A tag not seen before in this read.
  added,

  /// A tag already in this read: the repeat of a reader that sees a tag many times a second.
  repeat,

  /// The read already keeps the most tags it may: this one was left out.
  tooMany,

  /// The read is stopped: nothing is added.
  stopped,

  /// Nothing to add: a blank line.
  blank,
}

/// The tags of one read session, in the order they were first read.
class BulkReadSession {
  BulkReadSession({required this.limit}) : assert(limit > 0, 'a read keeps at least one tag');

  /// The most distinct tags this read keeps.
  final int limit;

  final List<String> _codes = [];
  final Set<String> _seen = {};
  int _repeats = 0;
  int _dropped = 0;
  bool _stopped = false;

  /// The distinct tags, as typed (trimmed), in the order first read.
  List<String> get codes => List.unmodifiable(_codes);

  /// How many times a tag already read was read again.
  int get repeats => _repeats;

  /// How many different tags were left out because the read was full.
  int get dropped => _dropped;

  bool get stopped => _stopped;

  bool get full => _codes.length >= limit;

  /// Adds [typed] (one code, as the reader typed it).
  BulkAdd add(String typed) {
    final code = typed.trim();
    if (code.isEmpty) return BulkAdd.blank;
    if (_stopped) return BulkAdd.stopped;
    final key = normaliseTag(code);
    if (_seen.contains(key)) {
      _repeats += 1;
      return BulkAdd.repeat;
    }
    if (_codes.length >= limit) {
      _dropped += 1;
      return BulkAdd.tooMany;
    }
    _seen.add(key);
    _codes.add(code);
    return BulkAdd.added;
  }

  /// Adds every code of [typed] (a burst: lines, or codes separated by white space or `,` or `;`).
  List<BulkAdd> addAll(String typed) => [
    for (final part in typed.split(RegExp(r'[\s,;]+'))) add(part),
  ];

  /// Stops the read: the tally is frozen.
  void stop() => _stopped = true;
}

/// The place a read piece is at.
class BulkPlace {
  const BulkPlace({required this.id, required this.code, required this.name});
  final String id;
  final String code;
  final String name;
}

/// A piece the server found for a tag.
class BulkPiece {
  const BulkPiece({
    required this.id,
    required this.state,
    required this.itemId,
    this.variantId,
    this.lotId,
    required this.place,
  });

  final String id;

  /// `in_stock`, `sold`, `returned`, `written_off` or `retired`.
  final String state;
  final String itemId;
  final String? variantId;
  final String? lotId;
  final BulkPlace place;

  bool get inStock => state == 'in_stock';

  factory BulkPiece.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bulk_piece');
    final place = r.objectOrAbsent('place');
    return BulkPiece(
      id: r.string('id'),
      state: r.string('state'),
      itemId: r.string('item_id'),
      variantId: r.stringOrNull('variant_id'),
      lotId: r.stringOrNull('lot_id'),
      place: BulkPlace(id: place.string('id'), code: place.string('code'), name: place.stringOrNull('name') ?? ''),
    );
  }
}

/// What the server made of one code of a read.
class BulkCode {
  const BulkCode({required this.input, required this.kind, this.itemName, this.variantLabel, this.lotCode, this.piece});

  final String input;

  /// The resolver's kind: `tag`, `item`, `variant`, `place`, `lot` or `unknown`.
  final String kind;
  final String? itemName;
  final String? variantLabel;
  final String? lotCode;

  /// Set when the tag names one piece.
  final BulkPiece? piece;

  bool get isPiece => piece != null;
  bool get isUnknown => kind == 'unknown';

  factory BulkCode.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'bulk_code');
    final item = r.objectOrNull('item');
    final variant = r.objectOrNull('variant');
    final lot = r.objectOrNull('lot');
    final piece = r.objectOrEmpty('piece');
    return BulkCode(
      input: r.string('input'),
      kind: r.string('kind'),
      itemName: item?.stringOrNull('name'),
      variantLabel: variant?.stringOrNull('label'),
      lotCode: lot?.stringOrNull('code'),
      piece: piece.isEmpty ? null : BulkPiece.fromJson(piece),
    );
  }
}

/// A read resolved by the server: `stock_resolve_codes_v1`.
class BulkResolution {
  const BulkResolution({
    required this.received,
    required this.distinct,
    required this.limit,
    required this.truncated,
    required this.codes,
    this.invalid = const [],
  });

  final int received;
  final int distinct;
  final int limit;

  /// The server stopped at its limit: some distinct codes were not resolved.
  final bool truncated;
  final List<BulkCode> codes;

  /// The codes that could not be read at all (blank, or over 200 characters).
  final List<String> invalid;

  factory BulkResolution.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'stock_resolve_codes_v1');
    return BulkResolution(
      received: r.integer('received'),
      distinct: r.integer('distinct'),
      limit: r.integer('limit'),
      truncated: r.boolOr('truncated', fallback: false),
      codes: [for (final c in r.requiredList('results')) BulkCode.fromJson(c)],
      invalid: [
        for (final i in r.list('invalid'))
          JsonReader.of(i, context: 'stock_resolve_codes_v1.invalid').stringOrNull('code') ?? '',
      ],
    );
  }
}

/// A line of the tally: so many pieces of one item (variant, lot).
class BulkTallyLine {
  const BulkTallyLine({required this.itemId, required this.itemName, this.variantId, this.variantLabel, this.lotId, this.lotCode, required this.count});

  final String itemId;
  final String itemName;
  final String? variantId;
  final String? variantLabel;
  final String? lotId;
  final String? lotCode;
  final int count;
}

/// The tally of a resolved read: what was read per item, variant and lot ("Gift basket · 7 pieces"), and, apart, the
/// tags the server does not know, the pieces that are not in stock, and the tags that name no piece.
class BulkTally {
  const BulkTally({required this.lines, required this.unknown, required this.notInStock, required this.notPieces});

  final List<BulkTallyLine> lines;
  final List<String> unknown;
  final List<BulkCode> notInStock;
  final List<BulkCode> notPieces;

  /// The pieces read and in stock.
  int get pieces => lines.fold(0, (sum, l) => sum + l.count);

  factory BulkTally.of(BulkResolution resolution) {
    final byKey = <String, BulkTallyLine>{};
    final unknown = <String>[];
    final notInStock = <BulkCode>[];
    final notPieces = <BulkCode>[];
    for (final c in resolution.codes) {
      if (c.isUnknown) {
        unknown.add(c.input);
      } else if (c.piece == null) {
        notPieces.add(c);
      } else if (!c.piece!.inStock) {
        notInStock.add(c);
      } else {
        final p = c.piece!;
        final key = '${p.itemId}|${p.variantId ?? ''}|${p.lotId ?? ''}';
        final held = byKey[key];
        byKey[key] = BulkTallyLine(
          itemId: p.itemId,
          itemName: c.itemName ?? '',
          variantId: p.variantId,
          variantLabel: c.variantLabel,
          lotId: p.lotId,
          lotCode: c.lotCode,
          count: (held?.count ?? 0) + 1,
        );
      }
    }
    return BulkTally(lines: byKey.values.toList(), unknown: unknown, notInStock: notInStock, notPieces: notPieces);
  }
}

/// A line of a delivery or an order: so many expected of an item (and variant).
class ExpectedLine {
  const ExpectedLine({required this.itemId, this.variantId, required this.quantity});
  final String itemId;
  final String? variantId;
  final int quantity;
}

/// One row of the table that compares a delivery with a read: expected, read, missing and extra.
class BulkCompareRow {
  const BulkCompareRow({required this.itemId, this.variantId, required this.expected, required this.read});

  final String itemId;
  final String? variantId;
  final int expected;
  final int read;

  int get missing => expected > read ? expected - read : 0;
  int get extra => read > expected ? read - expected : 0;
}

/// The delivery [expected] compared with the [tally]: a row for each item (variant) either names. For whoever receives; a
/// counter does not see the expected quantity, so the count shows the read only.
List<BulkCompareRow> compareDelivery(List<ExpectedLine> expected, BulkTally tally) {
  final rows = <String, ({int expected, int read})>{};
  String key(String item, String? variant) => '$item|${variant ?? ''}';
  for (final e in expected) {
    final k = key(e.itemId, e.variantId);
    rows[k] = (expected: (rows[k]?.expected ?? 0) + e.quantity, read: rows[k]?.read ?? 0);
  }
  for (final l in tally.lines) {
    final k = key(l.itemId, l.variantId);
    rows[k] = (expected: rows[k]?.expected ?? 0, read: (rows[k]?.read ?? 0) + l.count);
  }
  return [
    for (final MapEntry(key: k, value: v) in rows.entries)
      BulkCompareRow(
        itemId: k.split('|').first,
        variantId: k.split('|').last.isEmpty ? null : k.split('|').last,
        expected: v.expected,
        read: v.read,
      ),
  ];
}
