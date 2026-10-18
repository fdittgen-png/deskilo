// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/premises_lease.dart' show leaseManagePermission;
import '../../domain/purchase.dart' show
        purchaseDecidePermission,
        purchaseManagePermission,
        purchaseOffsetPermission,
        purchasePayPermission;
import '../widgets/consumption_sheet.dart';
import '../widgets/equipment_sheet.dart';
import '../widgets/expense_schedule_sheet.dart';
import '../widgets/expense_sheet.dart';
import '../widgets/money_faces_view.dart';
import '../widgets/premises_lease_sheet.dart';
import '../widgets/purchases_sheet.dart';
import '../widgets/suppliers_sheet.dart';
import 'money_screen_ops.dart';
import 'money_view_data.dart';

/// The buttons of the Money tab, each built once and placed by whichever
/// layout is on (#720): classic column, landscape side panel or the faces.
/// Grouped by MEANING — what pays, what asks, what documents (#486 UX).
class MoneyActionSet {
  MoneyActionSet._({
    required this.recordPayment,
    required this.buyPackage,
    required this.requestButtons,
    required this.invoices,
    required this.status,
    required this.wizard,
  });

  /// Reads the member, the enabled features and the sheets' wiring of
  /// [context] once and builds every button.
  factory MoneyActionSet.build(
    BuildContext context,
    WidgetRef ref, {
    required MoneyScreenOps ops,
    required MoneyViewData data,
  }) {
    final l10n = context.l10n;
    final currency = data.currency;
    return MoneyActionSet._(
      recordPayment: FilledButton.icon(
        key: const ValueKey('money-record-payment'),
        onPressed: () => ops.sheets.recordPayment(currency),
        icon: const Icon(Icons.payments_outlined),
        label: Text(l10n.moneyRecordPayment),
      ),
      buyPackage: data.onPackagePlan ? _buyPackage(l10n, ops, currency) : null,
      requestButtons: _requestButtons(context, ref, l10n, ops, data),
      invoices: _managementTile(
        on: data.invoicingOn,
        key: 'invoices-button',
        icon: Icons.receipt_long_outlined,
        title: l10n.invoicesManage,
        subtitle: l10n.uxNavFinance,
        onTap: () => context.push('/invoices'),
      ),
      status: _managementTile(
        on: data.statusToolOn,
        key: 'workspace-status-button',
        icon: Icons.account_balance_outlined,
        title: l10n.statusTitle,
        subtitle: l10n.statusSubtitle,
        onTap: () => context.push('/money/status'),
      ),
      wizard: _managementTile(
        on: data.repartitionWizardOn,
        key: 'repartition-wizard-button',
        icon: Icons.pie_chart_outline,
        title: l10n.repartitionWizardTitle,
        subtitle: l10n.repartitionWizardSubtitle,
        onTap: () => context.push('/money/repartition-wizard'),
      ),
    );
  }

  final Widget recordPayment;

  /// Only for members the owner put on the package plan (0042) — it PAYS,
  /// so it lives with the payment.
  final Widget? buyPackage;

  /// What asks: expense, scheduled expenses, quota, consumption.
  final List<Widget> requestButtons;

  /// #871 — the hand-off to invoice MANAGEMENT reads like every other
  /// management access in the app (the Settings tiles): a row with the
  /// management icon, a verb, and a chevron — never a button that repeats
  /// the name of the tab the person is already on.
  final Widget? invoices;

  /// #934 — the treasurer's view, for those who manage the money.
  final Widget? status;

  /// #934 — the guided repartition, for those who manage the money.
  final Widget? wizard;

  bool get hasWorkspaceTools =>
      invoices != null || status != null || wizard != null;

  static Widget _buyPackage(
    AppLocalizations l10n,
    MoneyScreenOps ops,
    MoneyFormat currency,
  ) =>
      FilledButton.tonalIcon(
        key: const ValueKey('buy-package-button'),
        onPressed: () => ops.sheets.buyPackage(currency),
        icon: const Icon(Icons.shopping_bag_outlined),
        label: Text(l10n.buyPackageButton),
      );

