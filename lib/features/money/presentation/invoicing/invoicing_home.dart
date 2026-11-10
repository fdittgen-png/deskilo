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
import '../../../../core/theme/app_radius.dart';
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
import 'invoicing_list.dart';
import 'invoicing_words.dart';

/// A source the home reads that can fail on its own; what it fed is not
/// shown while it is missing.
enum InvoicingSource { payments, reminders, toInvoice }

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
}

/// What the home's controls do; the screen wires the existing flows.
@immutable
class InvoicingHomeActions {
  const InvoicingHomeActions({
    required this.onOpenInvoice,
    required this.onOpenCustomer,
    required this.onCustomerAction,
    required this.onTodo,
    required this.onRules,
    required this.onRetry,
    required this.onNewInvoice,
  });

  final ValueChanged<String> onOpenInvoice;
  final ValueChanged<String> onOpenCustomer;
  final void Function(String customerId, InvoiceAction action) onCustomerAction;
  final ValueChanged<TodoKind> onTodo;
  final VoidCallback onRules;
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

  @override
  void dispose() {
    if (widget.filter == null) _filter.dispose();
    _query.dispose();
    super.dispose();
  }

  void _choose(InvoicingFilter f) => _filter.value = f;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = widget.data;
    // A business with no invoice at all, and nothing to invoice: one card
    // says where to start; no figure, filter or list has anything to say.
    if (data.receivables.isEmpty &&
        data.toInvoice.isEmpty &&
        data.failed.isEmpty) {
      return _EmptyHome(onNewInvoice: widget.actions.onNewInvoice);
    }
    return ValueListenableBuilder(
      valueListenable: _filter,
      builder: (context, filter, _) => LayoutBuilder(
        builder: (context, box) {
          final wide =
              widget.wide ?? box.maxWidth >= kWideNavigationMinWidth;
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
                      _FailedSource(
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
      OwedBucket.toConfirm: l.invoicingOwedToConfirm,
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
          _todoRow(l, t, caption(t), primary: i == 0),
      ],
      quiet: QuietLine(l.invoicingCaughtUp),
      footer: Row(
        children: [
          Expanded(
            child: QuietLine(
              data.mode == ReminderMode.automatic
                  ? l.invoicingRemindersAutomatic
                  : l.invoicingRemindersByHand,
              icon: Icons.notifications_outlined,
            ),
          ),
          TextButton(
            key: const ValueKey('invoicing-rules'),
            onPressed: widget.actions.onRules,
            child: Text(l.invoicingRules),
          ),
        ],
      ),
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
      onPressed: () => widget.actions.onTodo(t.kind),
    );
  }
}

/// The home of a business that has never invoiced.
class _EmptyHome extends StatelessWidget {
  const _EmptyHome({required this.onNewInvoice});

  final VoidCallback onNewInvoice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('invoicing-empty'),
      padding: AppSpacing.mdAll,
      children: [
        KitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              Text(l.invoicingEmptyTitle, style: theme.textTheme.titleMedium),
              Text(
                l.invoicingEmptyBody,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('invoicing-empty-new'),
                onPressed: onNewInvoice,
                icon: const Icon(Icons.add),
                label: Text(l.invoicingEmptyNew),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One line naming a source that could not be read, with a retry.
class _FailedSource extends StatelessWidget {
  const _FailedSource({required this.source, required this.onRetry});

  final InvoicingSource source;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = PersonalTheme.of(context);
    final name = switch (source) {
      InvoicingSource.payments => l.invoicingSourcePayments,
      InvoicingSource.reminders => l.invoicingSourceReminders,
      InvoicingSource.toInvoice => l.invoicingSourceToInvoice,
    };
    return DecoratedBox(
      key: ValueKey('invoicing-failed-${source.name}'),
      decoration: BoxDecoration(
        color: t.warningTint,
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l.invoicingSourceFailed(name),
                style: TextStyle(color: t.warning),
              ),
            ),
            TextButton(
              key: ValueKey('invoicing-retry-${source.name}'),
              onPressed: onRetry,
              child: Text(l.invoicingTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
