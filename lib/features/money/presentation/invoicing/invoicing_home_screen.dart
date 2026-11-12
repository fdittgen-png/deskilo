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
import 'invoicing_customer_link.dart';
import 'invoicing_home.dart';
import 'invoicing_list.dart';
import 'invoicing_live_pages.dart';
import 'invoicing_reads.dart';
import 'payments_to_match_screen.dart';

/// #3773 — the narrowest the invoice list keeps its table (number, customer,
/// amount, state) without cutting a word, in the five languages: measured on
/// the Demo. Narrower, the open invoice stands over the list's end.
@visibleForTesting
const double kInvoicingListMinWidth = 640;

/// The address of the invoice list; an open invoice is `/invoices/<id>`.
const String _invoicesPath = '/invoices';

/// What the screen read: the receivables, the invoices by id, their matches.
typedef _Read = ({
  List<Receivable> receivables,
  Map<String, Invoice> byId,
  Map<String, InvoiceMatch> matches,
  Set<String> holdsUnassigned,
  bool creditsKnown,
  ReminderMode mode,
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
    this.openCustomer,
  });

  /// The More menu's entries after "Paid and closed invoices".
  final List<MoreEntry> more;
  final bool isEu;
  final bool showMemberNames;
  final List<Widget>? legalNotes;

  /// #3610 — the customer the address names, opened once.
  final String? openCustomer;

  @override
  ConsumerState<InvoicingHomeScreen> createState() =>
      _InvoicingHomeScreenState();
}

class _InvoicingHomeScreenState extends ConsumerState<InvoicingHomeScreen> {
  final _filter = ValueNotifier(InvoicingFilter.open);

  /// Names the list, for the order the arrow keys move along.
  final _listKey = GlobalKey();
  var _searchOpen = false;

  /// What the home read at its last build: the actions act on it.
  _Read _read = (
    receivables: const [],
    byId: const {},
    matches: const {},
    holdsUnassigned: const {},
    creditsKnown: false,
    mode: ReminderMode.byHand,
  );

  /// The screen's width is a wide window's: the cards side by side, the
  /// lists as tables.
  bool _wide = false;

  @override
  void initState() {
    super.initState();
    _openLinked(widget.openCustomer);
  }

  @override
  void didUpdateWidget(InvoicingHomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.openCustomer != old.openCustomer) {
      _openLinked(widget.openCustomer);
    }
  }

  /// The customer the address names, once its frame is drawn.
  void _openLinked(String? customer) {
    if (customer == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(openLinkedCustomer(context, ref, customer, _openCustomer));
      }
    });
  }

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
          return OpenRecord(
            listPath: _invoicesPath,
            builder: (context, id) => ListDetailScaffold(
              id: 'invoices',
              paneStore: ref.watch(paneWidthStoreProvider),
              listMin: kInvoicingListMinWidth,
              list: home,
              selected: recordBesideList(context) ? id : null,
              onClose: () => closeRecord(context, _invoicesPath),
              order: () => InvoicingList.orderUnder(_listKey),
              onMove: (id) => moveToRecord(context, _invoicesPath, id),
              detail: (context, id) => InvoicePage(
                key: ValueKey('invoicing-panel-$id'),
                invoiceId: id,
                onClose: () => closeRecord(context, _invoicesPath),
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
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {}; // empty-ok: a failed read is a named source whose figures are withheld; a running one waits below
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
    final _Read read = (
      receivables: receivables,
      byId: byId,
      matches: matches,
      holdsUnassigned: holdsUnassigned,
      creditsKnown: creditsKnown,
      mode: data.mode,
    );
    // The actions of the pages opened over the home act on what is read
    // now, not on what was read when they opened.
    _read = read;
    return InvoicingHome(
      listKey: _listKey,
      data: data,
      searchOpen: _searchOpen,
      filter: _filter,
      legalNotes: widget.legalNotes,
      wide: _wide,
      actions: InvoicingHomeActions(
        onOpenInvoice: (id) => _open(byId[id], matches),
        onOpenCustomer: _openCustomer,
        onCustomerAction: _customerAction,
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

  /// Opens [invoice] at its address: beside the list on a large window, as
  /// a page otherwise.
  Future<void> _open(Invoice? invoice, Map<String, InvoiceMatch> _) async {
    if (invoice == null) return;
    openRecord(context, _invoicesPath, invoice.id);
  }

  Future<void> _customerAction(
    String customerId,
    InvoiceAction action,
  ) async {
    final (
      :receivables,
      :byId,
      :matches,
      :mode,
      :holdsUnassigned,
      :creditsKnown,
    ) = _read;
    // Nobody is reminded while who holds money is not known.
    if (action == InvoiceAction.shareReminder && !creditsKnown) return;
    // Money held unassigned is matched from the payments, never by
    // reminding the customer.
    if (action == InvoiceAction.match && holdsUnassigned.contains(customerId)) {
      await _openPaymentsToMatch(customerId);
      return;
    }
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

  /// The home opens every other "To do" entry as its own list; the month's
  /// entry opens its flow, the reminders by hand their queue.
  Future<void> _todo(TodoKind kind, String? period) async {
    if (kind == TodoKind.invoiceTheMonth) await _invoiceTheMonth(period);
    if (kind == TodoKind.shareReminders && _read.creditsKnown) {
      await _openQueue();
    }
  }

  /// Full screen, with its own messenger, so what it says is said there.
  Future<void> _fullScreen(Widget child) => showDialog<void>(
    context: context,
    builder: (_) => Dialog.fullscreen(child: ScaffoldMessenger(child: child)),
  );

  /// The customer's page: what they owe per currency, their credit, their
  /// invoices and their one action, on the current reads.
  Future<void> _openCustomer(String customerId) => _fullScreen(
    LiveCustomerPage(
      customerId: customerId,
      onOpenInvoice: (id) => openInvoicePage(context, id),
      onAction: (action) => _customerAction(customerId, action),
    ),
  );

  /// The reminders shared by hand, the customers holding money we have not
  /// assigned listed first to match; drawn again as the reads change.
  Future<void> _openQueue() =>
      _fullScreen(LiveReminderQueue(onMatch: _openPaymentsToMatch));

  /// The payments [customerId] made that no invoice has taken, each with the
  /// open invoices of the business's currency it could settle.
  Future<void> _openPaymentsToMatch(String customerId) => _fullScreen(
    PaymentsToMatchScreen(
      currency: ref.read(invoicingBusinessProvider).currency,
      customerId: customerId,
    ),
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
