// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- the one way the stock data layer calls the server: a refusal becomes its typed failure the
// same way everywhere (`throwStockFailure`), is logged once, and an answer of the wrong shape throws
// (a FormatException naming the function), never shown as an empty result.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/paged_fetch.dart';
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

  /// #4401 -- the most rows a configuration list holds (places, location kinds, units, codes, dimensions, variants,
  /// mappings, reorder points, count plans): far beyond any real business, so a longer list is a defect, refused as
  /// [StockListTooLong] rather than shown. A technical bound, not a business value: a list that grows with the
  /// business (items, suppliers, transfers, allocations) is read through [pages] and has no such cap.
  static const int listCap = 5000;

  /// Every row of a configuration list [build] selects, page by page (`fetchAllPages`: ended by an empty page,
  /// never by the server's own row cap), refused as [StockListTooLong] past [listCap].
  Future<List<Map<String, dynamic>>> rows(String what, PostgrestTransformBuilder<PostgrestList> Function() build) =>
      guard(what, () async {
        try {
          return await fetchAllPages(table: what, build: build, maxRows: listCap);
        } on ExportTooLargeException catch (e, stack) {
          Error.throwWithStackTrace(StockListTooLong(what, listCap), stack);
        }
      });

  /// Every row of a list that grows with the business [build] selects, page by page, with no cap of its own
  /// (`fetchAllPages`' safety ceiling only). [build] orders by a unique key last, so no row repeats or is skipped
  /// between pages.
  Future<List<Map<String, dynamic>>> pages(String what, PostgrestTransformBuilder<PostgrestList> Function() build) =>
      guard(what, () => fetchAllPages(table: what, build: build));

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
