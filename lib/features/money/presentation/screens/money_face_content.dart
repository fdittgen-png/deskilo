// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/expense_schedule.dart';
import '../../domain/money_face.dart';
import '../../providers/expense_schedule_providers.dart';
import '../widgets/account_card.dart';
import '../widgets/bill_view.dart';
import '../widgets/documents_face.dart';
import '../widgets/expense_schedule_sheet.dart';
import '../widgets/invoice_overview.dart';
import '../widgets/money_faces_view.dart';
import '../widgets/my_finances_link_card.dart';
import '../widgets/my_invoices_list.dart';
import '../widgets/negotiation_card.dart';
import '../widgets/usage_face.dart';
import 'money_action_set.dart';
import 'money_screen_ops.dart';
import 'money_view_data.dart';

/// What each face of the Money tab holds (#720): the cards that come from
/// the same [BillView], one face at a time, and the actions placed under
/// them. The classic column uses the same pieces whole.
class MoneyFaceContent {
  MoneyFaceContent(
    this.context,
    this.ref, {
    required this.ops,
    required this.data,
    required this.actions,
  });

  final BuildContext context;
  final WidgetRef ref;
  final MoneyScreenOps ops;
  final MoneyViewData data;
  final MoneyActionSet actions;

  AppLocalizations get _l10n => context.l10n;

  bool get reportsOn => data.memberReportsOn;

  bool get usageReportOn => data.usageReportOn;

  /// #720 — one bill builder: the whole bill (face null) for the classic
  /// column and the PDF, one face at a time for the faces.
  Widget bill(MoneyFace? face) => BillView(
        statement: data.statement!,
        ledger: data.ledger,
        pendingMoneyEvents: data.pendingEvents,
        currencyCode: data.currencyCode,
        memberId: data.member?.id ?? '',
        nowPeriod: ops.nowPeriod,
        // #155 — how-to-pay card on an outstanding balance.
        paymentInstructions: data.paymentInstructions,
        // 0043 — online-payment button, gated by the feature flag.
        onlinePaymentsEnabled:
            data.onlinePaymentsOn,
        onPayOnline: ops.payOnline,
        settlement: data.settlement,
        face: face,
      );

  /// #767 — a due occurrence is PRESENTED, never silently booked: one card
  /// per awaiting/rejected occurrence, on top of the Payments face.
  List<Widget> occurrenceCards() {
    final workspace = data.workspace;
    if (!data.scheduledExpensesOn || workspace == null) return const <Widget>[];
    ref.watch(expenseScheduleSweepProvider(workspace.id));
    final mine = ref.watch(expenseOccurrencesProvider(workspace.id)).value ??
        const <ExpenseOccurrence>[];
    final awaiting = [
      for (final o in mine)
        if (o.status == OccurrenceStatus.awaitingMember ||
            o.status == OccurrenceStatus.rejected)
          o,
    ];
    if (awaiting.isEmpty) return const <Widget>[];
    return <Widget>[
      moneySectionLabel(context, _l10n.scheduledAwaitingTitle),
      for (final o in awaiting) ExpenseOccurrenceCard(o, data.currency),
      const SizedBox(height: 8),
    ];
  }

  /// The classic column's bill side: the account position, the online
  /// attempts and the whole bill.
  List<Widget> billChildren() {
    final account = data.account;
    return [
      if (account != null && account.isNotable) ...[
        AccountCard(account: account, currencyCode: data.currencyCode),
        const SizedBox(height: 8),
      ],
      ...data.attemptsCard,
      if (data.statement != null) bill(null),
    ];
  }

  /// The classic column's actions, grouped by meaning (#486 UX): what pays,
  /// what asks, what documents.
  List<Widget> actionChildren(List<Widget> occurrenceCards) {
    Widget sectionLabel(String text) => moneySectionLabel(context, text);
    final buyPackage = actions.buyPackage;
    return <Widget>[
      ...occurrenceCards,
      sectionLabel(_l10n.moneySectionPay),
      actions.recordPayment,
      if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
      sectionLabel(_l10n.moneySectionRequests),
      MoneyActionGrid(actions.requestButtons),
      if (actions.purchaseButtons.isNotEmpty) ...[
        sectionLabel(_l10n.moneySectionPurchases),
        MoneyActionGrid(actions.purchaseButtons),
      ],
      sectionLabel(_l10n.moneySectionDocuments),
      for (final tile in actions.workspaceTools) ...[
        tile,
        const SizedBox(height: 8),
      ],
      // #494 — member self-service reports: the standing financial
      // agreement and the month's payments, viewable/downloadable/
      // shareable without asking anyone. Gated by memberReports (#502).
      if (reportsOn)
        DocumentsFaceActions(
          onAgreement: () => ops.memberDoc('agreement'),
          onPaymentsReport: () => ops.memberDoc('payments'),
          onUsageReport: usageReportOn ? () => ops.memberDoc('usage') : null,
          onStatementPdf: null,
          showDocumentLibrary: false,
        ),
    ];
  }

