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

import 'package:supabase_flutter/supabase_flutter.dart';

/// Rows per request. Under Supabase's default `max_rows` of 1000; a
/// lower cap only means more, shorter pages (#1848).
const int kExportPageSize = 500;

/// A hard ceiling on total rows, so a bug in the termination condition
/// cannot spin for ever against a live project. Well above any real
/// workspace: 200 pages of 500.
const int kExportMaxRows = 100000;

/// Thrown when an export read hits [kExportMaxRows].
///
/// #1310's rule: *if a page limit is ever reached unexpectedly, the
/// export fails with a message rather than returning less.* Silence is
/// the failure mode being fixed here, so this must never be swallowed
/// into a shorter list.
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
  int pageSize = kExportPageSize,
  int maxRows = kExportMaxRows,
}) =>
    fetchPages(
      table: table,
      page: (from, to) async => [
        for (final row in await build().range(from, to))
          Map<String, dynamic>.from(row),
      ],
      pageSize: pageSize,
      maxRows: maxRows,
    );

/// #1848 — the paging loop, with the page read handed in (tests drive it
/// with a server that caps below the page size).
///
/// A page SHORTER than requested is not the end: a server whose cap is
/// below [pageSize] returns short pages all the way through. The next
/// page starts after the rows actually returned, and only an EMPTY page
/// ends the read. The caller's order must be total (add a unique
/// tie-breaker such as `id`), or rows can repeat or vanish between pages.
Future<List<Map<String, dynamic>>> fetchPages({
  required String table,
  required Future<List<Map<String, dynamic>>> Function(int from, int to) page,
  int pageSize = kExportPageSize,
  int maxRows = kExportMaxRows,
}) async {
  final all = <Map<String, dynamic>>[];
  while (true) {
    final rows = await page(all.length, all.length + pageSize - 1);
    if (rows.isEmpty) return all;
    all.addAll(rows);
    if (all.length >= maxRows) {
      throw ExportTooLargeException(table, maxRows);
    }
  }
}
