// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the order a supplier bill charges, picked in the bill dialog
// while the purchase orders are on: the space's orders that were sent
// (sent, partly or wholly received) to the bill's supplier, or to any
// supplier before one is chosen. Picking one hands it to the dialog, which
// takes its amounts; the server links the bill (0677).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';

class PurchaseBillOrderField extends ConsumerWidget {
  const PurchaseBillOrderField({
    required this.workspaceId,
    required this.supplierId,
    required this.orderId,
    required this.onChanged,
    super.key,
  });

  final String workspaceId;
  final String? supplierId;
  final String? orderId;

  /// The order picked, or null for none.
  final ValueChanged<PurchaseOrder?> onChanged;

  static bool _charged(PurchaseOrder o) =>
      o.state != PurchaseOrderState.draft &&
      o.state != PurchaseOrderState.cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!featureOn(
      ref.watch(enabledFeatureKeysProvider),
      purchaseOrdersKey,
      byDefault: false,
    )) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final orders = [
      for (final o
          in ref.watch(purchaseOrdersProvider(workspaceId)).value ??
              const <PurchaseOrder>[])
        if (_charged(o) && (supplierId == null || o.supplierId == supplierId))
          o,
    ];
    if (orders.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<String?>(
      key: const ValueKey('purchase-order-link'),
      initialValue: orders.any((o) => o.id == orderId) ? orderId : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.purchaseBillOrder,
        helperText: l10n.purchaseBillOrderHint,
      ),
      items: [
        DropdownMenuItem<String?>(child: Text(l10n.purchaseBillNoOrder)),
        for (final o in orders)
          DropdownMenuItem<String?>(
            value: o.id,
            child: Text('${o.reference} · ${o.supplierName}'),
          ),
      ],
      onChanged: (id) => onChanged(orders.where((o) => o.id == id).firstOrNull),
    );
  }
}
