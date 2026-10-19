// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import '../domain/asset_valuation.dart';

/// The accountant's valuations and their RPCs (0500). Reading checks the
/// right on the server; every write derives actor and rights there.
class SupabaseAssetValuationRepository implements AssetValuationRepository {
  const SupabaseAssetValuationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ValuationBatch>> fetchBatches(String workspaceId) async {
    final json = await _client.rpc<Object?>(
      'asset_valuations_page_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_filters': <String, Object?>{},
        'p_cursor': null,
      },
    );
    return [
      for (final b in JsonReader.of(
        json,
        context: 'valuation batches',
      ).list('batches'))
        ValuationBatch.fromJson(b),
    ];
  }

  @override
  Future<List<ValuationRow>> fetchRows(
    String workspaceId,
    String batchId,
  ) async {
    final json = await _client.rpc<Object?>(
      'asset_valuations_page_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_filters': {'batch_id': batchId},
        'p_cursor': null,
      },
    );
    return [
      for (final r in JsonReader.of(
        json,
        context: 'valuation rows',
      ).list('rows'))
        ValuationRow.fromJson(r),
    ];
  }

  @override
  Future<ValuationBatch> stage(
    String workspaceId, {
    required ValuationCsv file,
    required ValuationSource source,
    required String requestId,
  }) async => ValuationBatch.fromJson(
    await _client.rpc<Object?>(
      'stage_asset_valuations_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_metadata': {
          'basis': file.basis?.wire,
          'source_system': source.system,
          'source_reference': source.reference,
          'source_hash': file.sha256Hex,
          'period_from': file.periodFrom == null
              ? null
              : isoDay(file.periodFrom!),
          'period_to': file.periodTo == null ? null : isoDay(file.periodTo!),
          'currency': file.currency,
          'movements': source.movements,
          'complete_scope': source.completeScope,
        },
        'p_rows': [for (final r in file.rows) r.toJson()],
      },
    ),
  );

  @override
  Future<ValuationBatch> confirm(
    String workspaceId, {
    required ValuationBatch batch,
    required String requestId,
    String? supersedes,
    String reason = '',
  }) async => ValuationBatch.fromJson(
    await _client.rpc<Object?>(
      'confirm_asset_valuations_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_batch_id': batch.id,
        'p_revision': batch.revision,
        'p_supersedes': supersedes,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    ),
  );
}
