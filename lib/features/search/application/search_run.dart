// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — one search at a time. Every request carries a generation; an
// answer to an older request, or to another account, server or workspace,
// is dropped, so a slow "Al" never replaces "Alice" and a search started in
// one workspace never shows in the next. Each source is bounded in count
// and in time; a source that fails gives nothing and is traced.
import 'dart:async';

import '../../../core/trace/trace_logger.dart';
import '../domain/search_result.dart';

class SearchRun {
  SearchRun({this.perSource = 6, this.timeout = const Duration(seconds: 4)});

  /// The most results one source gives.
  final int perSource;

  /// How long a source is waited for.
  final Duration timeout;

  int _generation = 0;

  /// Forgets every request in flight (the scope changed, the search
  /// closed): their answers are dropped.
  void discard() => _generation++;

  /// The results of [sources] for [query] in [scope]; null when a newer
  /// request or a [discard] came first.
  Future<List<SearchResult>?> run(
    SearchScope scope,
    String query,
    List<SearchSource> sources, {
    required SearchScope? Function() currentScope,
  }) async {
    final mine = ++_generation;
    final parts = await Future.wait([
      for (final s in sources) _bounded(s, query),
    ]);
    if (mine != _generation || currentScope() != scope) return null;
    return [for (final p in parts) ...p];
  }

  Future<List<SearchResult>> _bounded(SearchSource s, String query) async {
    try {
      final found = await s.search(query).timeout(timeout);
      return found.take(perSource).toList();
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'search',
        'source ${s.id} gave no answer',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }
}
