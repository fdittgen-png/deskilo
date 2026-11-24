// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- the returns, corrections and counts through the real Supabase
// client over a canned HTTP answer: a return carries its own identity, its
// lines' identities and the transport request id, with the quantity as the
// text it was typed; what a movement still allows is read back exactly; the
// counts are read with their states and whether they are stale; a count and a
// decision carry their request id; and a refusal of the server reaches the
// screen with its code.
import 'dart:convert';

import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/stock/data/supabase_stock_reversals.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';

({SupabaseStockReversals port, List<http.Request> sent}) _with(
  http.Response Function(http.Request request) answer,
) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      final r = answer(request);
      return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (port: SupabaseStockReversals(client), sent: sent);
}

http.Response _json(int status, Object? body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _body(http.Request r) => jsonDecode(r.body) as Map<String, Object?>;

void main() {
  test('a return carries its identity, its lines and the request id, with the quantity as typed', () async {
    final h = _with(
      (r) => _json(200, {
        'return_id': 'ret-1',
        'kind': 'customer',
        'lines': [
          {'return_line_id': 'l-1', 'movement_id': 'mv-9', 'source_movement_id': 'mv-1', 'quantity': '3', 'remaining': '7.000000'},
        ],
      }),
    );
    final result = await h.port.makeReturn(
      _ws,
      'ret-1',
      StockReturnKind.customer,
      const [
        (lineId: 'l-1', sourceMovementId: 'mv-1', quantity: '3', locationId: 'place-main', note: ''),
      ],
      'req-1',
    );
    final sent = _body(h.sent.single);
    expect(h.sent.single.url.path, endsWith('/rpc/stock_return_v1'));
    expect(sent['p_return_id'], 'ret-1');
    expect(sent['p_request_id'], 'req-1');
    expect(sent['p_kind'], 'customer');
    expect((sent['p_lines']! as List).single, {
      'return_line_id': 'l-1',
      'source_movement_id': 'mv-1',
      'quantity': '3',
      'location': 'place-main',
    });
    expect(result.movementIds, ['mv-9']);
    expect(result.remaining.text, '7');
  });

  test('what a movement still allows is read back exactly', () async {
    final h = _with(
      (r) => _json(200, [
        {
          'movement_id': 'mv-1',
          'reason': 'sale',
          'quantity': '10.000000',
          'reversed': '3.000000',
          'remaining': '7.000000',
          'reversals': [
            {'return_id': 'ret-1', 'return_line_id': 'l-1', 'kind': 'customer', 'quantity': '3.000000', 'movement_id': 'mv-9'},
          ],
        },
      ]),
    );
    final read = await h.port.reversible(_ws, ['mv-1']);
    expect(_body(h.sent.single)['p_movement_ids'], ['mv-1']);
    final one = read['mv-1']!;
    expect(one.remaining.text, '7');
    expect(one.fullyReversed, isFalse);
    expect(one.reversals.single.quantity.text, '3');
  });

  test('the counts are read with their state, difference and staleness', () async {
    final h = _with(
      (r) => _json(200, [
        {
          'count_id': 'c-1',
          'item_id': 'i-1',
          'location_id': 'p-1',
          'observed': '8.000000',
          'baseline': '10.000000',
          'state': 'recorded',
          'stale': true,
          'reason': 'shelf count',
          'author_member_id': 'm-1',
        },
      ]),
    );
    final counts = await h.port.counts(_ws);
    expect(counts.single.state, StockCountState.recorded);
    expect(counts.single.stale, isTrue);
    expect(counts.single.difference.text, '-2');
  });

  test('a count and a decision carry their request id and identity', () async {
    final h = _with((r) => _json(200, {'state': 'recorded'}));
    await h.port.recordCount(_ws, (countId: 'c-1', itemId: 'i-1', locationId: 'p-1', observed: '8', requestId: 'req-2', variantId: null, lotId: 'lot-1', reason: ''));
    await h.port.decideCount(_ws, 'c-1', StockCountDecision.apply, 'req-3', note: 'ok');
    expect(h.sent, hasLength(2));
    final record = _body(h.sent.first);
    expect(record['p_count_id'], 'c-1');
    expect(record['p_request_id'], 'req-2');
    expect(record['p_scope'], {'item_id': 'i-1', 'location_id': 'p-1', 'lot_id': 'lot-1'});
    expect(record['p_observed'], '8');
    final decide = _body(h.sent.last);
    expect(decide['p_decision'], 'apply');
    expect(decide['p_request_id'], 'req-3');
  });

  test('a refusal of the server reaches the screen with its code', () async {
    final h = _with((r) => _json(400, {'code': 'DKG17', 'message': 'only 4 can still be reversed', 'details': null, 'hint': null}));
    await expectLater(
      h.port.makeReturn(_ws, 'ret-1', StockReturnKind.customer, const [
        (lineId: 'l-1', sourceMovementId: 'mv-1', quantity: '9', locationId: 'p', note: ''),
      ], 'req-1'),
      throwsA(isA<Refusal>().having((e) => e.code, 'code', 'DKG17')),
    );
  });
}
