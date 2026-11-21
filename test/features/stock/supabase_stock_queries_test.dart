// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (A1) -- the stock reads through the real Supabase client over a
// canned HTTP answer: exact quantities read from the server's text, a
// continuation that is never dropped, a malformed or truncated page that
// throws instead of showing an empty list, and the request that carries the
// filters, the bound and the cursor.
import 'dart:convert';

import 'package:deskilo/features/stock/data/supabase_stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';
const _item = '00000000-0000-4000-8000-000000000301';
const _place = '00000000-0000-4000-8000-000000000401';

Map<String, Object?> _onHand(String quantity) => {
  'workspace_id': _ws,
  'item_id': _item,
  'item_name': 'Wine',
  'lot_id': null,
  'lot_code': null,
  'location_id': _place,
  'location_code': 'MAIN',
  'location_name': 'Main',
  'quantity': quantity,
  'unit': 'l',
};

({SupabaseStockQueries queries, List<http.Request> sent}) _with(Object? answer) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      return http.Response(
        jsonEncode(answer),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (queries: SupabaseStockQueries(client), sent: sent);
}

void main() {
  test('three thirds read as 0.999999 and 0.5 as 0.5, exactly, from text', () async {
    final h = _with({
      'rows': [_onHand('0.999999'), _onHand('0.500000')],
      'complete': true,
      'next': null,
    });
    final page = await h.queries.onHandPage(_ws);
    expect(page.rows.map((r) => r.quantity.text), ['0.999999', '0.5']);
    expect(page.complete, isTrue);
    expect(page.next, isNull);
    expect(page.rows.first.unit, 'l');
  });

  test('a page that continues hands back its cursor, and the next request carries it', () async {
    final h = _with({
      'rows': [_onHand('1.000000')],
      'complete': false,
      'next': {'version': 1, 'item_id': _item, 'location_id': _place, 'lot_id': null},
    });
    final page = await h.queries.onHandPage(_ws, itemId: _item, locationId: _place, limit: 1);
    expect(page.complete, isFalse);
    expect(page.next?['version'], 1);
    await h.queries.onHandPage(_ws, itemId: _item, locationId: _place, limit: 1, after: page.next);
    final body = jsonDecode(h.sent.last.body) as Map<String, Object?>;
    expect(h.sent.last.url.path, endsWith('/rpc/stock_on_hand_page_v1'));
    expect(body['p_workspace_id'], _ws);
    expect(body['p_item_id'], _item);
    expect(body['p_location_id'], _place);
    expect(body['p_limit'], 1);
    expect((body['p_after']! as Map)['item_id'], _item);
  });

  test('a page that neither ends nor continues is an error, not a short list', () async {
    final h = _with({'rows': [_onHand('1')], 'complete': false, 'next': null});
    await expectLater(h.queries.onHandPage(_ws), throwsA(isA<StockReadException>()));
  });

  test('a row with an unreadable quantity, or an answer of the wrong shape, throws', () async {
    await expectLater(
      _with({'rows': [_onHand('0.0000001')], 'complete': true}).queries.onHandPage(_ws),
      throwsA(anything),
    );
    await expectLater(_with({'rows': 'none', 'complete': true}).queries.onHandPage(_ws), throwsA(anything));
    await expectLater(_with(<Object?>[]).queries.onHandPage(_ws), throwsA(anything));
  });

  test('a movement keeps what was entered beside what is stored, its causes and an unknown cost', () async {
    final h = _with({
      'rows': [
        {
          'workspace_id': _ws,
          'id': '00000000-0000-4000-8000-000000000501',
          'item_id': _item,
          'item_name': 'Wine',
          'lot_id': null,
          'lot_code': null,
          'from_location_id': _place,
          'from_location_code': 'SUPPLIER',
          'to_location_id': _place,
          'to_location_code': 'MAIN',
          'quantity': '0.333333',
          'unit': 'l',
          'entered_quantity': '1.000000',
          'entered_unit': 'third',
          'occurred_at': '2026-03-03T09:00:00+00:00',
          'reason': 'receipt',
          'unit_cost': null,
          'actor_member_id': null,
          'receipt_line_id': 'r-1',
          'purchase_line_id': null,
          'event_id': null,
          'invoice_id': null,
        },
      ],
      'complete': true,
      'next': null,
    });
    final m = (await h.queries.movementsPage(_ws)).rows.single;
    expect(m.quantity.text, '0.333333');
    expect((m.enteredQuantity.text, m.enteredUnit), ('1', 'third'));
    expect(m.unitCost, isNull, reason: 'unknown valuation stays unknown');
    expect(m.causes, {'receipt_line': 'r-1'});
    expect(m.occurredAt.toUtc(), DateTime.utc(2026, 3, 3, 9));
    expect(h.sent.single.url.path, endsWith('/rpc/stock_movements_page_v1'));
  });

  test('a movement by its address is asked with its id, and an empty answer is none', () async {
    final h = _with({'rows': <Object?>[], 'complete': true, 'next': null});
    expect(await h.queries.movement(_ws, 'm-1'), isNull);
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(body['p_movement_id'], 'm-1');
    expect(body['p_limit'], 1);
  });
}
