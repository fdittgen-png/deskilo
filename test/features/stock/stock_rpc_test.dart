// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- the invariant: every stock function is called through one helper, a refusal of the server
// becomes its typed failure the same way for every caller (the six sites that had no mapping included), an
// answer of the wrong shape throws naming the function, and anything that is not a refusal of ours is
// rethrown as it came. Over a canned HTTP answer, as the other data tests.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/stock/data/stock_rpc.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

StockRpc _rpc(http.Response Function(http.Request) answer) => StockRpc(
  SupabaseClient(
    'http://localhost',
    'anon',
    httpClient: MockClient((request) async {
      final r = answer(request);
      return http.Response(r.body, r.statusCode, headers: r.headers, request: request);
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

http.Response _json(int status, Object? body) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

http.Response _refused(String code, [String message = 'refused', Object? details]) =>
    _json(400, {'code': code, 'message': message, 'details': details, 'hint': null});

void main() {
  test('an answer is returned as it came, an object and a list by their shape', () async {
    expect(await _rpc((_) => _json(200, {'a': 1})).object('f_v1', {}), {'a': 1});
    expect(await _rpc((_) => _json(200, [1, 2])).list('f_v1', {}), [1, 2]);
    expect(await _rpc((_) => _json(200, 7)).run('f_v1', {}), 7);
  });

  test('an answer of the wrong shape throws, naming the function', () async {
    await expectLater(
      _rpc((_) => _json(200, [1])).object('stock_x_v1', {}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('stock_x_v1'))),
    );
    await expectLater(
      _rpc((_) => _json(200, {'a': 1})).list('stock_y_v1', {}),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('stock_y_v1'))),
    );
  });

  test('a refusal of the server is its typed failure, for run, object and list alike', () async {
    final rpc = _rpc((_) => _refused(DkCode.dkg10));
    await expectLater(rpc.run('f_v1', {}), throwsA(isA<StockConfigStale>()));
    await expectLater(rpc.object('f_v1', {}), throwsA(isA<StockConfigStale>()));
    await expectLater(rpc.list('f_v1', {}), throwsA(isA<StockConfigStale>()));
    await expectLater(_rpc((_) => _refused(DkCode.dkg08)).run('f_v1', {}), throwsA(isA<StockConfigInUse>()));
    await expectLater(_rpc((_) => _refused(DkCode.dkg03, 'only 2 on hand')).run('f_v1', {}), throwsA(isA<StockNotEnough>()));
    await expectLater(
      _rpc((_) => _refused(DkCode.dkg11, 'x', jsonEncode({'field': 'name', 'reason': 'taken'}))).run('f_v1', {}),
      throwsA(isA<StockConfigRefused>().having((e) => e.field, 'field', 'name')),
    );
  });

  // #4411 -- a code the stock table does not know leaves the boundary as the
  // app's own refusal with its code, never as the SDK's type.
  test('a refusal that is not one of ours is the app refusal with its code', () async {
    await expectLater(
      _rpc((_) => _refused(PgCode.insufficientPrivilege, 'permission denied')).run('f_v1', {}),
      throwsA(isA<Refusal>().having((e) => e.code, 'code', PgCode.insufficientPrivilege)),
    );
  });

  test('guard maps a refusal of any read, a table included', () async {
    final rpc = _rpc((_) => _refused(DkCode.dkg10));
    await expectLater(rpc.guard('a read', () async => throw const PostgrestException(message: 'm', code: DkCode.dkg10)), throwsA(isA<StockConfigStale>()));
    expect(await rpc.guard('a read', () async => 3), 3);
  });

  // #4411 -- a failure that is not a refusal is logged once, at error, with
  // the error passed as an error (the redactor and the network classification
  // see it), and rethrown as it came.
  test('a failure that is not a refusal is one error entry with its error', () async {
    final logger = TraceLogger();
    final previous = TraceLogger.instance;
    TraceLogger.instance = logger;
    addTearDown(() => TraceLogger.instance = previous);
    final rpc = _rpc((_) => _json(200, 1));
    await expectLater(
      rpc.guard('a stock read', () async => throw StateError('a defect')),
      throwsA(isA<StateError>()),
    );
    final entries = [
      for (final e in logger.entries)
        if (e.area == 'stock') e,
    ];
    expect(entries, hasLength(1));
    expect(entries.single.level, TraceLevel.error);
    expect(entries.single.error, isNotNull);
  });

  test('a refusal is logged at warn with its error', () async {
    final logger = TraceLogger();
    final previous = TraceLogger.instance;
    TraceLogger.instance = logger;
    addTearDown(() => TraceLogger.instance = previous);
    await expectLater(
      _rpc((_) => _refused(DkCode.dkg10)).run('f_v1', {}),
      throwsA(isA<StockConfigStale>()),
    );
    final entry = logger.entries.singleWhere((e) => e.area == 'stock');
    expect(entry.level, TraceLevel.warn);
    expect(entry.error, isNotNull);
  });
}
