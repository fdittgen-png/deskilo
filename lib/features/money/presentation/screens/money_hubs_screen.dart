// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C1 — what the space buys, on a page of its own: the purchase side
// (a member's own expense, the documents to review, suppliers, the lease,
// equipment, rented rooms, the books' periods). The sales side is the Sales
// group of the menu since #3614. It opens the EXISTING sheets and screens
// with the gates the Money tab uses; nothing here decides money, and a door
// the person may not use is absent.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/page_title.dart';
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
      appBar: AppBar(
        title: PageTitle(l10n.hubPurchasesTitle),
        actions: [
          HelpDot(l10n.hubPurchasesTitle, anchor: HelpAnchor.moneyPurchases),
        ],
      ),
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

/// `/money/cash` — recorded money in and out, and what is still to pay;
/// never a bank balance (matching a statement is #2380's).
class CashHubScreen extends ConsumerWidget {
  const CashHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doors = MoneyActionSet.cashDoors(
      context,
      ref,
      MoneyViewData.gates(ref),
    );
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.hubCashTitle),
        actions: [HelpDot(l10n.hubCashTitle, anchor: HelpAnchor.moneyCash)],
      ),
      body: ListView(
        key: const ValueKey('cash-hub'),
        padding: AppSpacing.mdAll,
        children: [
          Text(
            l10n.biCashNotBankBalance,
            key: const ValueKey('cash-hub-recorded'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...doors,
        ],
      ),
    );
  }
}

/// `/money/accounting` — everything the books and the tax need, in one
/// place: the export and import of the books, the accounting systems, the
/// bank statements, the periods, the VAT and the legal identity. Each door
/// opens the screen or sheet it always opened, with its own gate.
class AccountingHubScreen extends ConsumerWidget {
  const AccountingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doors = MoneyActionSet.accountingDoors(
      context,
      ref,
      MoneyViewData.gates(ref),
    );
    return Scaffold(
      appBar: AppBar(title: PageTitle(context.l10n.hubAccountingTitle)),
      body: ListView(
        key: const ValueKey('accounting-hub'),
        padding: AppSpacing.mdAll,
        children: [
          Text(
            context.l10n.hubAccountingSubtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final door in doors) ...[
            door,
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
