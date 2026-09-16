// SPDX-License-Identifier: 0BSD
//
// #1310 S2 — an export that stops short is worse than one that fails.
//
// PostgREST caps every response at the project's `max_rows`. A `select`
// with no `range` therefore returns *at most* that many rows and says
// nothing about it: the caller gets a short list that looks complete.
// For a screen that is a display bug; for an export it is a silent loss
// of the operator's data, discovered only when somebody counts.
//
// So export reads page until a page comes back short, which is the one
// termination condition that is correct whatever the cap happens to be
// — we never have to know the number, and a cap changed in the
// dashboard cannot quietly break the export.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

/// Rows per request. Comfortably under Supabase's default `max_rows` of
/// 1000, so a full page is always the page size rather than the cap —
/// which is what makes "a short page means the end" true.
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
}) async {
  final all = <Map<String, dynamic>>[];
  var from = 0;

  while (true) {
    final page = await build().range(from, from + pageSize - 1);
    all.addAll(page.map(Map<String, dynamic>.from));

    // A short page is the end of the data — the only signal that does
    // not depend on knowing the server's cap.
    if (page.length < pageSize) return all;

    from += pageSize;
    if (all.length >= maxRows) {
      throw ExportTooLargeException(table, maxRows);
    }
  }
}
