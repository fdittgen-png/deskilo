// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4364 (G15) -- the invariant: a bulk read goes to the server in one call with its codes and one request id, the answer is
// read as it came (a blind counter's has no `missing`), and a refusal reaches the screen as its typed failure. Over a canned
// HTTP answer, as the other data tests; and the Demo answers through the same ports.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/stock/data/supabase_stock_cycle_counts.dart';
import 'package:deskilo/features/stock/data/supabase_stock_tags.dart';
import 'package:deskilo/features/stock/domain/stock_bulk_read.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';

SupabaseClient _client(http.Response Function(http.Request) answer, List<http.Request> sent) => SupabaseClient(
  'http://localhost',
  'anon',
  httpClient: MockClient((request) async {
    sent.add(request);
    final r = answer(request);
    return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
  }),
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

http.Response _json(int status, Object? body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('a read is sent in one call and its answer is read, the unknown tags included', () async {
    final sent = <http.Request>[];
    final port = SupabaseStockTags(
      _client((_) => _json(200, {
        'received': 3,
        'distinct': 2,
        'limit': 500,
        'truncated': false,
        'invalid': <Object?>[],
        'results': [
          {
            'input': 'E28068940000401561D68F01',
            'kind': 'tag',
            'item': {'id': 'i1', 'name': 'Gift basket'},
            'piece': {'id': 'p1', 'state': 'in_stock', 'item_id': 'i1', 'place': {'id': 'pl', 'code': 'MAIN', 'name': 'Main'}},
          },
          {'input': 'ZZ', 'kind': 'unknown', 'code': 'ZZ'},
        ],
      }), sent),
    );
    final r = await port.resolveCodes(_ws, ['E28068940000401561D68F01', 'ZZ', 'ZZ']);
    expect(sent, hasLength(1));
    expect(sent.single.url.path, endsWith('/rpc/stock_resolve_codes_v1'));
    expect(jsonDecode(sent.single.body), {'p_workspace_id': _ws, 'p_codes': ['E28068940000401561D68F01', 'ZZ', 'ZZ']});
    expect([r.received, r.distinct], [3, 2]);
    final tally = BulkTally.of(r);
    expect([tally.pieces, tally.lines.single.itemName, tally.unknown], [1, 'Gift basket', ['ZZ']]);
  });

  test('a count by bulk read carries its request id and task; a blind counter is given no missing list', () async {
    final sent = <http.Request>[];
    final port = SupabaseStockCycleCounts(
      _client((_) => _json(200, {
        'task_id': 't1',
        'request_id': 'r1',
        'task_state': 'open',
        'replayed': false,
        'lines': [
          {'line_id': 'l1', 'item_id': 'i1', 'variant_id': null, 'lot_id': null, 'location_id': 'pl', 'read': 2, 'state': 'counted'},
        ],
        'left_out': [
          {'code': 'ZZ', 'reason': 'not_a_piece'},
        ],
      }), sent),
    );
    final r = await port.countByTagRead(_ws, requestId: 'r1', taskId: 't1', codes: ['A', 'ZZ']);
    expect(jsonDecode(sent.single.body), {'p_workspace_id': _ws, 'p_request_id': 'r1', 'p_task_id': 't1', 'p_codes': ['A', 'ZZ']});
    expect([r.lines.single.read, r.lines.single.state, r.leftOut.single.reason, r.missing, r.replayed], [2, 'counted', 'not_a_piece', null, false]);
  });

  test('a refusal of the count read is its typed failure, and a closed task is refused as the server refuses it', () async {
    final port = SupabaseStockCycleCounts(
      _client((_) => _json(400, {'code': DkCode.dkg19, 'message': 'this task is no longer open', 'details': null, 'hint': null}), []),
    );
    await expectLater(
      port.countByTagRead(_ws, requestId: 'r', taskId: 't', codes: ['A']),
      throwsA(isA<Refusal>().having((e) => e.code, 'code', DkCode.dkg19)),
    );
  });

  test('the Demo resolves the tags of its gift basket as pieces of the main store, and tells the unknown ones', () async {
    final tags = DemoStockTags(nameOf: (id) async => id == 'demo-item-basket' ? 'Gift basket' : null);
    final r = await tags.resolveCodes('demo', ['E2801160600002054AF3E001', 'e2801160600002054af3e001', 'E2801160600002054AF3E002', 'NOPE', '  ']);
    expect([r.received, r.distinct, r.invalid.length], [5, 3, 1]);
    final t = BulkTally.of(r);
    expect([t.pieces, t.lines.single.itemName, t.unknown], [2, 'Gift basket', ['NOPE']]);
    expect(r.codes.first.piece?.place.code, 'MAIN');
    expect(() => const StockConfigRefused('a', 'b'), returnsNormally);
  });
}
