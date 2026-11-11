// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- the owner's invoicing home (the final design): how much is
// owed and in which state, the month's two figures, "To do", then the list,
// by customer or by invoice, under a pinned row of filters. Phone first: one
// column at 390 px; from the wide-navigation width the owed card and "To do"
// sit side by side and the customer list is a table. It draws what it is
// given; the screen reads the data and wires the existing flows.
import 'package:flutter/material.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/navigation_style.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/personal_theme.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/owed_card.dart';
import '../../../../core/ui/kit/split_bar.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/todo_card.dart';
import '../../../../core/ui/kit/todo_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_home_parts.dart';
import 'invoicing_list.dart';
import 'invoicing_words.dart';
import 'reminder_mode_line.dart';

/// A source the home reads that can fail on its own; what it fed is not
/// shown while it is missing.
enum InvoicingSource {
  invoices,
  matches,
  reminders,
  holds,
  transmissions,
  credits,
  payments,
  toInvoice;

  /// The sources every invoice's status, amount owed and action is read
  /// from: while one of them failed, no figure, list or action of the
  /// invoices is shown, only the failure and its Try again.
  static const Set<InvoicingSource> statuses = {
    invoices,
    matches,
    reminders,
    holds,
    transmissions,
    credits,
  };
}

/// What the home shows: the receivables on [today], the month [toInvoice],
/// the payments [received], the reminder [mode] and the sources that
/// [failed]. [currency] is the workspace's (what an empty card says in).
@immutable
class InvoicingHomeData {
  const InvoicingHomeData({
    required this.receivables,
    required this.today,
    required this.month,
    required this.currency,
    required this.mode,
    this.toInvoice = const [],
    this.toInvoiceMonth = '',
    this.received = const [],
    this.failed = const {},
    this.holdsUnassigned = const {},
    this.creditsKnown = true,
  });

  final List<Receivable> receivables;
  final DateTime today;

  /// The current month in words ("November").
  final String month;

  /// The month still to invoice in words ("October").
  final String toInvoiceMonth;
  final String currency;
  final ReminderMode mode;
  final List<ToInvoice> toInvoice;
  final List<ReceivedPayment> received;
  final Set<InvoicingSource> failed;

  /// The customers who hold money received and not assigned
  /// (`holdsUnassignedMoney`): matched first, never reminded.
  final Set<String> holdsUnassigned;

  /// Whether the customers' credits were read. Until then nobody is known
  /// to hold money, so no reminder is offered and "Share reminders by
  /// hand" says it is checking the received payments.
  final bool creditsKnown;
}

/// What the home's controls do; the screen wires the existing flows.
@immutable
class InvoicingHomeActions {
  const InvoicingHomeActions({
    required this.onOpenInvoice,
    required this.onOpenCustomer,
    required this.onCustomerAction,
    required this.onTodo,
    required this.onRetry,
    required this.onNewInvoice,
  });

  final ValueChanged<String> onOpenInvoice;
  final ValueChanged<String> onOpenCustomer;
  final void Function(String customerId, InvoiceAction action) onCustomerAction;
  final ValueChanged<TodoKind> onTodo;
  final ValueChanged<InvoicingSource> onRetry;
  final VoidCallback onNewInvoice;
}

/// At most this many "To do" entries show; the badge counts them all.
const int _todoShown = 5;

class InvoicingHome extends StatefulWidget {
  const InvoicingHome({
    super.key,
    required this.data,
    required this.actions,
    this.searchOpen = false,
    this.filter,
    this.legalNotes,
    this.wide,
  });

  final InvoicingHomeData data;
  final InvoicingHomeActions actions;

  /// The search field is shown (the top bar's Search opens it).
  final bool searchOpen;

  /// A filter chosen from outside (More → Paid and closed invoices).
  final ValueNotifier<InvoicingFilter>? filter;

  /// The legal notices, collapsed under one line; null when there are none.
  final List<Widget>? legalNotes;

  /// Whether the home lays itself out for a wide window, decided by the
  /// screen from the width it is given (an invoice panel beside the list
  /// must not turn the tables into phone lines); null: from its own width.
  final bool? wide;

  @override
  State<InvoicingHome> createState() => _InvoicingHomeState();
}

class _InvoicingHomeState extends State<InvoicingHome> {
  late final ValueNotifier<InvoicingFilter> _filter =
      widget.filter ?? ValueNotifier(InvoicingFilter.open);
  var _view = InvoicingView.customers;
  final _query = TextEditingController();

  /// The "To do" entry the list shows, or null for the filter's list.
  TodoKind? _todo;

