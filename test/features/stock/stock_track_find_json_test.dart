// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4436 -- the answers of stock_trace_find_v1 and of stock_trace_chain_v1 read backwards from a sold line (0940), as
// the server writes them: a receipt the reader may see carries its line, one they may not is its kind alone; pieces are
// absent where the business uses no tags, which is not "no piece"; an answer without its lists is a shape error, never
// "nothing found"; a sold line names the lot codes it took with their quantities and the pieces by their tags.
import 'package:deskilo/features/stock/domain/stock_trace_chain.dart';
import 'package:deskilo/features/stock/domain/stock_track_find.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a found lot, a piece and two sales, one of them unavailable to the reader',
    () {
      final a = TrackFindAnswer.fromJson({
        'code': 'MILK-12',
        'lots': [
          {
            'id': 'l-1',
            'item_id': 'i-1',
            'item': 'Oat milk',
            'code': 'MILK-12',
            'expires_on': '2026-11-28',
          },
        ],
        'pieces': [
          {
            'id': 'p-1',
            'item_id': 'i-2',
            'item': 'Gift basket',
            'lot_id': 'l-2',
            'state': 'in_stock',
            'tag': 'E28011',
          },
        ],
        'sales': [
          {
            'at': '2026-11-24T09:00:00+00:00',
            'quantity': '2',
            'document': {
              'kind': 'counter_receipt',
              'id': 'r-1',
              'label': 'R-00001',
              'line_id': 'line-1',
            },
          },
          {
            'at': '2026-11-23T09:00:00+00:00',
            'quantity': '1.5',
            'document': {'kind': 'counter_receipt', 'state': 'unavailable'},
          },
        ],
        'truncated': true,
      });
      expect(a.isEmpty, isFalse);
      expect(a.lots.single.expiresOn, DateTime(2026, 11, 28));
      expect(a.pieces!.single.tag, 'E28011');
      expect(
        (
          a.sales.first.lineId,
          a.sales.first.document!.label,
          a.sales.first.document!.available,
        ),
        ('line-1', 'R-00001', true),
      );
      expect(
        (
          a.sales.last.lineId,
          a.sales.last.document!.available,
          a.sales.last.quantity.text,
        ),
        (null, false, '1.5'),
      );
      expect(a.truncated, isTrue);
    },
  );

  test('no tags here is not "no piece", and nothing found is empty', () {
    final a = TrackFindAnswer.fromJson({
      'code': 'X',
      'lots': <Object?>[],
      'pieces': null,
      'sales': <Object?>[],
      'truncated': false,
    });
    expect(a.pieces, isNull);
    expect(a.isEmpty, isTrue);
  });

  test(
    'an answer without its lists is a shape error, never "nothing found"',
    () {
      expect(
        () => TrackFindAnswer.fromJson({
          'code': 'X',
          'pieces': null,
          'truncated': false,
        }),
        throwsA(anything),
      );
    },
  );

  test('a sold line read backwards names what it took', () {
    final c = TraceChain.fromJson({
      'subject': 'sale_line',
      'steps': <Object?>[],
      'took': {
        'lots': ['l-1'],
        'tracks': [
          {'kind': 'lot', 'code': 'MILK-12', 'quantity': '2'},
          {'kind': 'piece', 'code': 'E28011'},
        ],
      },
    });
    expect(c.subject, 'sale_line');
    expect(
      [for (final t in c.took) (t.kind, t.code, t.quantity?.text)],
      [('lot', 'MILK-12', '2'), ('piece', 'E28011', null)],
    );
  });
}
