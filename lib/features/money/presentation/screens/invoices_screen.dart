// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_ubl.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../widgets/dunning_rules_dialog.dart';
import '../widgets/settlement_sheet.dart';
import '../widgets/invoice_template_sheet.dart';
import '../widgets/invoice_archive_tab.dart';
import '../widgets/invoice_detail_sheet.dart';
import '../widgets/invoice_form_sheet.dart';
import '../widgets/invoicing_dashboard.dart';
import '../widgets/invoice_journey_view.dart';
import '../widgets/invoice_process_sheet.dart';
import '../widgets/invoice_stage_strip.dart';

/// The invoicing HUB (field request: "the user sees what to invoice, what
/// to remind, what has been invoiced") — three tabs over one archive:
/// TO INVOICE (last month's uninvoiced members), OPEN (issued, unpaid) and
/// ARCHIVE (closed: paid or erroneous). Members get the plain archive.
///
/// Invoices are immutable — there is no edit or delete anywhere, by design.
/// This screen only wires the pieces together: the rows live in
/// [InvoiceArchiveTab] / [ToInvoiceTab] / [OpenInvoicesTab], the actions in
/// invoice_actions.dart.
class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final countryCode = workspace?.countryCode ?? '';
    // 2014/55/EU: the e-invoice affordance shows for EU workspaces.
    final isEu = isEuCountry(countryCode);
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
    final showMemberNames = me?.canAdminister ?? false;
    final currency = moneyFormat(workspace?.currencyCode ?? 'EUR');

    final archive = InvoiceArchiveTab(
      canIssue: canIssue,
      showMemberNames: showMemberNames,
      countryCode: countryCode,
      isEu: isEu,
    );

    // The register reads the same archive as a dated ledger — one tap
    // from either surface.
    final registerAction = IconButton(
      key: const ValueKey('invoice-register-button'),
      tooltip: l10n?.invoiceRegisterTitle ?? 'Invoice register',
      icon: const Icon(Icons.table_rows_outlined),
      onPressed: () => context.push('/invoice-register'),
    );
    // #454: the PDF template editor — owner only (workspaces_update RLS
    // would refuse anyone else anyway), behind its feature flag.
    final templateAction = (me?.actsAsOwner ?? false) &&
            features.contains(WorkspaceFeature.invoicePdfTemplate)
        ? IconButton(
            key: const ValueKey('invoice-template-button'),
            tooltip: l10n?.invoiceTemplateTitle ?? 'Invoice PDF template',
            icon: const Icon(Icons.edit_note_outlined),
            onPressed: () => showInvoiceTemplateSheet(context, ref),
          )
        : null;
    // Mahnwesen (#472): the dunning policy — owner only.
    final dunningAction = ((me?.actsAsOwner ?? false) &&
            features.contains(WorkspaceFeature.dunning))
        ? IconButton(
            key: const ValueKey('invoice-dunning-settings'),
            tooltip: l10n?.dunningSettingsTitle ?? 'Reminder rules',
            icon: const Icon(Icons.rule_outlined),
            onPressed: () => showDunningRulesDialog(context, ref),
          )
        : null;

    // #812 — the process, explained: the same sheet a member opens from
    // their Invoices face.
    final journeyOn = features.contains(WorkspaceFeature.invoiceJourney);
    final processAction = journeyOn
        ? IconButton(
            key: const ValueKey('invoice-process-help'),
            tooltip: l10n?.journeyHowTitle ?? 'How invoicing works',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showInvoiceProcessSheet(context),
          )
        : null;

    // #804 — regrouping a member's open invoices into one they pay.
    final settlementAction =
        (canIssue && features.contains(WorkspaceFeature.invoiceSettlement))
            ? IconButton(
                key: const ValueKey('invoice-settlement'),
                tooltip: l10n?.settlementAction ?? 'Regroup into one invoice',
                icon: const Icon(Icons.merge_outlined),
                onPressed: () => showSettlementSheet(context, ref),
              )
            : null;

    if (!canIssue) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.invoicesTitle ?? 'Invoices'),
          actions: [
            ?templateAction,
            ?dunningAction,
            registerAction,
            ?processAction,
          ],
        ),
        body: archive,
      );
    }

    // The month as a proforma: derived on the spot for a member who has
    // no invoice yet, or re-rendered from the issued one.
    Future<void> proformaForEntry(String memberId, String period) async {
      final invoice = await proformaForMonth(
        ref,
        memberId: memberId,
        period: period,
      );
      if (!context.mounted) return;
      if (invoice == null) {
        AppSnack.info(
          context,
          l10n?.invoiceProformaNothing ??
              'Nothing tracked for this month — no proforma to send.',
        );
        return;
      }
      await shareProforma(context, ref, invoice);
    }

    Future<void> openDetail(OpenInvoiceEntry entry) async {
      final reminders =
          ref.read(invoiceRemindersProvider).value ?? const {};
      final action = await showInvoiceDetailSheet(
        context,
        invoice: entry.invoice,
        match: entry.pendingMatch,
        canIssue: true,
        isEu: isEu,
        reminder: reminders[entry.invoice.id],
        showMemberName: showMemberNames,
        transmission:
            ref.read(invoiceTransmissionsProvider).value?[entry.invoice.id],
        journey: readInvoiceJourney(
          ref,
          entry.invoice,
          match: entry.pendingMatch,
          reminder: reminders[entry.invoice.id],
        ),
      );
      if (action == null || !context.mounted) return;
      await runInvoiceAction(
        context,
        ref,
        action,
        entry.invoice,
        countryCode: countryCode,
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n?.invoicesTitle ?? 'Invoices'),
          actions: [
            ?templateAction,
            ?settlementAction,
            ?dunningAction,
            registerAction,
            ?processAction,
          ],
          bottom: TabBar(tabs: [
            Tab(
              key: const ValueKey('invoice-tab-todo'),
              text: l10n?.invoiceTabToInvoice ?? 'To invoice',
            ),
            Tab(
              key: const ValueKey('invoice-tab-open'),
              text: l10n?.invoiceTabOpen ?? 'Open',
            ),
            Tab(
              key: const ValueKey('invoice-tab-archive'),
              text: l10n?.invoiceTabArchive ?? 'Archive',
            ),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('invoice-create-button'),
          onPressed: () => showInvoiceIssueSheet(context, ref),
          icon: const Icon(Icons.receipt_long_outlined),
          label: Text(l10n?.invoiceCreate ?? 'New invoice'),
        ),
        body: Column(children: [
          if (journeyOn)
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
            child: TabBarView(children: [
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
                onProforma: proformaForEntry,
              ),
              OpenInvoicesTab(
                currency: currency,
                onOpen: openDetail,
                onRemind: (entry) =>
                    remindInvoice(context, ref, entry.invoice),
                onMatch: (entry) =>
                    matchInvoiceToPayment(context, ref, entry.invoice),
                onWriteoff: (entry) =>
                    requestInvoiceWriteoffDialog(context, ref, entry.invoice),
                onRefund: (entry) =>
                    settleCreditInvoiceDialog(context, ref, entry.invoice),
                onVoid: (entry) =>
                    voidInvoiceWithConfirm(context, ref, entry.invoice),
                onProforma: (entry) =>
                    shareProforma(context, ref, entry.invoice),
                onEvents: (_) => context.go('/events'),
              ),
              archive,
            ]),
          ),
        ]),
      ),
    );
  }
}
