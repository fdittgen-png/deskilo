// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- /invoices for someone who issues: the top bar (Invoices,
// Search, New, one worded More menu) over the invoicing home. It reads the
// invoices, their matches, reminders, holds, transmissions and payment
// events as receivables, the month to invoice and the month's payments,
// and hands every action to the flow the app already has. A source that
// fails is named on the home, and what it fed is not shown.
//
// Until their own pages land in this release, three entries lead to the
// flows that exist today: "Invoice {month}" opens the month's list
// (R1-e), the reminder and payment entries filter the list (R1-f), and a
// customer opens their oldest open invoice (R1-g).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../../providers/recorded_payments_providers.dart';
import '../invoice_actions.dart';
import '../invoice_proforma.dart';
import '../invoice_status.dart';
import '../widgets/dunning_rules_dialog.dart';
import '../widgets/invoice_detail_sheet.dart' hide InvoiceAction;
import '../widgets/invoice_form_sheet.dart';
import '../widgets/invoice_journey_view.dart';
import '../widgets/invoicing_dashboard.dart';
import 'invoicing_home.dart';
import 'invoicing_list.dart';
import 'receivables_adapter.dart';

/// What the screen read: the receivables, the invoices by id, their matches.
typedef _Read = ({
  List<Receivable> receivables,
  Map<String, Invoice> byId,
  Map<String, InvoiceMatch> matches,
});

/// One entry of the More menu: its key, icon, words and action.
typedef MoreEntry = (String key, IconData icon, String label, VoidCallback run);

class InvoicingHomeScreen extends ConsumerStatefulWidget {
  const InvoicingHomeScreen({
    super.key,
    required this.more,
    required this.isEu,
    required this.showMemberNames,
    this.legalNotes,
  });

  /// The More menu's entries after "Paid and closed invoices".
  final List<MoreEntry> more;
  final bool isEu;
  final bool showMemberNames;
  final List<Widget>? legalNotes;

  @override
  ConsumerState<InvoicingHomeScreen> createState() =>
      _InvoicingHomeScreenState();
}

