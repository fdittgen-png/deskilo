// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the stock commands through the real Supabase client over a
// canned HTTP answer: each command carries its request id and every line with
// its places, its exact quantity and (when asked) its acknowledgement; a
// transfer still on its way is read back with exact quantities (the numbers
// are read as text, never through a double); and a refusal of the server
// becomes the typed failure the screen shows: less on hand than asked (DKG03),
// or a field and a reason (DKG11).
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/stock/data/supabase_stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';

({SupabaseStockOperations operations, List<http.Request> sent}) _with(
  http.Response Function(http.Request request) answer,
) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      // a list read pages until an empty page (#4401): the canned answer is the first page
      if (int.tryParse(request.url.queryParameters['offset'] ?? '0')! > 0) {
        return http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: request);
      }
      final r = answer(request);
      return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (operations: SupabaseStockOperations(client), sent: sent);
}

http.Response _json(int status, Object? body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('a transfer carries the request id and each line with its places and exact quantity', () async {
    final h = _with((r) => _json(200, {'request_id': 'req-1', 'movements': [<String, Object?>{}, <String, Object?>{}]}));
    final result = await h.operations.transfer(
      _ws,
      const [
        StockLineDraft(itemId: 'i-1', quantity: '0.5', fromLocationId: 'p-1', toLocationId: 'p-2'),
        StockLineDraft(itemId: 'i-2', quantity: '1', fromLocationId: 'p-1', toLocationId: 'p-2', unit: 'carton'),
      ],
      'req-1',
    );
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(h.sent.single.url.path, endsWith('/rpc/stock_transfer_v1'));
    expect((body['p_workspace_id'], body['p_request_id']), (_ws, 'req-1'));
    expect(body['p_lines'], [
      {'item_id': 'i-1', 'quantity': '0.5', 'from': 'p-1', 'to': 'p-2'},
      {'item_id': 'i-2', 'quantity': '1', 'from': 'p-1', 'to': 'p-2', 'unit': 'carton'},
    ]);
    expect((result.requestId, result.movements), ('req-1', 2));
    expect(result.transferId, isNull);
  });

  test('a load names the destination and answers the transfer made; a receive names its lines and where they go', () async {
    final h = _with((r) => _json(200, {'request_id': 'r', 'transfer_id': 't-1', 'status': 'partly_received', 'movements': [<String, Object?>{}]}));
    final loaded = await h.operations.load(
      _ws,
      'p-branch',
      const [StockLineDraft(itemId: 'i-1', quantity: '6', fromLocationId: 'p-main', expiredAck: true)],
      'req-2',
    );
    final loadBody = jsonDecode(h.sent.last.body) as Map<String, Object?>;
    expect(h.sent.last.url.path, endsWith('/rpc/stock_transfer_load_v1'));
    expect(loadBody['p_to_location_id'], 'p-branch');
    expect((loadBody['p_lines']! as List).single, {'item_id': 'i-1', 'quantity': '6', 'from': 'p-main', 'expired_ack': true});
    expect(loaded.transferId, 't-1');

    final received = await h.operations.receive(
      _ws,
      't-1',
      const [(lineId: 'l-1', quantity: '2', toLocationId: 'p-shelf'), (lineId: 'l-2', quantity: '1', toLocationId: null)],
      'req-3',
    );
    final receiveBody = jsonDecode(h.sent.last.body) as Map<String, Object?>;
    expect(h.sent.last.url.path, endsWith('/rpc/stock_transfer_receive_v1'));
    expect(receiveBody['p_transfer_id'], 't-1');
    expect(receiveBody['p_lines'], [
      {'line_id': 'l-1', 'quantity': '2', 'to': 'p-shelf'},
      {'line_id': 'l-2', 'quantity': '1'},
    ]);
    expect((received.status, received.movements), ('partly_received', 1));
  });

  test('a take-out is a consumption or a loss: two commands', () async {
    final h = _with((r) => _json(200, {'request_id': 'r', 'movements': [<String, Object?>{}]}));
    const line = StockLineDraft(itemId: 'i-1', quantity: '1', fromLocationId: 'p-1');
    await h.operations.takeOut(_ws, StockTakeOutReason.consumption, const [line], 'req-4');
    await h.operations.takeOut(_ws, StockTakeOutReason.loss, const [line], 'req-5');
    expect(h.sent.map((r) => r.url.path.split('/').last), ['stock_consume_v1', 'stock_loss_v1']);
  });

  test('less on hand than asked is the typed failure, whole; a field and a reason is a refusal', () async {
    final short = _with((r) => _json(400, {'code': DkCode.dkg03, 'message': 'not that much', 'details': null, 'hint': null}));
    await expectLater(
      short.operations.transfer(_ws, const [StockLineDraft(itemId: 'i-1', quantity: '9', fromLocationId: 'a', toLocationId: 'b')], 'req-6'),
      throwsA(isA<StockNotEnough>()),
    );
    final refused = _with((r) => _json(400, {
      'code': DkCode.dkg11,
      'message': 'not valid',
      'details': '{"field": "to_location_id", "reason": "same_site"}',
      'hint': null,
    }));
    await expectLater(
      refused.operations.load(_ws, 'p', const [StockLineDraft(itemId: 'i-1', quantity: '1', fromLocationId: 'a')], 'req-7'),
      throwsA(isA<StockConfigRefused>().having((e) => (e.field, e.reason), 'field and reason', ('to_location_id', StockRefusal.sameSite))),
    );
  });

  test('the transfers on their way are read in one call with exact quantities, their places and their lines (#4401)', () async {
    final h = _with((r) {
      expect(r.url.path, endsWith('/stock_transfers'), reason: 'one call: the places, lines and items come embedded');
      return _json(200, [
        {
          'id': 't-1',
          'from_location_id': 'p-main',
          'to_location_id': 'p-branch',
          'status': 'partly_received',
          'revision': 2,
          'created_datetime': '2026-11-20T10:00:00+00:00',
          'from_place': {'code': 'MAIN'},
          'to_place': {'code': 'BRANCH'},
          'stock_transfer_lines': [
            {
              'id': 'l-1',
              'item_id': 'i-1',
              'variant_id': null,
              'lot_id': null,
              'loaded': '6.000000',
              'received': '2.500000',
              'services': {'name': 'Mugs', 'inventory_unit': 'piece'},
            },
            {'id': 'l-2', 'item_id': 'i-hidden', 'variant_id': null, 'lot_id': null, 'loaded': '1', 'received': '0', 'services': null},
          ],
        },
      ]);
    });
    final transfers = await h.operations.openTransfers(_ws);
    final t = transfers.single;
    expect((t.fromCode, t.toCode, t.status, t.revision), ('MAIN', 'BRANCH', 'partly_received', 2));
    final line = t.lines.first;
    expect((line.itemName, line.unit, line.loaded.text, line.received.text, line.inTransit.text), ('Mugs', 'piece', '6', '2.5', '3.5'));
    expect((t.lines.last.itemId, t.lines.last.itemName), ('i-hidden', ''), reason: 'an item the reader may not see keeps its line');
    final read = h.sent.first.url.queryParameters;
    expect(read['select'], contains('loaded::text'), reason: 'read as text, never through a double');
    expect(read['select'], contains('stock_transfers_workspace_id_from_location_id_fkey'), reason: 'each place by its own key');
    expect(read['stock_transfer_lines.order'], 'id.asc.nullslast');
    expect(h.sent.where((r) => (int.tryParse(r.url.queryParameters['offset'] ?? '0') ?? 0) == 0), hasLength(1), reason: 'one call (and the empty page that ends it)');
  });

  test('no transfer on its way is an empty list after one read', () async {
    final h = _with((r) => _json(200, <Object?>[]));
    expect(await h.operations.openTransfers(_ws), isEmpty);
    expect(h.sent, hasLength(1));
  });
}
