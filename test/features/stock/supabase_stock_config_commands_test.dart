// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4169 (A1) -- the stock configuration through the real Supabase client over a
// canned HTTP answer: a save carries the revision it read and a request id, a
// refusal of the server becomes the typed failure the screen shows under its
// field (stale, invalid content with its field and reason, in use), and
// nothing is reported saved that was not.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/stock/data/supabase_stock_config_commands.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_variants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ws = '00000000-0000-4000-8000-000000000101';
const _item = '00000000-0000-4000-8000-000000000301';

({SupabaseStockConfigCommands commands, List<http.Request> sent}) _with(
  int status,
  Object? answer,
) {
  final sent = <http.Request>[];
  final client = SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      sent.add(request);
      return http.Response(
        jsonEncode(answer),
        status,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return (commands: SupabaseStockConfigCommands(client), sent: sent);
}

const _config = StockItemConfig(
  itemId: _item,
  revision: 3,
  stockable: true,
  purchasable: true,
  sellable: true,
  inventoryUnit: 'piece',
  tracking: 'none',
  shelfLifeDays: null,
  units: [StockUnitDraft(unit: 'carton', factorNum: 12, factorDen: 1, defaultPurchase: true)],
  codes: [StockCodeDraft(code: 'BEAN-1', kind: 'own')],
);

void main() {
  test('a save carries the revision it read, the request id and the complete lists, and reports what the server answered', () async {
    final h = _with(200, {'item_id': _item, 'revision': 4, 'replayed': false});
    final saved = await h.commands.saveItem(_ws, _config, 'req-1');
    expect((saved.id, saved.revision, saved.replayed), (_item, 4, false));
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(h.sent.single.url.path, endsWith('/rpc/save_stock_item_v1'));
    expect(body['p_expected_revision'], 3);
    expect(body['p_request_id'], 'req-1');
    final item = body['p_item']! as Map<String, Object?>;
    expect((item['units']! as List).single, containsPair('factor_num', 12));
    expect((item['codes']! as List).single, containsPair('code', 'BEAN-1'));
  });

  test('a place is created with no id and no revision, and saved with both', () async {
    final h = _with(200, {'place_id': 'p-1', 'revision': 1, 'replayed': false});
    await h.commands.savePlace(_ws, place: {'kind': 'shelf', 'code': 'S1'}, requestId: 'r');
    var body = jsonDecode(h.sent.last.body) as Map<String, Object?>;
    expect(body['p_place_id'], isNull);
    expect(body['p_expected_revision'], isNull);
    await h.commands.savePlace(_ws, place: {'name': 'x'}, requestId: 'r2', placeId: 'p-1', expectedRevision: 1);
    body = jsonDecode(h.sent.last.body) as Map<String, Object?>;
    expect((body['p_place_id'], body['p_expected_revision']), ('p-1', 1));
  });

  test('a stale revision is a failure that says read again', () async {
    final h = _with(400, {'code': DkCode.dkg10, 'message': 'changed', 'details': null, 'hint': null});
    await expectLater(h.commands.saveItem(_ws, _config, 'r'), throwsA(isA<StockConfigStale>()));
  });

  test('a content refusal names its field and its reason', () async {
    final h = _with(400, {
      'code': DkCode.dkg11,
      'message': 'not valid',
      'details': '{"field": "units[0].factor_den", "reason": "factor_invalid"}',
      'hint': null,
    });
    await expectLater(
      h.commands.saveItem(_ws, _config, 'r'),
      throwsA(
        isA<StockConfigRefused>()
            .having((e) => e.field, 'field', 'units[0].factor_den')
            .having((e) => e.reason, 'reason', 'factor_invalid'),
      ),
    );
  });

  test('an item in use keeps its unit and tracking: a failure, not a success', () async {
    final h = _with(400, {'code': DkCode.dkg08, 'message': 'kept', 'details': null, 'hint': null});
    await expectLater(h.commands.saveItem(_ws, _config, 'r'), throwsA(isA<StockConfigInUse>()));
  });

  test('another failure is not swallowed', () async {
    final h = _with(400, {'code': DkCode.dkn01, 'message': 'not allowed', 'details': null, 'hint': null});
    await expectLater(h.commands.saveItem(_ws, _config, 'r'), throwsA(isA<Refusal>().having((e) => e.code, 'code', 'DKN01')));
  });

  test('the variants of an item are saved complete, at the item revision, and a duplicate combination is a refusal', () async {
    final h = _with(200, {'item_id': _item, 'revision': 5, 'replayed': false});
    await h.commands.saveVariants(
      _ws,
      _item,
      variants: const [
        StockVariant(id: null, values: {'d1': 'v1', 'd2': 'v2'}, priceCents: 2600, active: true, label: ''),
      ],
      expectedRevision: 4,
      requestId: 'r',
    );
    final body = jsonDecode(h.sent.single.body) as Map<String, Object?>;
    expect(h.sent.single.url.path, endsWith('/rpc/save_item_variants_v1'));
    expect(body['p_expected_revision'], 4);
    expect(((body['p_variants']! as List).single as Map)['values'], {'d1': 'v1', 'd2': 'v2'});

    final bad = _with(400, {
      'code': DkCode.dkg11,
      'message': 'not valid',
      'details': '{"field": "variants[1].values", "reason": "variant_combination_duplicate"}',
      'hint': null,
    });
    await expectLater(
      bad.commands.saveVariants(_ws, _item, variants: const [], expectedRevision: 4, requestId: 'r2'),
      throwsA(isA<StockConfigRefused>().having((e) => e.reason, 'reason', 'variant_combination_duplicate')),
    );
  });

  test('a dimension and a supplier mapping are explicit saves with their revisions', () async {
    final h = _with(200, {'dimension_id': 'd-1', 'revision': 1, 'replayed': false});
    await h.commands.saveDimension(_ws, dimension: {'name': 'Colour'}, requestId: 'r');
    expect(h.sent.last.url.path, endsWith('/rpc/save_item_dimension_v1'));
    final m = _with(200, {'mapping_id': 'm-1', 'revision': 2, 'replayed': false});
    final saved = await m.commands.saveMapping(
      _ws,
      mapping: {'supplier_id': 's', 'item_id': _item, 'article_ref': 'TX-100'},
      requestId: 'r',
      mappingId: 'm-1',
      expectedRevision: 1,
    );
    expect((saved.id, saved.revision), ('m-1', 2));
    final body = jsonDecode(m.sent.single.body) as Map<String, Object?>;
    expect((body['p_mapping_id'], body['p_expected_revision']), ('m-1', 1));
  });
}
