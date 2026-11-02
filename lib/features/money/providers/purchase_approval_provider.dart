// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_purchase_approval_reads.dart';
import '../domain/purchase_approval_reads.dart';
import 'credit_providers.dart';

final purchaseApprovalReadsProvider = Provider<PurchaseApprovalReads>(
  (ref) => SupabasePurchaseApprovalReads(ref.watch(moneyClientProvider)),
);

/// The first page supplies the badge count; errors are never converted to zero.
final purchaseApprovalPageProvider = FutureProvider.autoDispose
    .family<
      PurchaseApprovalPage,
      ({String workspaceId, PurchaseApprovalCursor? after})
    >(
      (ref, key) => ref
          .watch(purchaseApprovalReadsProvider)
          .page(key.workspaceId, after: key.after),
    );

final purchaseApprovalDetailProvider = FutureProvider.autoDispose
    .family<PurchaseApprovalDetail, ({String workspaceId, String purchaseId})>(
      (ref, key) => ref
          .watch(purchaseApprovalReadsProvider)
          .detail(key.workspaceId, key.purchaseId),
    );
