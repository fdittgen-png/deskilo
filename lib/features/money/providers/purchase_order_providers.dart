// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase orders: their repository (overridable in tests and
// the demonstration) and the space's list.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_purchase_order_repository.dart';
import '../domain/purchase_order.dart';
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
