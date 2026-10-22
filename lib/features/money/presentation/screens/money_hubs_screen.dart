// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C1 — what the space buys and what it sells, each on a page of its
// own: the purchase side (a member's own expense, the documents to review,
// suppliers, the lease, equipment, rented rooms, the books' periods) and the
// sales side (services and prices, invoices, the register, billing). Both
// open the EXISTING sheets and screens with the gates the Money tab uses;
// nothing here decides money, and a door the person may not use is absent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/add_purchase_button.dart';
import 'money_action_set.dart';
import 'money_view_data.dart';

/// `/money/purchases` — the purchase side, for the person's own expenses
/// and, for those who manage them, the space's.
class PurchasesHubScreen extends ConsumerWidget {
  const PurchasesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = MoneyViewData.gates(ref);
    final doors = MoneyActionSet.purchaseDoors(context, ref, data);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.hubPurchasesTitle)),
      body: ListView(
        key: const ValueKey('purchases-hub'),
        padding: AppSpacing.mdAll,
        children: [
          // A member's own outlay, whatever else they may manage.
          // #2577 C2 — one way in: who paid decides the form.
          AddPurchaseButton(
            key: const ValueKey('purchases-hub-own-expense'),
            currency: data.currency,
            workspaceId: data.workspace?.id,
            bills: MoneyActionSet.canCaptureBills(ref, data),
          ),
          for (final door in doors) ...[
            const SizedBox(height: AppSpacing.sm),
            door,
          ],
        ],
      ),
    );
  }
}

/// `/money/sales` — what the space sells and invoices, for those who
/// manage it.
class SalesHubScreen extends ConsumerWidget {
  const SalesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doors = MoneyActionSet.salesDoors(
      context,
      ref,
      MoneyViewData.gates(ref),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.hubSalesTitle)),
      body: ListView(
        key: const ValueKey('sales-hub'),
        padding: AppSpacing.mdAll,
        children: doors,
      ),
    );
  }
}
