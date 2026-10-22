// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2573 -- from the decision on an expense request to the purchase document
// it was filed as (the bridge of 0461 files every expense event as a member
// receipt): the events page asks core for an opener, money supplies it.
import 'package:flutter/widgets.dart';

import '../../../core/navigation/event_sources.dart';
import '../domain/purchase.dart';
import 'widgets/purchases_sheet.dart';

class PurchaseSourceOpener implements EventSourceOpener {
  const PurchaseSourceOpener(this._purchases);
  final PurchaseRepository _purchases;

  @override
  Future<bool> open(
    BuildContext context,
    String workspaceId,
    String eventId,
  ) async {
    final purchaseId = await _purchases.purchaseFiledFrom(
      workspaceId,
      sourceKind: 'expense_event',
      sourceId: eventId,
    );
    if (purchaseId == null || !context.mounted) return false;
    await showPurchaseDetail(context, workspaceId, purchaseId);
    return true;
  }
}
