// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/time/date_text.dart';
import '../domain/book_period.dart';

/// The book periods, the export log and their RPCs (0504). Reading checks
/// the right on the server; every write derives actor and rights there.
class SupabaseBookPeriodRepository implements BookPeriodRepository {
  const SupabaseBookPeriodRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BookPeriodsOverview> fetch(String workspaceId) async =>
      BookPeriodsOverview.fromJson(
        await _client.rpc<Object?>(
          'book_periods_v1',
          params: {'p_workspace_id': workspaceId},
        ),
      );

  @override
  Future<BookPeriod> close(String workspaceId, DateTime from, DateTime to) async =>
      BookPeriod.fromJson(
        await _client.rpc<Object?>(
          'close_book_period_v1',
          params: {
            'p_workspace_id': workspaceId,
            'p_from': isoDay(from),
            'p_to': isoDay(to),
          },
        ),
      );

  @override
  Future<BookPeriod> reopen(
    String workspaceId,
    String periodId,
    String reason,
  ) async => BookPeriod.fromJson(
    await _client.rpc<Object?>(
      'reopen_book_period_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_period_id': periodId,
        'p_reason': reason,
      },
    ),
  );

  @override
  Future<void> recordExport(String workspaceId, BookExportRecord record) async {
    await _client.rpc<Object?>(
      'record_book_export_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_format_id': record.formatId,
        'p_from': isoDay(record.from),
        'p_to': isoDay(record.to),
        'p_sha256': record.sha256,
        'p_bytes': record.bytes,
        'p_rows': record.rows,
        'p_documents': record.documents,
      },
    );
  }
}
