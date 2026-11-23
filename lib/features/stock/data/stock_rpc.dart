// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- the one way the stock data layer calls the server: a refusal becomes its typed failure the
// same way everywhere (`throwStockFailure`), is logged once, and an answer of the wrong shape throws
// (a FormatException naming the function), never shown as an empty result.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import 'stock_refusals.dart';

/// The stock functions and reads behind the ports, called through one helper.
class StockRpc {
  const StockRpc(this._client);

  final SupabaseClient _client;

  /// Runs [read]: a refusal of the server is logged once as "[what] was refused" and thrown as its
  /// typed failure; anything else is rethrown as it came.
  Future<T> guard<T>(String what, Future<T> Function() read) async {
    try {
      return await read();
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('stock', '$what was refused: ${e.code}', stackTrace: stack);
      throwStockFailure(e, stack);
    }
  }

  /// `fn` with [params]: its answer as it came.
  Future<Object?> run(String fn, Map<String, Object?> params, {String? what}) =>
      guard(what ?? fn, () => _client.rpc<Object?>(fn, params: params));

  /// `fn`'s answer, which must be a JSON object.
  Future<Map<String, Object?>> object(String fn, Map<String, Object?> params, {String? what}) async {
    final answer = await run(fn, params, what: what);
    if (answer is! Map) throw FormatException('$fn did not answer an object');
    return Map<String, Object?>.from(answer);
  }

  /// `fn`'s answer, which must be a JSON list.
  Future<List<Object?>> list(String fn, Map<String, Object?> params, {String? what}) async {
    final answer = await run(fn, params, what: what);
    if (answer is! List) throw FormatException('$fn did not answer a list');
    return answer;
  }
}
