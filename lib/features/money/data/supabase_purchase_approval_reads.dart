// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/purchase_approval_reads.dart';

/// Server-gated reads for bills the current member can decide.
class SupabasePurchaseApprovalReads implements PurchaseApprovalReads {
  const SupabasePurchaseApprovalReads(this.client);

  final SupabaseClient client;

  @override
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  }) async => PurchaseApprovalPage.fromJson(
    await client.rpc<Object?>(
      'purchase_approval_page_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_after_created': ?after?.created,
        'p_after_id': ?after?.id,
      },
    ),
  );

  @override
  Future<PurchaseApprovalDetail> detail(
    String workspaceId,
    String purchaseId,
  ) async => PurchaseApprovalDetail.fromJson(
    await client.rpc<Object?>(
      'purchase_approval_detail_v1',
      params: {'p_workspace_id': workspaceId, 'p_purchase_id': purchaseId},
    ),
  );
}
