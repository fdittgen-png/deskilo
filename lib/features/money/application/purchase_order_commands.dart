// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — what a buyer asks of the purchase orders: save a draft, mark a
// printed one sent, cancel one with its reason. The server decides; the
// list is read again after each.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/purchase_order.dart';
import '../providers/purchase_order_providers.dart';

class PurchaseOrderCommands {
  PurchaseOrderCommands(this._ref);

  final Ref _ref;

  PurchaseOrderRepository get _repo =>
      _ref.read(purchaseOrderRepositoryProvider);

  Future<PurchaseOrder> save(
    String workspaceId,
    String requestId,
    PurchaseOrderDraft draft,
  ) => _refreshed(workspaceId, _repo.save(workspaceId, requestId, draft));

  Future<PurchaseOrder> markSent(
    String workspaceId,
    PurchaseOrder order,
    String requestId,
  ) => _refreshed(
    workspaceId,
    _repo.markSent(workspaceId, order.id, order.revision, requestId),
  );

  Future<PurchaseOrder> cancel(
    String workspaceId,
    PurchaseOrder order,
    String reason,
    String requestId,
  ) => _refreshed(
    workspaceId,
    _repo.cancel(workspaceId, order.id, order.revision, reason, requestId),
  );

  Future<PurchaseOrder> _refreshed(
    String workspaceId,
    Future<PurchaseOrder> done,
  ) async {
    final order = await done;
    _ref.invalidate(purchaseOrdersProvider(workspaceId));
    return order;
  }
}

final purchaseOrderCommandsProvider = Provider<PurchaseOrderCommands>(
  PurchaseOrderCommands.new,
);