  @override
  void initState() {
    super.initState();
    // A filter chosen anywhere (a chip, a legend line, More) replaces the
    // "To do" list.
    _filter.addListener(_clearTodo);
  }

  void _clearTodo() {
    if (_todo != null) setState(() => _todo = null);
  }

  @override
  void dispose() {
    _filter.removeListener(_clearTodo);
    if (widget.filter == null) _filter.dispose();
    _query.dispose();
    super.dispose();
  }

  void _choose(InvoicingFilter f) {
    _clearTodo();
    _filter.value = f;
  }

  /// A "To do" entry opens the list of exactly what it counts; the month's
  /// entry opens its own flow.
  void _openTodo(TodoKind kind) {
    // The month's entry opens its flow and the reminders by hand open their
    // queue, which lists exactly the reminders the entry counts.
    if (kind == TodoKind.invoiceTheMonth || kind == TodoKind.shareReminders) {
      widget.actions.onTodo(kind);
      return;
    }
    setState(() => _todo = kind);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = widget.data;
    // A business with no invoice at all, and nothing to invoice: one card
    // says where to start; no figure, filter or list has anything to say.
    if (data.receivables.isEmpty &&
        data.toInvoice.isEmpty &&
        data.failed.isEmpty) {
      return InvoicingEmptyHome(onNewInvoice: widget.actions.onNewInvoice);
    }
    return ValueListenableBuilder(
      valueListenable: _filter,
      builder: (context, filter, _) => LayoutBuilder(
        builder: (context, box) {
          final wide =
              widget.wide ?? box.maxWidth >= kWideNavigationMinWidth;
          final statusesFailed = data.failed.any(
            InvoicingSource.statuses.contains,
          );
          if (statusesFailed) return _failedOnly(data.failed);
          final owed = _owedCard(context, filter);
          final todo = _todoCard(context);
          return CustomScrollView(
            key: const ValueKey('invoicing-home'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    for (final s in data.failed) ...[
                      InvoicingFailedSource(
                        source: s,
                        onRetry: () => widget.actions.onRetry(s),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: AppSpacing.md,
                        children: [
                          Expanded(child: owed),
                          Expanded(child: todo),
                        ],
                      )
                    else ...[
                      owed,
                      const SizedBox(height: AppSpacing.md),
                      todo,
                    ],
                    if (widget.legalNotes case final notes?) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ExpansionTile(
                        key: const ValueKey('invoicing-legal-notes'),
                        title: Text(l.invoicingLegalNotes),
                        tilePadding: EdgeInsets.zero,
                        children: notes,
                      ),
                    ],
                  ],
                ),
              ),
              InvoicingList(
                key: const ValueKey('invoicing-list'),
                receivables: data.receivables,
                today: data.today,
                mode: data.mode,
                holdsUnassigned: data.holdsUnassigned,
                remindersKnown: data.creditsKnown,
                filter: filter,
                view: _view,
                query: _query,
                searchOpen: widget.searchOpen,
                wide: wide,
                onFilter: _choose,
                onView: (v) => setState(() => _view = v),
                onOpenInvoice: widget.actions.onOpenInvoice,
                onOpenCustomer: widget.actions.onOpenCustomer,
                onCustomerAction: widget.actions.onCustomerAction,
                todo: switch (_todo) {
                  final kind? => (kind: kind, title: _todoTitle(l, kind)),
                  null => null,
                },
                onClearTodo: () => setState(() => _todo = null),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _owedCard(BuildContext context, InvoicingFilter filter) {
    final l = context.l10n;
    final data = widget.data;
    final format = appFormatOf(context);
    final t = PersonalTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    Color tone(StatusTone s) => statusColorsOf(t, s, scheme: scheme).$2;
    final colours = {
      OwedBucket.notYetDue: t.interactiveBorder,
      OwedBucket.toConfirm: tone(StatusTone.info),
      OwedBucket.overdue: tone(StatusTone.due),
    };
    final labels = {
      OwedBucket.notYetDue: l.invoicingOwedNotYetDue,
      OwedBucket.toConfirm: l.journeyStageConfirm,
      OwedBucket.overdue: l.invoicingOwedOverdue,
    };
    final owed = owedOf(data.receivables, data.today);
    final month = monthOf(
      data.receivables,
      data.today,
      received: data.received,
    );
    List<String> values(Tally t) => t.byCurrency.isEmpty
        ? [format.moneyIn(data.currency).formatMinor(0)]
        : [
            for (final e in t.byCurrency.entries)
              format.moneyIn(e.key).formatMinor(e.value),
          ];
    OwedBlock block(OwedInCurrency o) {
      final money = format.moneyIn(o.currency);
      return (
        total: money.formatMinor(o.totalMinor),
        parts: [
          for (final b in OwedBucket.values)
            (weight: o.buckets[b]?.minor ?? 0, color: colours[b]!),
        ],
        legend: [
          for (final b in OwedBucket.values)
            if (o.buckets[b] case final share?)
              LegendToggle(
                key: ValueKey('invoicing-owed-${o.currency}-${b.name}'),
                color: colours[b]!,
                label: labels[b]!,
                caption: l.invoicingInvoiceCount(share.count),
                value: money.formatMinor(share.minor),
                selected: filter == InvoicingFilter.of(b),
                onTap: () => _choose(InvoicingFilter.of(b)),
              ),
        ],
      );
    }

    return OwedCard(
      key: const ValueKey('invoicing-owed'),
      label: l.invoicingOwed,
      blocks: owed.isEmpty
          ? [
              (
                total: format.moneyIn(data.currency).formatMinor(0),
                parts: const [],
                legend: const [],
              ),
            ]
          : [for (final o in owed) block(o)],
      figures: [
        (
          label: l.invoicingInvoicedIn(data.month),
          values: values(month.invoiced),
        ),
        // No figure is shown that was not read.
        if (!data.failed.contains(InvoicingSource.payments))
          (
            label: l.invoicingReceivedIn(data.month),
            values: values(month.received),
          ),
      ],
    );
  }

  Widget _todoCard(BuildContext context) {
    final l = context.l10n;
    final data = widget.data;
    final format = appFormatOf(context);
    final todo = todoOf(
      data.receivables,
      toInvoice: data.failed.contains(InvoicingSource.toInvoice)
          ? const []
          : data.toInvoice,
      mode: data.mode,
      holdsUnassigned: data.holdsUnassigned,
    );
    String caption(Todo t) => t.kind == TodoKind.invoiceTheMonth
        ? '${l.invoicingCustomerCount(t.tally.count)} · ${amountsOf(format, t.tally)}'
        : '${l.invoicingInvoiceCount(t.tally.count)} · ${amountsOf(format, t.tally)}';
    return TodoCard(
      key: const ValueKey('invoicing-todo'),
      title: l.invoicingTodo,
      count: todo.length,
      rows: [
        for (final (i, t) in todo.take(_todoShown).indexed)
          _todoRow(
            l,
            t,
            // The reminders wait for the received payments: who holds money
            // is matched first, and that is not known yet.
            t.kind == TodoKind.shareReminders && !data.creditsKnown
                ? l.invoicingCheckingPayments
                : caption(t),
            primary: i == 0,
          ),
      ],
      quiet: QuietLine(l.invoicingCaughtUp),
      // How reminders go out, with Rules: the line the reminders share.
      footer: const ReminderModeLine(),
    );
  }

  Widget _todoRow(
    AppLocalizations l,
    Todo t,
    String caption, {
    required bool primary,
  }) {
    final words = todoWordsOf(l, t, widget.data.toInvoiceMonth);
    return TodoRow(
      icon: words.icon,
      title: words.title,
      caption: caption,
      buttonLabel: words.button,
      buttonKey: ValueKey('invoicing-todo-${t.kind.name}'),
      primary: primary,
      alert: words.alert,
      onPressed: t.kind == TodoKind.shareReminders && !widget.data.creditsKnown
          ? null
          : () => _openTodo(t.kind),
    );
  }

  /// The title of the "To do" entry [kind], as its row says it now.
  String _todoTitle(AppLocalizations l, TodoKind kind) {
    final data = widget.data;
    final todo = todoOf(
      data.receivables,
      mode: data.mode,
      holdsUnassigned: data.holdsUnassigned,
    ).firstWhere(
      (t) => t.kind == kind,
      orElse: () => (kind: kind, tally: Tally.empty),
    );
    return todoWordsOf(l, todo, data.toInvoiceMonth).title;
  }

  /// Only the sources that failed, each with its Try again: nothing read
  /// from them is shown as if it had been read.
  Widget _failedOnly(Set<InvoicingSource> failed) => ListView(
    key: const ValueKey('invoicing-failed'),
    padding: AppSpacing.mdAll,
    children: [
      for (final s in failed) ...[
        InvoicingFailedSource(source: s, onRetry: () => widget.actions.onRetry(s)),
        const SizedBox(height: AppSpacing.sm),
      ],
    ],
  );
}
