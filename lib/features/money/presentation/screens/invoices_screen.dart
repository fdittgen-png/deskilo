// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show watchWorkspaceIsEu;
import '../invoicing/invoicing_home_screen.dart';
import '../my_finances_route.dart';
import '../widgets/dunning_rules_dialog.dart';
import '../widgets/expense_repartition_sheet.dart';
import '../widgets/invoice_archive_tab.dart';
import '../widgets/invoice_process_sheet.dart';
import '../widgets/invoice_template_sheet.dart';
import '../widgets/recapitulative_notice.dart';
import '../widgets/settlement_sheet.dart';
import '../widgets/small_business_notice.dart';
import '../widgets/wizard_context.dart';

/// Invoices are immutable — there is no edit or delete anywhere, by design.
/// Someone who issues lands on the invoicing home (#3587); a member reads
/// their own invoices in the archive. The actions live in
/// invoice_actions.dart.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key, this.customer});

  /// #3610 — the customer the address names (search), opened once.
  final String? customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final countryCode = workspace?.countryCode ?? '';
    final me = ref.watch(myMemberProvider).value;
    final features = ref.watch(enabledFeaturesSyncProvider);
    // #454: warm the template before any render action can be tapped —
    // invoicePdfTemplateFor reads it synchronously.
    ref.watch(invoicePdfTemplateProvider);
    // #513 — the CENTRAL permission decides (owner always passes; the
    // legacy adminInvoicing flag keeps granting inside the matrix
    // defaults). The server re-checks via has_permission.
    final perms = ref.watch(myPermissionsProvider);
    final canIssue =
        me != null && perms.contains(WorkspacePermission.issueInvoices);
    final isEu = watchWorkspaceIsEu(ref, countryCode);
    final showMemberNames =
        (me?.canAdminister ?? false) ||
        perms.contains(WorkspacePermission.viewFinances);
    final more = _moreEntries(context, ref, perms, canIssue: canIssue);

    if (!canIssue) {
      return Scaffold(
        appBar: AppBar(
          title: PageTitle(l10n.myInvoicesTitle),
          actions: [_memberMenu(context, more)],
        ),
        body: Column(
          children: [
            _Banner(text: l10n.memberInvoicesBanner),
            Expanded(
              child: InvoiceArchiveTab(
                canIssue: false,
                showMemberNames: showMemberNames,
                countryCode: countryCode,
                isEu: isEu,
              ),
            ),
          ],
        ),
      );
    }
    final currency =
        workspace?.currencyCode ?? appFormatOf(context).currencyCode;
    final recapitulative = features.contains(
      WorkspaceFeature.recapitulativeStatement,
    );
    final exempt = workspace?.vatRegime == 'exempt';
    return InvoicingHomeScreen(
      openCustomer: customer,
      more: more,
      isEu: isEu,
      showMemberNames: showMemberNames,
      // The legal notices, under one collapsed line (#2354, #2440).
      legalNotes: recapitulative || exempt
          ? [
              RecapitulativeNotice(enabled: recapitulative),
              SmallBusinessNotice(
                exempt: exempt,
                country: countryCode,
                currency: currency,
              ),
            ]
          : null,
    );
  }
}

