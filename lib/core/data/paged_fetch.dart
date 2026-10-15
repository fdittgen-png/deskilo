// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1310 S2 — an export that stops short is worse than one that fails.
//
// PostgREST caps every response at the project's `max_rows`. A `select`
// with no `range` therefore returns *at most* that many rows and says
// nothing about it: the caller gets a short list that looks complete.
// For a screen that is a display bug; for an export it is a silent loss
// of the operator's data, discovered only when somebody counts.
//
// So reads page until a page comes back EMPTY (#1848): a short page is
// what every page looks like when the server's cap is below the page
// size, so "short means the end" silently dropped everything past the
// first cap's worth. Empty is the one end signal that holds whatever the
// cap is — we never have to know the number.
library;

import 'package:meta/meta.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'read_provenance.dart';

/// Rows per request. Under Supabase's default `max_rows` of 1000; a
/// lower cap only means more, shorter pages (#1848).
const int _kExportPageSize = 500;

/// A hard ceiling on total rows, so a bug in the termination condition
/// cannot spin for ever against a live project. Well above any real
/// workspace: 200 pages of 500.
const int _kExportMaxRows = 100000;

/// Thrown when an export read hits [_kExportMaxRows].
///
/// #1310's rule: *if a page limit is ever reached unexpectedly, the
/// export fails with a message rather than returning less.* Silence is
/// the failure mode being fixed here, so this must never be swallowed
/// into a shorter list.
@visibleForTesting
class ExportTooLargeException implements Exception {
  const ExportTooLargeException(this.table, this.rows);

  final String table;
  final int rows;

  @override
  String toString() =>
      'ExportTooLargeException: $table returned more than $rows rows — '
      'the export was stopped rather than silently truncated.';
}

/// Reads every row [build] selects, one page at a time.
///
/// [build] is called once per page and must return a fresh builder: a
/// PostgREST builder is single-use, so reusing one across pages fails on
/// the second call. The caller orders inside [build]; an unordered
/// paged read can repeat or skip rows between pages, because the server
/// is free to return them differently each time.
///
/// ```dart
/// final rows = await fetchAllPages(
///   table: 'reservations',
///   build: () => _client
///       .from('reservations')
///       .select()
///       .eq('workspace_id', workspaceId)
///       .order('starts_at', ascending: true),
/// );
/// ```
Future<List<Map<String, dynamic>>> fetchAllPages({
  required String table,
  required PostgrestTransformBuilder<PostgrestList> Function() build,
  int pageSize = _kExportPageSize,
  int maxRows = _kExportMaxRows,
  Future<int> Function()? count,
}) async => (await _fetchAllPagesRead(
  table: table,
  build: build,
  pageSize: pageSize,
  maxRows: maxRows,
  count: count,
)).rows;

/// [fetchAllPages] with what it may claim (#2587): the rows of a bounded
/// TRAVERSAL, never a snapshot. See [fetchPagesRead].
Future<ProvenancedRows<Map<String, Object?>>> _fetchAllPagesRead({
  required String table,
  required PostgrestTransformBuilder<PostgrestList> Function() build,
  int pageSize = _kExportPageSize,
  int maxRows = _kExportMaxRows,
  Future<int> Function()? count,
}) => fetchPagesRead(
  count: count,
  table: table,
  page: (from, to) async => [
    for (final row in await build().range(from, to))
      Map<String, dynamic>.from(row),
  ],
  pageSize: pageSize,
  maxRows: maxRows,
);

