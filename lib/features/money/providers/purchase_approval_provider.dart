// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_purchase_approval_reads.dart';
import '../domain/purchase_approval_reads.dart';
import 'credit_providers.dart';

export 'credit_providers.dart' show purchaseApprovalAccessProvider;

final purchaseApprovalReadsProvider = Provider<PurchaseApprovalReads>(
  (ref) => SupabasePurchaseApprovalReads(ref.watch(moneyClientProvider)),
);

/// The first page supplies the badge count; errors are never converted to zero.
final purchaseApprovalPageProvider = FutureProvider.autoDispose
    .family<
      PurchaseApprovalPage,
      ({String workspaceId, PurchaseApprovalCursor? after})
    >((ref, key) {
      if (!ref.watch(purchaseApprovalAccessProvider(key.workspaceId))) {
        throw StateError('purchase approvals are not available');
      }
      return ref
          .watch(purchaseApprovalReadsProvider)
          .page(key.workspaceId, after: key.after);
    }, name: 'purchaseApprovalPageProvider');

final purchaseApprovalDetailProvider = FutureProvider.autoDispose
    .family<PurchaseApprovalDetail, ({String workspaceId, String purchaseId})>((
      ref,
      key,
    ) async {
      if (!ref.watch(purchaseApprovalAccessProvider(key.workspaceId))) {
        throw StateError('purchase approvals are not available');
      }
      final pendingPage = ref.watch(
        purchaseApprovalPageProvider((
          workspaceId: key.workspaceId,
          after: null,
        )).future,
      );
      final reads = ref.watch(purchaseApprovalReadsProvider);
      await pendingPage;
      return reads.detail(key.workspaceId, key.purchaseId);
    }, name: 'purchaseApprovalDetailProvider');
