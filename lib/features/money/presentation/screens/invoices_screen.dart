// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/settings/setting_defaults.g.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/app_tab_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_ubl.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_proforma.dart';
import '../invoice_status.dart';
import '../my_finances_route.dart';
import '../widgets/dunning_rules_dialog.dart';
import '../widgets/expense_repartition_sheet.dart';
import '../widgets/invoice_archive_tab.dart';
import '../widgets/invoice_detail_sheet.dart';
import '../widgets/invoice_form_sheet.dart';
import '../widgets/invoice_journey_view.dart';
import '../widgets/invoice_process_sheet.dart';
import '../widgets/invoice_stage_strip.dart';
import '../widgets/invoice_template_sheet.dart';
import '../widgets/invoicing_dashboard.dart';
import '../widgets/recapitulative_notice.dart';
import '../widgets/settlement_sheet.dart';
import '../widgets/small_business_notice.dart';

/// The invoicing HUB (field request: "the user sees what to invoice, what
/// to remind, what has been invoiced") — three tabs over one archive:
/// TO INVOICE (last month's uninvoiced members), OPEN (issued, unpaid) and
/// ARCHIVE (closed: paid or erroneous). Members get the plain archive.
///
/// Invoices are immutable — there is no edit or delete anywhere, by design.
/// This screen only wires the pieces together: the rows live in
/// [InvoiceArchiveTab] / [ToInvoiceTab] / [OpenInvoicesTab], the actions in
/// invoice_actions.dart.
/// #3072 — the room under the lists for the extended floating button (its
/// height plus the margin the scaffold gives it).
const double _fabClearance = 88;

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

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
    final canIssue = me != null &&
        ref
            .watch(myPermissionsProvider)
            .contains(WorkspacePermission.issueInvoices);
    final perms = ref.watch(myPermissionsProvider);
    final facts = (
      countryCode: countryCode,
      currencyCode: workspace?.currencyCode ?? SettingDefaults.localeDefaultCurrency,
      vatExempt: workspace?.vatRegime == 'exempt',
      // 2014/55/EU: the e-invoice affordance shows for EU workspaces.
      isEu: isEuCountry(countryCode),
      showMemberNames: (me?.canAdminister ?? false) ||
          perms.contains(WorkspacePermission.viewFinances),
      features: features,
    );

    final archive = InvoiceArchiveTab(
      canIssue: canIssue,
      showMemberNames: facts.showMemberNames,
      countryCode: countryCode,
      isEu: facts.isEu,
    );
    final tools = _toolsMenu(
        l10n, _toolItems(context, ref, perms, canIssue: canIssue));

    if (!canIssue) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.myInvoicesTitle),
          actions: [tools],
        ),
        body: Column(children: [
          _Banner(
            text: l10n.memberInvoicesBanner,
          ),
          Expanded(child: archive),
        ]),
      );
    }
    return _hub(context, ref, facts, tools: tools, archive: archive);
  }

  /// The month as a proforma: derived on the spot for a member who has no
  /// invoice yet, or re-rendered from the issued one.
  Future<void> _proformaForEntry(BuildContext context, WidgetRef ref,
      String memberId, String period) async {
    final invoice = await proformaForMonth(
      ref,
      memberId: memberId,
      period: period,
    );
    if (!context.mounted) return;
    if (invoice == null) {
      AppSnack.info(
        context,
        context.l10n.invoiceProformaNothing,
      );
      return;
    }
    await shareProforma(context, ref, invoice);
  }

  Future<void> _openDetail(BuildContext context, WidgetRef ref,
      OpenInvoiceEntry entry, _HubFacts facts) async {
    final reminders = ref.read(invoiceRemindersProvider).value ?? const {};
    await showInvoiceDetailSheet(
      context,
      ref: ref,
      invoice: entry.invoice,
      match: entry.pendingMatch,
      settledByNumber: settledByNumberOf(
          entry.invoice, ref.read(invoicesProvider).value ?? const []),
      canIssue: true,
      isEu: facts.isEu,
      reminder: reminders[entry.invoice.id],
      showMemberName: facts.showMemberNames,
      transmission:
          ref.read(invoiceTransmissionsProvider).value?[entry.invoice.id],
      journey: readInvoiceJourney(
        ref,
        entry.invoice,
        match: entry.pendingMatch,
        reminder: reminders[entry.invoice.id],
      ),
    );
  }

  /// The invoicing hub of someone who issues: to invoice, open, archive.
  Widget _hub(BuildContext context, WidgetRef ref, _HubFacts facts,
      {required Widget tools, required Widget archive}) {
    final l10n = context.l10n;
    final currency = moneyFormat(facts.currencyCode);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.invoicingHubTitle),
          actions: [tools],
          bottom: AppTabBar.bottom(context, tabs: [
            AppTab(l10n.invoiceTabToInvoice,
                key: const ValueKey('invoice-tab-todo')),
            AppTab(l10n.invoiceTabOpen,
                key: const ValueKey('invoice-tab-open')),
            AppTab(l10n.invoiceTabArchive,
                key: const ValueKey('invoice-tab-archive')),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('invoice-create-button'),
          onPressed: () => showInvoiceIssueSheet(context, ref),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n.invoiceCreate),
        ),
        body: Column(children: [
          _Banner(
            text: l10n.invoicingBanner,
          ),
          RecapitulativeNotice(
              enabled: facts.features
                  .contains(WorkspaceFeature.recapitulativeStatement)), // #2354
          SmallBusinessNotice(
            // #2440
            exempt: facts.vatExempt,
            country: facts.countryCode,
            currency: facts.currencyCode,
          ),
          if (facts.features.contains(WorkspaceFeature.invoiceJourney))
            Builder(
              builder: (context) => InvoiceStageStrip(
                currency: currency,
                onStage: (tab) =>
                    DefaultTabController.of(context).animateTo(tab),
              ),
            )
          else
            InvoicingSummaryBar(currency: currency),
          Expanded(
            // #3072 — room under the lists for the floating button, so it
            // never covers the action of the last row.
            child: Padding(
              padding: const EdgeInsets.only(bottom: _fabClearance),
              child: TabBarView(children: [
                _toInvoiceTab(context, ref, currency),
                _openTab(context, ref, currency, facts),
                archive,
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _toInvoiceTab(
          BuildContext context, WidgetRef ref, MoneyFormat currency) =>
      ToInvoiceTab(
        currency: currency,
        onIssue: (memberId, period) => showInvoiceIssueSheet(
          context,
          ref,
          memberId: memberId,
          period: period,
        ),
        onIssueAll: (entries, period) => issueInvoicesForAll(
          context,
          ref,
          entries,
          period,
          currency,
        ),
        onProforma: (memberId, period) =>
            _proformaForEntry(context, ref, memberId, period),
      );

  Widget _openTab(BuildContext context, WidgetRef ref, MoneyFormat currency,
          _HubFacts facts) =>
      OpenInvoicesTab(
        currency: currency,
        onOpen: (entry) => _openDetail(context, ref, entry, facts),
        onRemind: (entry) => remindInvoice(context, ref, entry.invoice),
        onMatch: (entry) => matchInvoiceToPayment(context, ref, entry.invoice),
        onWriteoff: (entry) =>
            requestInvoiceWriteoffDialog(context, ref, entry.invoice),
        onRefund: (entry) =>
            settleCreditInvoiceDialog(context, ref, entry.invoice),
        onVoid: (entry) => voidInvoiceWithConfirm(context, ref, entry.invoice),
        onProforma: (entry) => shareProforma(context, ref, entry.invoice),
        onEvents: (_) => context.go('/events'),
      );
}

/// What the screen shows, read once from the workspace, the member and the
/// enabled features.
typedef _HubFacts = ({
  String countryCode,
  String currencyCode,
  bool vatExempt,
  bool isEu,
  bool showMemberNames,
  Set<WorkspaceFeature> features,
});

/// One entry of the tools menu: its key, icon, label and action.
typedef _ToolItem = (String, IconData, String, VoidCallback);

/// One labelled menu instead of six unlabelled icons: every tool names
/// itself, and each keeps its key.
List<_ToolItem> _toolItems(
  BuildContext context,
  WidgetRef ref,
  Set<WorkspacePermission> perms, {
  required bool canIssue,
}) {
  final l10n = context.l10n;
  final features = ref.read(enabledFeaturesSyncProvider);
  // #454: the PDF template editor — owner only (workspaces_update RLS
  // would refuse anyone else anyway), behind its feature flag.
  // #2137 — set_invoice_pdf_template asks designDocuments.
  final templateOn = perms.contains(WorkspacePermission.designDocuments) &&
      features.contains(WorkspaceFeature.invoicePdfTemplate);
  // Mahnwesen (#472): the dunning policy — owner only.
  // #2137 — set_dunning_rules asks manageBilling.
  final dunningOn = perms.contains(WorkspacePermission.manageBilling) &&
      features.contains(WorkspaceFeature.dunning);
  // #812 — the process, explained: the same sheet a member opens from
  // their Invoices face.
  final processOn = features.contains(WorkspaceFeature.invoiceJourney);
  // #828 — a shared expense split over the members.
  final repartitionOn =
      canIssue && features.contains(WorkspaceFeature.expenseRepartition);
  // #804 — regrouping a member's open invoices into one they pay.
  final settlementOn =
      canIssue && features.contains(WorkspaceFeature.invoiceSettlement);
  return [
    (
      'invoicing-my-finances-tool',
      Icons.account_balance_wallet_outlined,
      l10n.invoicingMyFinances,
      () => context.push(myFinancesRoute(
        workspaceId: ref.read(activeWorkspaceIdProvider).value)),
    ),
    if (repartitionOn)
      (
        'invoice-distribute-button',
        Icons.call_split,
        l10n.repartitionAction,
        () => showExpenseRepartitionSheet(context, ref),
      ),
    if (settlementOn)
      (
        'invoice-settlement',
        Icons.merge_outlined,
        l10n.settlementAction,
        () => showSettlementSheet(context, ref),
      ),
    (
      'invoice-register-button',
      Icons.table_rows_outlined,
      l10n.invoiceRegisterTitle,
      () => context.push('/invoice-register'),
    ),
    if (dunningOn)
      (
        'invoice-dunning-settings',
        Icons.rule_outlined,
        l10n.dunningSettingsTitle,
        () => showDunningRulesDialog(context, ref),
      ),
    if (templateOn)
      (
        'invoice-template-button',
        Icons.edit_note_outlined,
        l10n.invoiceTemplateTitle,
        () => showInvoiceTemplateSheet(context, ref),
      ),
    if (processOn)
      (
        'invoice-process-help',
        Icons.help_outline,
        l10n.journeyHowTitle,
        () => showInvoiceProcessSheet(context),
      ),
  ];
}

Widget _toolsMenu(AppLocalizations l10n, List<_ToolItem> toolItems) =>
    PopupMenuButton<int>(
      key: const ValueKey('invoicing-tools'),
      tooltip: l10n.invoicingTools,
      icon: const Icon(Icons.tune),
      onSelected: (i) => toolItems[i].$4(),
      itemBuilder: (_) => [
        for (final (i, t) in toolItems.indexed)
          PopupMenuItem<int>(
            key: ValueKey(t.$1),
            value: i,
            child: Row(children: [
              Icon(t.$2, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(t.$3)),
            ]),
          ),
      ],
    );

/// Says which of the two money jobs this screen is, and where the other
/// one lives: an admin must never confuse invoicing with their own invoices.
class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    // At large accessibility text the banner would eat the list: the same
    // link stays one tap away in the tools menu.
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
                    child: Icon(Icons.info_outline,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(text,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const ValueKey('invoicing-my-finances'),
                  onPressed: () => context.push(myFinancesRoute(
          workspaceId: ProviderScope.containerOf(context)
                          .read(activeWorkspaceIdProvider)
                          .value)),
                  child: Text(l10n.invoicingMyFinances),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
