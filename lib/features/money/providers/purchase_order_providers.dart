// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders: their repository (overridable in tests and
// the demonstration) and the space's list.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_purchase_order_repository.dart';
import '../domain/purchase_order.dart';
import '../domain/purchase_order_receipt.dart';
import 'credit_providers.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>(
  (ref) => SupabasePurchaseOrderRepository(ref.watch(moneyClientProvider)),
);

/// The space's purchase orders, the latest first.
final purchaseOrdersProvider = FutureProvider.autoDispose
    .family<List<PurchaseOrder>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseOrderRepositoryProvider).fetchOrders(workspaceId),
    );

/// #3307 — the space's e-mail attempts, the latest first.
final purchaseOrderSendsProvider = FutureProvider.autoDispose
    .family<List<PurchaseOrderSend>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseOrderRepositoryProvider).fetchSends(workspaceId),
    );

/// #3307 — how the space e-mails its orders; null before it is configured.
final purchaseOrderMailSettingsProvider = FutureProvider.autoDispose
    .family<PurchaseOrderMailSettings?, String>(
      (ref, workspaceId) => ref
          .watch(purchaseOrderRepositoryProvider)
          .fetchMailSettings(workspaceId),
    );

/// #3307 — the space's deliveries, the latest first.
final purchaseOrderReceiptsProvider = FutureProvider.autoDispose
    .family<List<PurchaseOrderReceipt>, String>(
      (ref, workspaceId) =>
          ref.watch(purchaseOrderRepositoryProvider).fetchReceipts(workspaceId),
    );
