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
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/storage/pane_width_store.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../../providers/recorded_payments_providers.dart';
import '../invoice_actions.dart';
import '../widgets/invoice_form_sheet.dart';
import 'invoice_month_flow.dart';
import 'invoice_page.dart';
import 'invoicing_customer_actions.dart';
import 'invoicing_home.dart';
import 'invoicing_list.dart';
import 'invoicing_live_pages.dart';
import 'invoicing_reads.dart';

/// #3773 — the narrowest the invoice list keeps its table (number, customer,
/// amount, state) without cutting a word, in the five languages: measured on
/// the Demo. Narrower, the open invoice stands over the list's end.
@visibleForTesting
const double kInvoicingListMinWidth = 640;

/// #3614 — what the pane shows for an open customer: `customer:<id>`, so
/// it is never taken for an invoice's id.
const String _customerKey = 'customer:';

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

  /// Names the list, for the order the arrow keys move along.
  final _listKey = GlobalKey();

  /// #3614 — the invoices the desk table shows, in their order.
  List<String> _deskOrder = const [];
  var _searchOpen = false;

  /// The screen's width is a wide window's: the cards side by side, the
  /// lists as tables.
  bool _wide = false;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final invoices = ref.watch(invoicesProvider);
    // #3610 — N: a new invoice; /: the search over the list.
    return ShortcutScope(
      handlers: {
        AppShortcutId.newRecord: () =>
            unawaited(showInvoiceIssueSheet(context, ref)),
        AppShortcutId.filter: () => setState(() => _searchOpen = true),
      },
      child: Scaffold(
      appBar: AppBar(
        title: PageTitle(l.featureInvoicing),
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
      body: LayoutBuilder(
        builder: (context, box) {
          _wide = isWideNavigationWidth(box.maxWidth);
          final home = switch (invoices) {
            AsyncData(:final value) => _home(context, value),
            AsyncError() => _home(context, const []),
            _ => const LoadingView(),
          };
          // #3607 — the open invoice is in the address. A large window keeps
          // it beside the list, which stays the same widget, so its view,
          // filter and search survive; a smaller one opens it as a page.
          // #3614 — and so is an open customer.
          return OpenRecord(
            listPath: invoicesPath,
            builder: (context, invoiceId) => OpenRecord(
              listPath: customersPath,
              builder: (context, customerId) => ListDetailScaffold(
                id: 'invoices',
                paneStore: ref.watch(paneWidthStoreProvider),
                listMin: kInvoicingListMinWidth,
                list: home,
                selected: !recordBesideList(context)
                    ? null
                    : customerId != null
                    ? '$_customerKey$customerId'
                    : invoiceId,
                onClose: () => closeRecord(context, invoicesPath),
                // The list's order; at the desk by invoice, the table's.
                order: () => switch (InvoicingList.orderUnder(_listKey)) {
                  final List<String> o when o.isEmpty => _deskOrder,
                  final o => o,
                },
                onMove: (id) => moveToRecord(context, invoicesPath, id),
                detail: (context, id) => id.startsWith(_customerKey)
                    ? CustomerRecord(
                        key: ValueKey('invoicing-customer-panel-$id'),
                        customerId: id.substring(_customerKey.length),
                        onClose: () => closeRecord(context, invoicesPath),
                      )
                    : InvoicePage(
                        key: ValueKey('invoicing-panel-$id'),
                        invoiceId: id,
                        onClose: () => closeRecord(context, invoicesPath),
                      ),
              ),
            ),
          );
        },
      ),
    ),
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
    // An entry is chosen by its key, never by its place in the list.
    return PopupMenuButton<String>(
      key: const ValueKey('invoicing-tools'),
      tooltip: l.invoicingTools,
      onSelected: (key) {
        for (final e in entries) {
          if (e.$1 == key) e.$4();
        }
      },
      itemBuilder: (_) => [
        for (final e in entries)
          PopupMenuItem<String>(
            key: ValueKey(e.$1),
            value: e.$1,
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
  }

  Widget _home(BuildContext context, List<Invoice> invoices) {
    // #3680 — while a status read is still running, nothing is counted.
    if (ref.watch(invoicingStatusesWaitingProvider)) return const LoadingView();
    final format = appFormatOf(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final now = ref.watch(clockProvider).now();
    // The business's calendar day, from the workspace's own context.
    final dayOf =
        ref.watch(readyWorkspaceContextProvider)?.calendar.dateOf ??
        (DateTime d) => DateTime(d.year, d.month, d.day);
    final today = dayOf(now);
    final rules = ref.watch(dunningRulesProvider).value ?? DunningRules.defaults; // empty-ok: the home waits for the statuses, the rules among them, and names a failed read
    // #3680 — the matches are read before anything is counted.
    ref.watch(invoiceMatchesProvider);
    final overview = ref.watch(invoicingOverviewProvider);
    final window = (
      workspaceId: workspace?.id ?? '',
      from: DateTime(today.year, today.month),
      to: DateTime(today.year, today.month + 1, 0),
    );
    final received = ref.watch(receivedPaymentsProvider(window));
    final reader = ref.watch(invoicingReaderProvider);
    final receivables = reader.read(invoices);
    // Unknown is not none: while the money not assigned is not read, nobody
    // is known to hold any, and nobody is reminded.
    final money = unassignedMoneyKnown(ref.watch(unassignedMoneyProvider));
    final creditsKnown = money != null;
    final holdsUnassigned = money?.holdersAmong(receivables) ?? const {};
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
        for (final p in received.value ?? const <ReceivedPayment>[]) // empty-ok: a failed read is the named source `payments`
          (currency: p.currency, minor: p.minor, on: dayOf(p.on)),
      ],
      failed: {
        ...ref.watch(invoicingFailedSourcesProvider),
        if (received.hasError) InvoicingSource.payments,
        if (overview.hasError) InvoicingSource.toInvoice,
      },
      holdsUnassigned: holdsUnassigned,
      creditsKnown: creditsKnown,
    );
    final byId = {for (final i in invoices) i.id: i};
    return InvoicingHome(
      listKey: _listKey,
      data: data,
      searchOpen: _searchOpen,
      filter: _filter,
      legalNotes: widget.legalNotes,
      wide: _wide,
      actions: InvoicingHomeActions(
        onOpenInvoice: (id) => _open(byId[id]),
        onOpenCustomer: (id) => openRecord(context, customersPath, id),
        onCustomerAction: (id, action) =>
            CustomerActions(context, ref).run(id, action),
        onTodo: (kind) => _todo(kind, period),
        onRetry: (source) => switch (source) {
          InvoicingSource.payments => ref.invalidate(
            receivedPaymentsProvider(window),
          ),
          InvoicingSource.toInvoice => ref.invalidate(
            invoicingOverviewProvider,
          ),
          _ => retryInvoicingSource(ref, source),
        },
        onNewInvoice: () => showInvoiceIssueSheet(context, ref),
        onRemind: (id) {
          if (byId[id] case final invoice?) {
            unawaited(remindInvoice(context, ref, invoice));
          }
        },
        // #3614 — a selection's reminders, one after the other, on the
        // reminder queue and its states.
        onShareReminders: (ids) => unawaited(
          _fullScreen(
            LiveReminderQueue(
              only: ids,
              onMatch: CustomerActions(context, ref).paymentsToMatch,
            ),
          ),
        ),
      ),
      onDeskOrder: (order) => _deskOrder = order,
    );
  }

  static DateTime _monthOf(String period) {
    final parts = period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Opens [invoice] at its address: beside the list on a large window, as
  /// a page otherwise.
  void _open(Invoice? invoice) {
    if (invoice != null) openRecord(context, invoicesPath, invoice.id);
  }

  /// The home opens every other "To do" entry as its own list; the month's
  /// entry opens its flow, the reminders by hand their queue.
  Future<void> _todo(TodoKind kind, String? period) async {
    if (kind == TodoKind.invoiceTheMonth) await _invoiceTheMonth(period);
    final creditsKnown =
        unassignedMoneyKnown(ref.read(unassignedMoneyProvider)) != null;
    if (kind == TodoKind.shareReminders && creditsKnown) {
      await _openQueue();
    }
  }

  /// Full screen, with its own messenger, so what it says is said there.
  Future<void> _fullScreen(Widget child) => showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(child: ScaffoldMessenger(child: child)),
  );

  /// The reminders shared by hand, the customers holding money we have not
  /// assigned listed first to match; drawn again as the reads change.
  Future<void> _openQueue() => _fullScreen(
    LiveReminderQueue(onMatch: CustomerActions(context, ref).paymentsToMatch),
  );

  /// The month to invoice, full screen with the list the app has today,
  /// until the month flow replaces it (R1-e).
  /// The month's flow (R1-e): every customer of the month with what is
  /// invoiced, the ones that need a fix said apart with their Fix, one
  /// Issue for the selection, and the result. A Fix opens the customer's
  /// page or the business's legal identity; the flow reads them again when
  /// the person comes back.
  Future<void> _invoiceTheMonth(String? period) async {
    final overview = ref.read(invoicingOverviewProvider).value;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (overview == null || workspace == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        // Its own messenger: what the month says is said once, here, not
        // also on the home under it.
        child: ScaffoldMessenger(
          child: InvoiceMonthFlow(
            period: period ?? overview.period,
            entries: overview.toInvoice,
            currency: workspace.currencyCode,
            workspaceId: workspace.id,
            onFixCustomer: (memberId) async {
              await context.push('/member/$memberId');
            },
            onFixBusiness: () async {
              await context.push('/legal-identity');
            },
          ),
        ),
      ),
    );
  }
}