  /// The cards of every face. [exposure] is what is open and overdue across
  /// MY invoices, judged by the workspace's own payment term (#726).
  Map<MoneyFace, List<Widget>> cards(
    List<Widget> occurrenceCards,
    InvoiceExposure? exposure,
  ) {
    final account = data.account;
    final statement = data.statement;
    final member = data.member;
    final overdueBanner = exposure == null || exposure.overdue.isEmpty
        ? null
        : OverdueBanner(exposure: exposure);
    return {
      MoneyFace.statement: [
        ...data.attemptsCard,
        if (statement != null) bill(MoneyFace.statement),
        if (account != null && account.isNotable) ...[
          const SizedBox(height: 8),
          AccountCard(
              account: account,
              currencyCode: data.currencyCode,
              collapsible: true),
        ],
      ],
      MoneyFace.payments: [
        if (overdueBanner != null) ...[overdueBanner, const SizedBox(height: 8)],
        ...data.attemptsCard,
        ...occurrenceCards,
        moneySectionLabel(context, _l10n.moneySectionPay),
        if (statement != null) bill(MoneyFace.payments),
      ],
      MoneyFace.invoices: [
        if (actions.hasWorkspaceTools)
          MoneyWorkspaceTools(actions: actions.workspaceTools),
        if (exposure != null) ...[
          InvoiceSummaryCard(exposure: exposure),
          const SizedBox(height: 8),
          MyInvoicesList(memberId: member?.id ?? '', exposure: exposure),
        ],
      ],
      // #833 — the month's bookings and what each of them costs. The face
      // is always in the tab strip; the flag decides whether it has
      // anything to say, so turning it off never leaves a dead tab.
      MoneyFace.usage: [
        // #873 — the month's consumption as a letter, from this face too.
        if (usageReportOn)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              key: const ValueKey('usage-report-button-face'),
              onPressed: () => ops.memberDoc('usage'),
              icon: const Icon(Icons.insights_outlined),
              label: Text(_l10n.usageReportButton),
            ),
          ),
        if (data.usageRecordsOn)
          UsageFace(period: ops.period),
      ],
      MoneyFace.documents: [
        if (data.priceNegotiationsOn &&
            member != null)
          NegotiationCard(memberId: member.id, currency: data.currency),
      ],
    };
  }

  /// The actions under each face.
  Map<MoneyFace, List<Widget>> faceActions() {
    final statement = data.statement;
    final buyPackage = actions.buyPackage;
    final workspace = data.workspace;
    Widget financesLink() => MyFinancesLinkCard(
          workspaceId: workspace?.id,
          workspaceName: workspace?.name,
        );
    return {
      MoneyFace.statement: const [],
      MoneyFace.payments: [
        const SizedBox(height: 8),
        actions.recordPayment,
        if (buyPackage != null) ...[const SizedBox(height: 8), buyPackage],
        moneySectionLabel(context, _l10n.moneySectionRequests),
        MoneyActionGrid(actions.requestButtons),
        if (actions.purchaseButtons.isNotEmpty) ...[
          moneySectionLabel(context, _l10n.moneySectionPurchases),
          MoneyActionGrid(actions.purchaseButtons),
        ],
        financesLink(),
      ],
      MoneyFace.invoices: [financesLink()],
      MoneyFace.usage: const [],
      MoneyFace.documents: [
        DocumentsFaceActions(
          onAgreement: reportsOn ? () => ops.memberDoc('agreement') : null,
          onPaymentsReport: reportsOn ? () => ops.memberDoc('payments') : null,
          onUsageReport: usageReportOn ? () => ops.memberDoc('usage') : null,
          onStatementPdf:
              data.pdfExportOn &&
                      statement != null
                  ? () => ops.exportBill(statement)
                  : null,
          showDocumentLibrary: data.documentsOn,
        ),
      ],
    };
  }
}
