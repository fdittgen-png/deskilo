// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/retention_hold.dart';

/// Retention holds through their three definer functions.
class SupabaseRetentionHoldRepository implements RetentionHoldRepository {
  SupabaseRetentionHoldRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RetentionHold>> fetchHolds(String workspaceId) async {
    final rows = await _client.rpc<Object?>(
      'retention_holds',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final row in (rows as List? ?? const []))
        RetentionHold.fromJson(row),
    ];
  }

  @override
  Future<RetentionHold> placeHold({
    required String workspaceId,
    String? issuerSiteId,
    String? docClass,
    required String reason,
  }) async => RetentionHold.fromJson(
    await _client.rpc<Object?>(
      'place_retention_hold',
      params: {
        'p_workspace_id': workspaceId,
        'p_issuer_site_id': issuerSiteId,
        'p_doc_class': docClass,
        'p_reason': reason,
      },
    ),
  );

  @override
  Future<RetentionHold> releaseHold(String holdId, String reason) async =>
      RetentionHold.fromJson(
        await _client.rpc<Object?>(
          'release_retention_hold',
          params: {'p_hold_id': holdId, 'p_reason': reason},
        ),
      );
}
