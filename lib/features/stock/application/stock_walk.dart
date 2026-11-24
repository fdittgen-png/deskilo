// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4161 (B) -- a walk over the pages of one stock read: the first page, then
// each page from the cursor the last one gave. A failed page keeps the rows
// already shown and the cursor, so the same page can be asked again; a
// refusal or a failure is never shown as an empty list. #4401: the one walk
// of stock -- on hand, the movements, the registry of items and the goods of
// a document each give it their page function.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/stock_page.dart';

/// What one walk reads: a business, and the filters the person chose.
typedef StockFilters = ({
  String workspaceId,
  String? itemId,
  String? locationId,
});

/// The rows read so far, and where the walk stands.
class StockWalkState<T> {
  const StockWalkState({
    this.rows = const [],
    this.next,
    this.complete = false,
    this.loading = true,
    this.error,
    this.first,
  });

  final List<T> rows;

  /// The first page as read: what the read says as a whole beside its rows (the goods of a document say whether a
  /// recorded link reaches them).
  final StockPage<T>? first;

  /// The cursor of the last page, when more follows.
  final StockCursor? next;

  /// Nothing follows the rows shown.
  final bool complete;

  /// A page is being read.
  final bool loading;

  /// Why the last page could not be read: the rows above stay, and the same
  /// page can be asked again.
  final Object? error;

  bool get isFirstLoad => loading && rows.isEmpty && error == null;
  bool get failedFirst => error != null && rows.isEmpty;
  bool get canLoadMore => !complete && !loading && next != null;
}

/// The walk of one read.
class StockWalk<T> extends Notifier<StockWalkState<T>> {
  StockWalk(this._read);

  /// The page function: given the walk's [Ref], reads the page after a cursor (the first when null).
  final Future<StockPage<T>> Function(StockCursor? after) Function(Ref ref)
  _read;

  @override
  StockWalkState<T> build() {
    unawaited(Future.microtask(() => loadMore(first: true)));
    return const StockWalkState();
  }

  /// Reads the next page, or the first. Asking again after a failure asks
  /// the same page.
  Future<void> loadMore({bool first = false}) async {
    final current = state;
    if (!first && (current.loading || current.complete)) return;
    state = StockWalkState(rows: current.rows, next: current.next, first: current.first);
    try {
      final page = await _read(ref)(first ? null : current.next);
      if (!ref.mounted) return;
      state = StockWalkState(
        rows: [...current.rows, ...page.rows],
        next: page.next,
        complete: page.complete,
        loading: false,
        first: first ? page : current.first,
      );
    } on Object catch (error, stack) {
      TraceLogger.instance.warn('stock', 'a stock page could not be read', error: error, stackTrace: stack);
      if (!ref.mounted) return;
      state = StockWalkState(
        rows: current.rows,
        next: current.next,
        loading: false,
        error: error,
        first: current.first,
      );
    }
  }

  /// Starts again from the first page.
  Future<void> reload() async {
    state = const StockWalkState();
    await loadMore(first: true);
  }
}