/// The worded entries of the More menu (#3587's final design, section 4),
/// each where its permission and feature allow it.
List<MoreEntry> _moreEntries(
  BuildContext context,
  WidgetRef ref,
  Set<WorkspacePermission> perms, {
  required bool canIssue,
}) {
  final l10n = context.l10n;
  final features = ref.read(enabledFeaturesSyncProvider);
  // #454: the PDF template editor, behind its feature flag.
  // #2137 — set_invoice_pdf_template asks designDocuments.
  final templateOn =
      perms.contains(WorkspacePermission.designDocuments) &&
      features.contains(WorkspaceFeature.invoicePdfTemplate);
  // Mahnwesen (#472): set_dunning_rules asks manageBilling.
  final dunningOn =
      perms.contains(WorkspacePermission.manageBilling) &&
      features.contains(WorkspaceFeature.dunning);
  // #812 — the process, explained: the same sheet a member opens from
  // their Invoices face.
  final processOn = features.contains(WorkspaceFeature.invoiceJourney);
  // #828 — a shared expense split over the members: reachable only from
  // here, so it stays in the menu.
  final repartitionOn =
      canIssue && features.contains(WorkspaceFeature.expenseRepartition);
  // #804 — regrouping a customer's open invoices into one they pay.
  final settlementOn =
      canIssue && features.contains(WorkspaceFeature.invoiceSettlement);
  final wizardOn =
      canIssue && features.contains(WorkspaceFeature.invoicingWizard);
  // The setup guide when it is on, the workspace settings otherwise.
  final setupOn =
      canIssue &&
      perms.contains(WorkspacePermission.manageConfiguration) &&
      features.contains(WorkspaceFeature.setupGuide);
  final settingsOn =
      canIssue &&
      (setupOn || perms.contains(WorkspacePermission.workspaceSettings));
  return [
    (
      'invoicing-personal-action',
      Icons.account_balance_wallet_outlined,
      l10n.invoicingMoreMine,
      () => context.push(myFinancesRoute()),
    ),
    if (dunningOn)
      (
        'invoice-dunning-settings',
        Icons.rule_outlined,
        l10n.dunningSettingsTitle,
        () => showDunningRulesDialog(context, ref),
      ),
    if (settingsOn)
      (
        'invoicing-setup-guide',
        Icons.settings_outlined,
        l10n.invoicingMoreSettings,
        () => context.push(setupOn ? '/setup' : '/workspace-settings'),
      ),
    (
      'invoice-register-button',
      Icons.table_rows_outlined,
      l10n.invoicingMoreRegister,
      () => context.push('/invoice-register'),
    ),
    if (templateOn)
      (
        'invoice-template-button',
        Icons.edit_note_outlined,
        l10n.invoicingMoreTemplate,
        () => showInvoiceTemplateSheet(context, ref),
      ),
    if (settlementOn)
      (
        'invoice-settlement',
        Icons.merge_outlined,
        l10n.invoicingMoreRegroup,
        () => showSettlementSheet(context, ref),
      ),
    if (repartitionOn)
      (
        'invoice-distribute-button',
        Icons.call_split,
        l10n.repartitionAction,
        () => showExpenseRepartitionSheet(context, ref),
      ),
    // #827 — the month-close wizard: its card sat on the old month list,
    // so it keeps a door here.
    if (wizardOn)
      (
        'invoice-wizard-card',
        Icons.auto_fix_high_outlined,
        l10n.invoiceWizardAction,
        () => openInvoicingWizard(context),
      ),
    if (processOn)
      (
        'invoice-process-help',
        Icons.help_outline,
        l10n.invoicingMoreHow,
        () => showInvoiceProcessSheet(context),
      ),
  ];
}

/// A member's menu: the same worded entries their permissions allow.
Widget _memberMenu(BuildContext context, List<MoreEntry> entries) =>
    PopupMenuButton<int>(
      key: const ValueKey('invoicing-tools'),
      tooltip: context.l10n.invoicingTools,
      onSelected: (i) => entries[i].$4(),
      itemBuilder: (_) => [
        for (final (i, e) in entries.indexed)
          PopupMenuItem<int>(
            key: ValueKey(e.$1),
            value: i,
            child: Row(
              children: [
                Icon(e.$2, size: 20),
                const SizedBox(width: 12),
                Flexible(child: Text(e.$3)),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        // The worded button is a whole target, not just its words.
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(MaterialLocalizations.of(context).moreButtonTooltip),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
      ),
    );

/// Says which of the two money jobs this screen is, and where the other
/// one lives: a member must never confuse their invoices with invoicing.
class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // At large accessibility text the banner would eat the list: the same
    // link stays one tap away in the menu.
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Card(
        key: const ValueKey('invoicing-banner'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('invoicing-my-finances'),
                  onPressed: () => context.push(myFinancesRoute()),
                  child: Text(l10n.tabMoney),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
