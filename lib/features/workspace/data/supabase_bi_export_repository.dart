// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The export read on the server (`bi_export_snapshot_v1`): its refusals,
// typed. Nothing is retried here: an export is asked once per click.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/bi_batch.dart';
import '../domain/bi_report_snapshot.dart';

class SupabaseBiExportRepository implements BiExportRepository {
  SupabaseBiExportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> snapshot(
    String workspaceId, {
    required List<BiBatchRequest> requests,
    required BiExportFormat format,
    String? reportId,
    int? reportRevision,
  }) async {
    try {
      return await _client.rpc<Object?>(
        'bi_export_snapshot_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_requests': [for (final r in requests) r.toJson()],
          'p_report_id': reportId,
          'p_report_revision': reportRevision,
          'p_format': format.name,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the export sheet says it.
      Error.throwWithStackTrace(BiExportRefused(_failureOf(e.code)), st);
    }
  }
}

/// The failure a SQLSTATE of the export read stands for.
BiExportFailure _failureOf(String? code) => switch (code) {
  '42501' => BiExportFailure.forbidden,
  '0A000' => BiExportFailure.off,
  '54000' => BiExportFailure.tooLarge,
  '40001' => BiExportFailure.stale,
  '22023' => BiExportFailure.invalid,
  _ => BiExportFailure.unavailable,
};