class _InvoicingHomeScreenState extends ConsumerState<InvoicingHomeScreen> {
  final _filter = ValueNotifier(InvoicingFilter.open);
  var _searchOpen = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invoices = ref.watch(invoicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.featureInvoicing),
        actions: [
          IconButton(
            key: const ValueKey('invoicing-search'),
            tooltip: l.invoicingSearch,
            icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
            onPressed: () => setState(() => _searchOpen = !_searchOpen),
          ),
          OutlinedButton.icon(
            key: const ValueKey('invoicing-new'),
            onPressed: () => showInvoiceIssueSheet(context, ref),
            icon: const Icon(Icons.add),
            label: Text(l.invoicingNew),
          ),
          _moreMenu(context),
        ],
      ),
      body: switch (invoices) {
        AsyncData(:final value) => _home(context, value),
        AsyncError() => _home(context, const [], failedInvoices: true),
        _ => const LoadingView(),
      },
    );
  }

  Widget _moreMenu(BuildContext context) {
    final l = context.l10n;
    final entries = <MoreEntry>[
      (
        'invoicing-more-paid',
        Icons.task_alt,
        l.invoicingMorePaid,
        () => _filter.value = InvoicingFilter.paid,
      ),
      ...widget.more,
    ];
    return PopupMenuButton<int>(
      key: const ValueKey('invoicing-tools'),
      tooltip: l.invoicingTools,
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
      // Worded, so the title bar never shows an unnamed icon.
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
    );
  }

  Widget _home(
    BuildContext context,
    List<Invoice> invoices, {
    bool failedInvoices = false,
  }) {
    final format = appFormatOf(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final now = ref.watch(clockProvider).now();
    // The business's calendar day, from the workspace's own context.
    final dayOf =
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf ??
        (DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dayOf(now);
    final rules =
        ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider);
    final overview = ref.watch(invoicingOverviewProvider);
    final window = (
      workspaceId: workspace?.id ?? '',
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month + 1, 0),
    );
    final received = ref.watch(receivedPaymentsProvider(window));
    final reader = ReceivablesReader(
      matches: matches,
      reminders: reminders.value ?? const {},
      rules: rules,
      now: now,
      dayOf: dayOf,
      eventFactsOf: ref.watch(invoiceEventFactsProvider),
      transmissions: ref.watch(invoiceTransmissionsProvider).value ?? const {},
      held: {...?ref.watch(dunningHoldsProvider).value?.keys},
    );
    final receivables = reader.read(invoices);
    final period = overview.value?.period;
    final currency = workspace?.currencyCode ?? '';
    final data = InvoicingHomeData(
      receivables: receivables,
      today: today,
      month: format.dates(DateShape.month).format(today),
      toInvoiceMonth: period == null
          ? ''
          : format.dates(DateShape.month).format(_monthOf(period)),
      currency: currency,
      mode: rules.automatic ? ReminderMode.automatic : ReminderMode.byHand,
      toInvoice: [
        for (final e in overview.value?.toInvoice ?? const <ToInvoiceEntry>[])
          (
            customerId: e.memberId,
            currency: currency,
            amountMinor: e.totalCents,
          ),
      ],
      // Each payment dated by its match on the business's calendar.
      received: [
        for (final p in received.value ?? const <ReceivedPayment>[])
          (currency: p.currency, minor: p.minor, on: dayOf(p.on)),
      ],
      failed: {
        if (received.hasError) InvoicingSource.payments,
        if (reminders.hasError) InvoicingSource.reminders,
        if (overview.hasError) InvoicingSource.toInvoice,
      },
    );
    final byId = {for (final i in invoices) i.id: i};
    return InvoicingHome(
      data: data,
      searchOpen: _searchOpen,
      filter: _filter,
      legalNotes: widget.legalNotes,
      actions: InvoicingHomeActions(
        onOpenInvoice: (id) => _open(byId[id], matches),
        onOpenCustomer: (customerId) => _open(
          byId[_oldestOf(receivables, customerId, (r) => r.isOutstanding)],
          matches,
        ),
        onCustomerAction: (customerId, action) => _customerAction(
          (receivables: receivables, byId: byId, matches: matches),
          customerId,
          action,
          data.mode,
        ),
        onTodo: (kind) => _todo(kind, receivables, byId, matches, period),
        onRules: () => showDunningRulesDialog(context, ref),
        onRetry: (source) => switch (source) {
          InvoicingSource.payments => ref.invalidate(
            receivedPaymentsProvider(window),
          ),
          InvoicingSource.reminders => ref.invalidate(invoiceRemindersProvider),
          InvoicingSource.toInvoice => ref.invalidate(
            invoicingOverviewProvider,
          ),
        },
        onNewInvoice: () => showInvoiceIssueSheet(context, ref),
      ),
    );
  }

  static DateTime _monthOf(String period) {
    final parts = period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// The id of [customerId]'s oldest receivable that [holds], or ''.
  static String _oldestOf(
    List<Receivable> receivables,
    String customerId,
    bool Function(Receivable) holds,
  ) {
    final theirs = [
      for (final r in receivables)
        if (r.customerId == customerId && holds(r)) r,
    ]..sort((a, b) => (a.dueOn ?? a.issuedOn).compareTo(b.dueOn ?? b.issuedOn));
    return theirs.isEmpty ? '' : theirs.first.invoiceId;
  }

  Future<void> _open(
    Invoice? invoice,
    Map<String, InvoiceMatch> matches,
  ) async {
    if (invoice == null) return;
    final reminders = ref.read(invoiceRemindersProvider).value ?? const {};
    final match = matches[invoice.id];
    await showInvoiceDetailSheet(
      context,
      ref: ref,
      view: InvoiceDetailView(
        invoice: invoice,
        match: match,
        settledByNumber: settledByNumberOf(
          invoice,
          ref.read(invoicesProvider).value ?? const [],
        ),
        canIssue: true,
        isEu: widget.isEu,
        reminder: reminders[invoice.id],
        showMemberName: widget.showMemberNames,
        transmission: ref.read(invoiceTransmissionsProvider).value?[invoice.id],
        journey: readInvoiceJourney(
          ref,
          invoice,
          match: match,
          reminder: reminders[invoice.id],
        ),
      ),
    );
  }

  Future<void> _customerAction(
    _Read read,
    String customerId,
    InvoiceAction action,
    ReminderMode mode,
  ) async {
    final (:receivables, :byId, :matches) = read;
    final bool Function(Receivable) holds = switch (action) {
      InvoiceAction.shareReminder => (r) => reminderToShare(r, mode),
      InvoiceAction.confirmPayment => (r) => r.paymentDeclared,
      _ => (r) => r.paymentToMatch,
    };
    final invoice = byId[_oldestOf(receivables, customerId, holds)];
    if (invoice == null) return;
    switch (action) {
      case InvoiceAction.shareReminder:
        await remindInvoice(context, ref, invoice);
      case InvoiceAction.match:
        await matchInvoiceToPayment(context, ref, invoice);
      case _:
        // Confirm or Not received is decided on the invoice (R1-f brings
        // the payments to confirm as their own flow).
        await _open(invoice, matches);
    }
  }

  Future<void> _todo(
    TodoKind kind,
    List<Receivable> receivables,
    Map<String, Invoice> byId,
    Map<String, InvoiceMatch> matches,
    String? period,
  ) async {
    Invoice? first(bool Function(Receivable) holds) {
      for (final r in receivables) {
        if (holds(r)) return byId[r.invoiceId];
      }
      return null;
    }

    switch (kind) {
      case TodoKind.invoiceTheMonth:
        await _invoiceTheMonth(period);
      case TodoKind.shareReminders:
        _filter.value = InvoicingFilter.overdue;
      case TodoKind.confirmPayments || TodoKind.matchPayments:
        _filter.value = InvoicingFilter.toConfirm;
      case TodoKind.payOutRefunds:
        final note = first((r) => r.stage == ReceivableStage.refundOwed);
        if (note != null) await settleCreditInvoiceDialog(context, ref, note);
      case TodoKind.rejectedEInvoices:
        await _open(first((r) => r.eInvoiceRejected), matches);
      case TodoKind.setDueDate:
        await _open(first((r) => r.isOutstanding && !r.dueDateSet), matches);
      case TodoKind.issueDrafts:
        break;
    }
  }

  /// The month to invoice, full screen with the list the app has today,
  /// until the month flow replaces it (R1-e).
  Future<void> _invoiceTheMonth(String? period) async {
    final l = context.l10n;
    final format = appFormatOf(context);
    final currencyCode = ref.read(currentWorkspaceProvider).value?.currencyCode;
    final currency = format.moneyIn(currencyCode ?? '');
    await showDialog<void>(
      context: context,
      builder: (page) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              l.invoicingTodoMonth(
                period == null
                    ? ''
                    : format.dates(DateShape.month).format(_monthOf(period)),
              ),
            ),
          ),
          body: ToInvoiceTab(
            currency: currency,
            onIssue: (memberId, p) =>
                showInvoiceIssueSheet(page, ref, memberId: memberId, period: p),
            onIssueAll: (entries, p) =>
                issueInvoicesForAll(page, ref, entries, p, currency),
            onProforma: (memberId, p) async {
              final invoice = await proformaForMonth(
                ref,
                memberId: memberId,
                period: p,
              );
              if (invoice != null && page.mounted) {
                await shareProforma(page, ref, invoice);
              }
            },
          ),
        ),
      ),
    );
  }
}
