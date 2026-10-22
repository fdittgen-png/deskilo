// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C2 — one way in for everything bought: "Add purchase / expense"
// asks only who paid, then opens the form that already exists for that
// answer, so there is one validator per kind and nothing new to learn.
//
//   * I paid personally — the member's expense (it is owed to them once
//     approved); offered to everyone, an owner included.
//   * Not paid yet — a supplier bill the space still owes.
//   * The space already paid — the same bill: the server sends only an
//     unpaid bill to approval, so its payment is recorded from To pay once
//     it is approved, never assumed.
//
// The two bill answers need purchases on and managePurchases; without
// them the button goes straight to the person's own expense.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_sheet.dart';
import 'expense_sheet.dart';
import 'purchase_dialogs.dart';

/// Who paid what is being entered.
enum PurchasePayer { me, unpaid, space }

class AddPurchaseButton extends ConsumerWidget {
  const AddPurchaseButton({
    super.key,
    required this.currency,
    required this.workspaceId,
    required this.bills,
  });

  final MoneyFormat currency;
  final String? workspaceId;

  /// Whether the person may capture supplier bills (purchases on and
  /// managePurchases): the caller knows the gates.
  final bool bills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = workspaceId;
    Future<void> open() async {
      final payer = bills
          ? await showAppSheet<PurchasePayer>(
              context: context,
              builder: (_) => const _WhoPaid(),
            )
          : PurchasePayer.me;
      if (payer == null || !context.mounted) return;
      switch (payer) {
        case PurchasePayer.me:
          await showExpenseSheet(context, ref, currency);
        case PurchasePayer.unpaid || PurchasePayer.space:
          if (workspace == null) return;
          await showPurchaseBillDialog(context, workspace);
      }
    }

    return FilledButton.icon(
      key: const ValueKey('add-purchase'),
      onPressed: open,
      icon: const Icon(Icons.add_shopping_cart_outlined),
      label: Text(l10n.purchaseEntryAdd),
    );
  }
}

class _WhoPaid extends StatelessWidget {
  const _WhoPaid();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget answer(PurchasePayer payer, IconData icon, String t, String s) =>
        ListTile(
          key: ValueKey('add-purchase-${payer.name}'),
          leading: Icon(icon),
          title: Text(t),
          subtitle: Text(s),
          onTap: () => Navigator.of(context).pop(payer),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              l10n.purchaseEntryWhoPaid,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          answer(
            PurchasePayer.me,
            Icons.person_outline,
            l10n.purchaseEntryMe,
            l10n.purchaseEntryMeHint,
          ),
          answer(
            PurchasePayer.unpaid,
            Icons.receipt_long_outlined,
            l10n.purchaseEntryUnpaid,
            l10n.purchaseEntryUnpaidHint,
          ),
          answer(
            PurchasePayer.space,
            Icons.account_balance_outlined,
            l10n.purchaseEntryPaid,
            l10n.purchaseEntryPaidHint,
          ),
        ],
      ),
    );
  }
}
