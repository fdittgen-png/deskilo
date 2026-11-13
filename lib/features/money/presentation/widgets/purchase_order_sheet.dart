// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the purchase order form, opened from the orders screen.
// #3608 — it is a long task: an order with its lines does not fit a side
// panel, so it opens as a page of its own with an address
// (`/money/purchase-orders/new`, `/money/purchase-orders/<id>/edit`), the
// form in its column and the order's totals beside it
// (purchase_order_page.dart). The fields and their checks are the form's
// (purchase_order_form.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/adaptive/long_task_page.dart';

/// Opens the purchase order form.
class PurchaseOrderSheet {
  const PurchaseOrderSheet(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// The address of the page that edits [orderId], or starts a new order.
  static String addressOf(String? orderId) => orderId == null
      ? '/money/purchase-orders/new'
      : '/money/purchase-orders/${Uri.encodeComponent(orderId)}/edit';

  /// Opens the form for a new order, or for the draft [order]. True once
  /// the server has it.
  Future<bool> open({required String workspaceId, String? orderId}) async =>
      await showLongTask<bool>(context, address: addressOf(orderId)) ?? false;
}
