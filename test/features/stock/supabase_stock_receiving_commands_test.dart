// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (A) -- receiving a delivery into stock through the real Supabase client
// over a canned HTTP answer: a put-away carries the request id and every part
// with its place, variant, lot and cost (an unknown cost is sent as unknown,
// never as zero), a retried request answers the same ids and says so, and a
// refusal of the server becomes the typed failure the screen shows under its
// field.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/features/stock/data/supabase_stock_receiving_commands.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';
const _receipt = '00000000-0000-4000-8000-000000000801';

({SupabaseStockReceivingCommands commands, List<http.Request> sent}) _with(int status, Object? answer) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      // a list read pages until an empty page (#4401): the canned rows are the first page
      final later = int.tryParse(request.url.queryParameters['offset'] ?? '0')! > 0;
      return http.Response(
        jsonEncode(later ? <Object?>[] : answer),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (commands: SupabaseStockReceivingCommands(client), sent: sent);
}

Map<String, Object?> _row(String id, String qty) => {
  'id': id,
  'receipt_line_id': 'rl-1',
  'item_id': 'i-1',
  'variant_id': null,
  'lot_id': 'l-1',
  'location_id': 'p-1',
  'movement_id': 'm-$id',
  'entered_unit': 'carton',
  'entered_quantity': qty,
  'inventory_quantity': '24.000000',
  'order_reference': '2026-0001',
  'supplier_name': 'Water Co',
  'line_text': 'Water',
};

void main() {
  test('a put-away carries every part with its place, lot and cost; an unknown cost is sent as unknown, never as zero', () async {
    final h = _with(200, {'receipt_id': _receipt, 'replayed': false, 'allocations': [_row('a-1', '2.000000')]});
    final result = await h.commands.putAway(
      _ws,
      _receipt,
      const [
        PutAwayAllocation(lineNo: 1, quantity: '2', locationId: 'p-1', cost: PutAwayCost.known(totalMinor: 2400)),
        PutAwayAllocation(lineNo: 3, quantity: '10', locationId: 'p-2', lotCode: 'Y1', expiresOn: '2026-12-31'),
      ],
      'req-1',
    );
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(h.sent.single.url.path, endsWith('/rpc/put_away_receipt_v1'));
    expect(body['p_request_id'], 'req-1');
    final parts = body['p_allocations']! as List;
    expect((parts[0] as Map)['cost'], {'state': 'known', 'total_cost_minor': 2400});
    expect((parts[1] as Map)['cost'], {'state': 'unknown'}, reason: 'no assertion is unknown, not zero');
    expect((parts[1] as Map)['lot'], {'code': 'Y1', 'expires_on': '2026-12-31'});
    expect(result.allocations.single.inventoryQuantity.text, '24');
    expect((result.receiptId, result.replayed), (_receipt, false));
  });

  test('a retried request answers the same ids and says it was replayed', () async {
    final h = _with(200, {'receipt_id': _receipt, 'replayed': true, 'allocations': [_row('a-1', '2.000000')]});
    final result = await h.commands.putAway(_ws, _receipt, const [PutAwayAllocation(lineNo: 1, quantity: '2', locationId: 'p-1')], 'req-1');
    expect(result.replayed, isTrue);
    expect(result.allocations.single.id, 'a-1');
  });

  test('the delivery and its put-away are one call: the order revision, the lines and the request id travel together', () async {
    final h = _with(200, {'receipt_id': _receipt, 'replayed': false, 'allocations': <Object?>[]});
    await h.commands.recordAndPutAway(
      _ws,
      const DeliveryDraft(
        orderId: 'o-1',
        orderRevision: 3,
        receivedOn: '2026-11-21',
        lines: [(lineNo: 1, quantity: '2'), (lineNo: 4, quantity: '1')],
        note: 'dock',
      ),
      const [PutAwayAllocation(lineNo: 1, quantity: '2', locationId: 'p-1', cost: PutAwayCost.orderPrice())],
      'req-2',
    );
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(h.sent.single.url.path, endsWith('/rpc/record_receipt_and_put_away_v1'));
    expect((body['p_revision'], body['p_request_id'], body['p_note']), (3, 'req-2', 'dock'));
    expect(body['p_lines'], [
      {'line_no': 1, 'quantity': '2'},
      {'line_no': 4, 'quantity': '1'},
    ]);
    expect(((body['p_allocations']! as List).single as Map)['cost'], {'state': 'order_price'});
  });

  test('an over-allocation is a refusal with its field and reason, and nothing is reported put away', () async {
    final h = _with(400, {
      'code': DkCode.dkg11,
      'message': 'not valid',
      'details': '{"field": "allocations[0].quantity", "reason": "over_allocated"}',
      'hint': null,
    });
    await expectLater(
      h.commands.putAway(_ws, _receipt, const [PutAwayAllocation(lineNo: 2, quantity: '13', locationId: 'p-1')], 'req-3'),
      throwsA(isA<StockConfigRefused>().having((e) => (e.field, e.reason), 'field and reason', ('allocations[0].quantity', StockRefusal.overAllocated))),
    );
  });

  test('the allocations of a delivery read back with their frozen origin', () async {
    final h = _with(200, [_row('a-1', '2.000000'), _row('a-2', '1.000000')]);
    final read = await h.commands.allocations(_ws, _receipt);
    expect(read.map((a) => (a.enteredQuantity.text, a.enteredUnit, a.orderReference, a.supplierName)), [
      ('2', 'carton', '2026-0001', 'Water Co'),
      ('1', 'carton', '2026-0001', 'Water Co'),
    ]);
    expect(h.sent.first.url.queryParameters['receipt_id'], 'eq.$_receipt');
  });

  test('the allocations of an order are read through its deliveries, with the order line each came from', () async {
    final h = _with(200, [
      {..._row('a-1', '2.000000'), 'purchase_order_lines': {'line_no': 3}},
    ]);
    final read = await h.commands.allocationsOfOrder(_ws, 'o-1');
    expect(read.single.lineNo, 3);
    expect(h.sent.first.url.queryParameters['purchase_order_receipts.order_id'], 'eq.o-1');
  });
}