/// [fetchPages] with the honest provenance of what it read (#2587).
///
/// The closing exact [count] and unique ids DETECT some instability (the
/// read is repeated, then refused with [IncompleteReadException]); an
/// agreeing count never promotes the traversal to a snapshot — a delete
/// plus an insert between two pages keeps both the count and the number of
/// unique ids while omitting a row and keeping a deleted one. The
/// completeness is therefore always [ReadCompleteness.boundedTraversal];
/// an exact financial or BI result comes from ONE server response under one
/// statement snapshot instead.
@visibleForTesting
Future<ProvenancedRows<Map<String, Object?>>> fetchPagesRead({
  required String table,
  required Future<List<Map<String, Object?>>> Function(int from, int to) page,
  int pageSize = _kExportPageSize,
  int maxRows = _kExportMaxRows,
  Future<int> Function()? count,
  int attempts = 3,
}) async {
  final rows = await fetchPages(
    table: table,
    page: page,
    pageSize: pageSize,
    maxRows: maxRows,
    count: count,
    attempts: attempts,
  );
  return ProvenancedRows(
    rows,
    ReadProvenance.traversal(
      queryFingerprint: table,
      reason: count == null
          ? 'offset traversal, no closing count'
          : 'offset traversal, count and ids agreed (not a snapshot)',
    ),
  );
}

/// #1848 — the paging loop, with the page read handed in (tests drive it
/// with a server that caps below the page size).
///
/// A page SHORTER than requested is not the end: a server whose cap is
/// below [pageSize] returns short pages all the way through. The next
/// page starts after the rows actually returned, and only an EMPTY page
/// ends the read. The caller's order must be total (add a unique
/// tie-breaker such as `id`), or rows can repeat or vanish between pages.
@visibleForTesting
Future<List<Map<String, dynamic>>> fetchPages({
  required String table,
  required Future<List<Map<String, dynamic>>> Function(int from, int to) page,
  int pageSize = _kExportPageSize,
  int maxRows = _kExportMaxRows,
  Future<int> Function()? count,
  int attempts = 3,
}) async {
  for (var attempt = 1;; attempt++) {
    final all = <Map<String, dynamic>>[];
    while (true) {
      final rows = await page(all.length, all.length + pageSize - 1);
      if (rows.isEmpty) break;
      all.addAll(rows);
      if (all.length >= maxRows) {
        throw ExportTooLargeException(table, maxRows);
      }
    }
    if (count == null) return all;
    // Offset traversal is not a snapshot (#1848, #2587): a row inserted,
    // deleted or retimed between two pages repeats or skips rows. A repeat
    // or a count mismatch is DETECTED: the read is made again and after
    // [attempts] refused. Agreement only means "not visibly unstable" —
    // see [fetchPagesRead], which never calls it a snapshot.
    final ids = {for (final r in all) r['id']};
    if (ids.length == all.length && await count() == all.length) return all;
    if (attempt >= attempts) throw IncompleteReadException(table);
  }
}

/// A paged read whose rows changed under it on every attempt: what it
/// would return can be neither proven complete nor shown as free capacity.
@visibleForTesting
class IncompleteReadException implements Exception {
  const IncompleteReadException(this.table);
  final String table;

  @override
  String toString() => 'IncompleteReadException: $table changed while it '
      'was being read — the window is incomplete.';
}

/// #2011 — ids per `in.(…)` request: bounded, so a large plan never builds
/// an unbounded URL.
const int _kInChunk = 100;

/// [ids] in consecutive chunks of at most [size].
@visibleForTesting
List<List<String>> chunked(List<String> ids, [int size = _kInChunk]) => [
  for (var i = 0; i < ids.length; i += size)
    ids.sublist(i, i + size > ids.length ? ids.length : i + size),
];

/// #2011 — every row [build] selects for [ids]: the ids in bounded chunks,
/// each chunk paged to the end ([fetchAllPages]). [build] filters by its
/// chunk and orders totally.
Future<List<Map<String, dynamic>>> fetchAllIn({
  required String table,
  required List<String> ids,
  required PostgrestTransformBuilder<PostgrestList> Function(List<String> chunk)
      build,
}) async => [
  for (final chunk in chunked(ids))
    ...await fetchAllPages(table: table, build: () => build(chunk)),
];