  static List<Widget> _requestButtons(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    MoneyScreenOps ops,
    MoneyViewData data,
  ) {
    final currency = data.currency;
    Widget fitted(String text) => fittedLabel(text);
    return [
      OutlinedButton.icon(
        key: const ValueKey('money-submit-expense'),
        onPressed: () => showExpenseSheet(context, ref, currency),
        icon: const Icon(Icons.receipt_long_outlined),
        label: fitted(l10n.moneySubmitExpense),
      ),
      // #767 — recurring expenses: the schedule list/create door, and the
      // occurrences presented for confirmation (cards below).
      if (data.scheduledExpensesOn)
        OutlinedButton.icon(
          key: const ValueKey('scheduled-expenses-button'),
          onPressed: () => showExpenseSchedulesSheet(context, ref, currency),
          icon: const Icon(Icons.event_repeat_outlined),
          label: fitted(l10n.scheduledExpensesTitle),
        ),
      // #2567 — the payees of the purchase side, for those who manage the
      // money.
      if (data.suppliersOn && data.workspace != null)
        OutlinedButton.icon(
          key: const ValueKey('suppliers-button'),
          onPressed: () => showSuppliersSheet(context, data.workspace!.id),
          icon: const Icon(Icons.storefront_outlined),
          label: fitted(l10n.suppliersTitle),
        ),
      // #2573 — one document per purchase: the member's receipts and the
      // supplier bills.
      if (data.purchasesOn && data.workspace != null)
        OutlinedButton.icon(
          key: const ValueKey('purchases-button'),
          onPressed: () => showPurchasesSheet(
            context,
            data.workspace!.id,
            canCapture: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == purchaseManagePermission),
            canPay: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == purchasePayPermission),
            canDecide: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == purchaseDecidePermission),
            canOffset: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == purchaseOffsetPermission),
          ),
          icon: const Icon(Icons.shopping_cart_outlined),
          label: fitted(l10n.purchasesTitle),
        ),
      // #2569 — the lease the space holds as tenant, with its rent terms.
      if (data.premisesLeaseOn && data.workspace != null)
        OutlinedButton.icon(
          key: const ValueKey('premises-lease-button'),
          onPressed: () => showPremisesLeaseSheet(
            context,
            data.workspace!.id,
            currencyCode: data.currencyCode,
            canManage: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == leaseManagePermission),
            canMatch: ref
                .read(myPermissionsProvider)
                .any((p) => p.wireName == purchaseManagePermission),
          ),
          icon: const Icon(Icons.apartment_outlined),
          label: fitted(l10n.leaseTitle),
        ),
      // #2576 — the equipment the space bought, and the treatment of each piece.
      if (data.assetRegisterOn && data.workspace != null)
        EquipmentButton(
          workspaceId: data.workspace!.id,
          held: {for (final p in ref.read(myPermissionsProvider)) p.wireName},
        ),
      OutlinedButton.icon(
        key: const ValueKey('quota-request-button'),
        onPressed: () => ops.sheets.requestQuota(ops.period),
        icon: const Icon(Icons.hourglass_top_outlined),
        label: fitted(l10n.quotaRequestButton),
      ),
      // Consumption follows the services feature (#146).
      if (data.servicesOn)
        OutlinedButton.icon(
          key: const ValueKey('money-consumption-add'),
          onPressed: () {
            final me = ref.read(myMemberProvider).value;
            if (me == null) return;
            unawaited(
                showConsumptionSheet(context, ref, subjectMemberId: me.id));
          },
          icon: const Icon(Icons.room_service_outlined),
          label: fitted(l10n.consumptionAdd),
        ),
    ];
  }

  static Widget? _managementTile({
    required bool on,
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      on
          ? ListTile(
              key: ValueKey(key),
              contentPadding: EdgeInsets.zero,
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              // Not chevron_right: the period bar owns that icon here.
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: onTap,
            )
          : null;
}
