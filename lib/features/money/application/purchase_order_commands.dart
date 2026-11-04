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

  /// E-mails [order] under [attemptId]; the list and the attempts are
  /// read again whatever the outcome.
  Future<PurchaseOrderSend> sendByEmail(
    String workspaceId,
    PurchaseOrder order,
    String attemptId,
    PurchaseOrderMail mail,
  ) async {
    try {
      return await _repo.sendByEmail(workspaceId, order, attemptId, mail);
    } finally {
      _ref
        ..invalidate(purchaseOrdersProvider(workspaceId))
        ..invalidate(purchaseOrderSendsProvider(workspaceId));
    }
  }

  /// A person decides an attempt nobody could confirm.
  Future<PurchaseOrderSend> resolveSend(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) async {
    final send = await _repo.resolveSend(
      workspaceId,
      attemptId,
      delivered: delivered,
    );
    _ref
      ..invalidate(purchaseOrdersProvider(workspaceId))
      ..invalidate(purchaseOrderSendsProvider(workspaceId));
    return send;
  }

  Future<PurchaseOrderMailSettings> saveMailSettings(
    String workspaceId,
    PurchaseOrderMailDraft draft,
  ) async {
    final saved = await _repo.saveMailSettings(workspaceId, draft);
    _ref.invalidate(purchaseOrderMailSettingsProvider(workspaceId));
    return saved;
  }

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
