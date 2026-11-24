// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- the one way the stock data layer calls the server: a refusal becomes its typed failure the
// same way everywhere (`throwStockFailure`), is logged once, and an answer of the wrong shape throws
// (a FormatException naming the function), never shown as an empty result.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import 'stock_refusals.dart';

/// A list read found more rows than [StockRpc.listCap]: it is refused, never shown cut short as if it were
/// the whole list.
class StockListTooLong implements Exception {
  const StockListTooLong(this.what, this.cap);

  final String what;
  final int cap;

  @override
  String toString() => 'StockListTooLong($what: more than $cap rows)';
}

/// The stock functions and reads behind the ports, called through one helper.
class StockRpc {
  const StockRpc(this._client);

  final SupabaseClient _client;

  /// #4401 -- the most rows a list read of configuration takes (places, items, units, codes, variants, mappings,
  /// points, plans, allocations): far above what one business holds, and a bound, so no read is unbounded. A page of
  /// the ledger is read by its own paged function, never by this.
  static const int listCap = 5000;

  /// [query]'s rows, at most [listCap]: a longer list is a [StockListTooLong], never silently cut. A refusal
  /// becomes its typed failure as every call through [guard] does.
  Future<List<Map<String, dynamic>>> rows(String what, PostgrestTransformBuilder<PostgrestList> query) =>
      guard(what, () async {
        final rows = await query.limit(listCap + 1);
        if (rows.length > listCap) throw StockListTooLong(what, listCap);
        return rows;
      });

  /// Runs [read]: a refusal of the server is logged once at warn as "[what] was refused" and thrown as
  /// its typed failure; anything else (a lost connection, a defect) is logged once at error and
  /// rethrown as it came (#4411). [pieces]: the command names pieces (#4379).
  Future<T> guard<T>(String what, Future<T> Function() read, {bool pieces = false}) async {
    try {
      return await read();
    } on PostgrestException catch (e, stack) {
      TraceLogger.instance.warn('stock', '$what was refused: ${e.code}', error: e, stackTrace: stack);
      throwStockFailure(e, stack, pieces: pieces);
    } on Object catch (e, stack) {
      TraceLogger.instance.error('stock', '$what failed', error: e, stackTrace: stack);
      rethrow;
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
