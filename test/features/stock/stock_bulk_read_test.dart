// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4364 (G15) -- the invariant: a bulk read keeps each tag once whatever the reader types, never more than its
// limit, stops when told, and its tally is what the server resolved: pieces per item (variant, lot), the unknown tags
// apart, the pieces not in stock apart; a delivery is compared with what was read as expected / read / missing / extra.
import 'package:deskilo/features/stock/domain/stock_bulk_read.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'E28068940000401561D68F01';
const _b = 'E28068940000401561D68F02';

Map<String, Object?> _piece(String code, {String item = 'i1', String state = 'in_stock', String? lot, String place = 'MAIN'}) => {
  'input': code,
  'kind': 'tag',
  'code': code,
  'item': {'id': item, 'name': item == 'i1' ? 'Gift basket' : 'Crate'},
  'piece': {
    'id': 'p-$code',
    'state': state,
    'item_id': item,
    'variant_id': null,
    'lot_id': lot,
    'place': {'id': 'pl-$place', 'code': place, 'name': place},
  },
};

void main() {
  test('a tag typed in lower case, with spaces, colons or dashes is the tag the server knows: a repeat', () {
    final s = BulkReadSession(limit: 10);
    expect(s.add('E2806894'), BulkAdd.added);
    expect(s.add('e2:80-68 94'), BulkAdd.repeat);
    expect(s.codes, ['E2806894']);
  });

  test('a tag read five hundred times counts once; the order is the order first read', () {
    final s = BulkReadSession(limit: 10);
    expect(s.add(_a), BulkAdd.added);
    for (var i = 0; i < 500; i++) {
      expect(s.add(_a.toLowerCase()), BulkAdd.repeat);
    }
    expect(s.add(_b), BulkAdd.added);
    expect(s.codes, [_a, _b]);
    expect(s.repeats, 500);
    expect(s.add('  '), BulkAdd.blank);
  });

  test('a burst of lines, spaces and commas is read tag by tag', () {
    final s = BulkReadSession(limit: 10)..addAll('$_a\n$_b,$_a;  $_b');
    expect(s.codes, [_a, _b]);
    expect(s.repeats, 2);
  });

  test('a read keeps at most its limit and says how many it left out; a stopped read adds nothing', () {
    final s = BulkReadSession(limit: 2);
    expect([s.add('AA'), s.add('BB'), s.add('CC'), s.add('CC'), s.add('AA')], [BulkAdd.added, BulkAdd.added, BulkAdd.tooMany, BulkAdd.tooMany, BulkAdd.repeat]);
    expect([s.codes.length, s.dropped, s.full], [2, 2, true]);
    s.stop();
    expect(s.add('DD'), BulkAdd.stopped);
    expect(s.stopped, isTrue);
  });

  BulkResolution resolution(List<Map<String, Object?>> codes) => BulkResolution.fromJson({
    'received': codes.length + 3,
    'distinct': codes.length,
    'limit': 500,
    'truncated': false,
    'results': codes,
    'invalid': [
      {'code': '', 'reason': 'invalid'},
    ],
  });

  test('the server answer is read and tallied per item, with the others apart', () {
    final r = resolution([
      _piece('T1'),
      _piece('T2'),
      _piece('T3', lot: 'lot-a'),
      _piece('T4', item: 'i2'),
      _piece('T5', state: 'sold'),
      {'input': 'ZZ', 'kind': 'unknown', 'code': 'ZZ'},
      {'input': 'PL', 'kind': 'place', 'code': 'PL'},
    ]);
    expect([r.received, r.distinct, r.truncated, r.invalid], [10, 7, false, ['']]);
    final t = BulkTally.of(r);
    expect(t.pieces, 4);
    expect(
      {for (final l in t.lines) '${l.itemName}/${l.lotId ?? '-'}': l.count},
      {'Gift basket/-': 2, 'Gift basket/lot-a': 1, 'Crate/-': 1},
    );
    expect(t.unknown, ['ZZ']);
    expect(t.notInStock.single.input, 'T5');
    expect(t.notPieces.single.input, 'PL');
  });

  test('a delivery is compared with the read: expected, read, missing and extra', () {
    final t = BulkTally.of(resolution([for (var i = 0; i < 11; i++) _piece('T$i'), _piece('X', item: 'i2')]));
    final rows = {
      for (final r in compareDelivery(const [ExpectedLine(itemId: 'i1', quantity: 12), ExpectedLine(itemId: 'i3', quantity: 2)], t))
        r.itemId: (r.expected, r.read, r.missing, r.extra),
    };
    expect(rows['i1'], (12, 11, 1, 0));
    expect(rows['i2'], (0, 1, 0, 1));
    expect(rows['i3'], (2, 0, 2, 0));
  });
}
