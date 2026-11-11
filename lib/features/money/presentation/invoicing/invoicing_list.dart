// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- the invoicing home's list: a pinned row (the search field
// when open, the filter chips, the count and the Customers / Invoices
// switch) over one line per customer -- late customers first, with their one
// action -- or one line per invoice with its status in words. On a wide
// window the customer lines are a table under their header.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/personal_theme.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/customer_row.dart';
import '../../../../core/ui/kit/filter_chips.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/table_line.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_words.dart';

/// What the list holds: the open invoices, one bucket of them, or the paid
/// and closed ones.
enum InvoicingFilter {
  open,
  notYetDue,
  toConfirm,
  overdue,
  paid;

  /// The filter of an owed bucket (its legend line).
  static InvoicingFilter of(OwedBucket bucket) => switch (bucket) {
    OwedBucket.notYetDue => notYetDue,
    OwedBucket.toConfirm => toConfirm,
    OwedBucket.overdue => overdue,
  };

  bool holds(Receivable r, DateTime today) => switch (this) {
    open => r.isOutstanding,
    notYetDue => owedBucketOf(r, today) == OwedBucket.notYetDue,
    toConfirm => owedBucketOf(r, today) == OwedBucket.toConfirm,
    overdue => owedBucketOf(r, today) == OwedBucket.overdue,
    paid => !r.isOutstanding && r.stage != ReceivableStage.draft,
  };
}

/// One line per customer, or one per invoice.
enum InvoicingView { customers, invoices }

/// The chips shown (the legend's Not yet due has no chip of its own).
/// The wide invoice table: customer · invoice · due · open · status.
const KitColumns _invoiceColumns = (flex: [4, 3, 2, 3, 4], endFrom: 3);

const List<InvoicingFilter> _chips = [
  InvoicingFilter.open,
  InvoicingFilter.overdue,
  InvoicingFilter.toConfirm,
  InvoicingFilter.paid,
];

class InvoicingList extends StatelessWidget {
  const InvoicingList({
    super.key,
    required this.receivables,
    required this.today,
    required this.mode,
    required this.filter,
    required this.view,
    required this.query,
    required this.searchOpen,
    required this.wide,
    required this.onFilter,
    required this.onView,
    required this.onOpenInvoice,
    required this.onOpenCustomer,
    required this.onCustomerAction,
    this.todo,
    this.onClearTodo,
    this.holdsUnassigned = const {},
    this.remindersKnown = true,
  });

  final List<Receivable> receivables;
  final DateTime today;
  final ReminderMode mode;
  final InvoicingFilter filter;
  final InvoicingView view;
  final TextEditingController query;
  final bool searchOpen;
  final bool wide;
  final ValueChanged<InvoicingFilter> onFilter;
  final ValueChanged<InvoicingView> onView;
  final ValueChanged<String> onOpenInvoice;
  final ValueChanged<String> onOpenCustomer;
  final void Function(String customerId, InvoiceAction action) onCustomerAction;

  /// The "To do" entry the list was opened from, with its title: the list
  /// is then exactly what that entry counts, until [onClearTodo].
  final ({TodoKind kind, String title})? todo;
  final VoidCallback? onClearTodo;

  /// The customers matched first and never reminded (`holdsUnassignedMoney`).
  final Set<String> holdsUnassigned;

  /// False while who holds money is not known: no Remind is offered.
  final bool remindersKnown;

  bool _selects(Receivable r) => switch (todo) {
    (:final kind, title: _) =>
      todoKindOf(r, mode, holdsUnassigned: holdsUnassigned) == kind,
    null => filter.holds(r, today),
  };

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: query,
    builder: (context, value, _) {
      final q = value.text.trim().toLowerCase();
      final shown = [
        for (final r in receivables)
          if (_selects(r) &&
              (q.isEmpty ||
                  r.customerName.toLowerCase().contains(q) ||
                  r.number.toLowerCase().contains(q)))
            r,
      ];
      final byCustomer =
          view == InvoicingView.customers && filter != InvoicingFilter.paid;
      return SliverMainAxisGroup(
        slivers: [
          PinnedHeaderSliver(child: _header(context, shown, byCustomer)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: shown.isEmpty
                  ? KitCard(child: QuietLine(_nothing(context.l10n, q)))
                  : RowList(
                      rows: byCustomer
                          ? _customerRows(context, shown)
                          : _invoiceRows(context, shown),
                    ),
            ),
          ),
        ],
      );
    },
  );

  String _nothing(AppLocalizations l, String q) {
    if (q.isNotEmpty) return l.invoicingNothingMatches(query.text.trim());
    return switch (filter) {
      InvoicingFilter.overdue => l.invoicingNothingOverdue,
      InvoicingFilter.toConfirm => l.invoicingNothingToConfirm,
      _ => l.invoicingNothingHere,
    };
  }

  Widget _header(
    BuildContext context,
    List<Receivable> shown,
    bool byCustomer,
  ) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final customers = {for (final r in shown) r.customerId}.length;
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.sm,
          children: [
            if (searchOpen)
              AppTextField(
                key: const ValueKey('invoicing-search-field'),
                controller: query,
                label: l.invoicingSearch,
                hint: l.invoicingSearchHint,
                prefixIcon: const Icon(Icons.search),
                autofocus: true,
              ),
            if (todo case (:final title, kind: _))
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InputChip(
                  key: const ValueKey('invoicing-todo-selected'),
                  label: Text(title),
                  selected: true,
                  onDeleted: onClearTodo,
                  deleteButtonTooltipMessage: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                ),
              ),
            FilterChips(
              key: const ValueKey('invoicing-filters'),
              options: [
                for (final f in _chips)
                  (
                    value: f,
                    label: switch (f) {
                      InvoicingFilter.open => l.invoicingFilterOpen,
                      InvoicingFilter.overdue => l.invoicingFilterOverdue,
                      InvoicingFilter.toConfirm => l.journeyStageConfirm,
                      _ => l.invoicingFilterPaid,
                    },
                    key: ValueKey('invoicing-filter-${f.name}'),
                  ),
              ],
              selected: filter,
              onSelected: onFilter,
            ),
            // The count and the switch share one row where they fit (a
            // phone of 390 px and up), so the pinned area is two rows; on the
            // narrowest phones the switch moves under the count.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l.invoicingCountLine(
                    l.invoicingCustomerCount(customers),
                    l.invoicingInvoiceCount(shown.length),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (filter != InvoicingFilter.paid)
                  ViewToggle<InvoicingView>(
                    key: const ValueKey('invoicing-view'),
                    selected: view,
                    onChanged: onView,
                    options: [
                      ViewToggleOption(
                        value: InvoicingView.customers,
                        icon: Icons.people_outline,
                        label: l.invoicingViewCustomers,
                      ),
                      ViewToggleOption(
                        value: InvoicingView.invoices,
                        icon: Icons.receipt_long_outlined,
                        label: l.featureInvoicing,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _customerRows(BuildContext context, List<Receivable> shown) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final rows = customerRowsOf(
      shown,
      today: today,
      mode: mode,
      holdsUnassigned: holdsUnassigned,
    );
    return [
      if (wide)
        CustomerHeader(
          customer: l.invoicingColCustomer,
          invoices: l.featureInvoicing,
          oldest: l.invoicingColOldest,
          owes: l.invoicingColOwes,
        ),
      for (final row in rows)
        CustomerRow(
          key: ValueKey('invoicing-customer-${row.customerId}'),
          name: row.customerName,
          caption: _captionOf(context, l, format, row),
          invoices: '${row.invoices.length}',
          oldest: _chipOf(l, format, row.invoices.first),
          owes: [
            for (final e in row.owes.byCurrency.entries)
              format.moneyIn(e.key).formatMinor(e.value),
          ],
          wide: wide,
          onTap: () => onOpenCustomer(row.customerId),
          action: _actionOf(l, row),
        ),
    ];
  }

  /// The line's second line: how many invoices, then what stands out about
  /// the customer in its tone -- late in the due tone, a declared payment in
  /// info, a hold in warning.
  Widget _captionOf(
    BuildContext context,
    AppLocalizations l,
    AppFormat format,
    CustomerLine row,
  ) {
    final t = PersonalTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    Color tone(StatusTone s) => statusColorsOf(t, s, scheme: scheme).$2;
    final count = l.invoicingInvoiceCount(row.invoices.length);
    final String words;
    final Color? colour;
    if (row.onHold && row.remindersToShare == 0) {
      words = l.invoicingStatusOnHold;
      colour = tone(StatusTone.warn);
    } else if (row.daysLate case final days?) {
      words = row.everyReminderSent
          ? '${l.invoicingDaysLate(days)} · ${l.invoicingEveryReminderSent}'
          : l.invoicingDaysLate(days);
      colour = tone(StatusTone.due);
    } else {
      final first = row.invoices.first;
      final status = invoiceStatusOf(first, today);
      words = statusWordsOf(l, format, first, status, today);
      final kind = statusToneOf(status.kind);
      colour = kind == StatusTone.neutral ? null : tone(kind);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$count · '),
          TextSpan(
            text: words,
            style: TextStyle(color: colour),
          ),
        ],
      ),
    );
  }

  Widget? _actionOf(AppLocalizations l, CustomerLine row) {
    final action = row.action;
    if (action == null) return null;
    if (action == InvoiceAction.shareReminder && !remindersKnown) return null;
    final label = switch (action) {
      InvoiceAction.shareReminder => l.invoicingActionRemind,
      InvoiceAction.confirmPayment => l.invoicingActionConfirm,
      _ => l.invoicingActionMatch,
    };
    return FilledButton.tonal(
      key: ValueKey('invoicing-customer-action-${row.customerId}'),
      onPressed: () => onCustomerAction(row.customerId, action),
      child: Text(label),
    );
  }

  Widget _chipOf(AppLocalizations l, AppFormat format, Receivable r) {
    final status = invoiceStatusOf(r, today);
    return StatusChip(
      label: statusWordsOf(l, format, r, status, today),
      tone: statusToneOf(status.kind),
    );
  }

  List<Widget> _invoiceRows(BuildContext context, List<Receivable> shown) {
    final l = context.l10n;
    final format = appFormatOf(context);
    int key(Receivable r) => filter == InvoicingFilter.paid
        ? -(r.paidOn ?? r.issuedOn).millisecondsSinceEpoch
        : (r.dueOn ?? r.issuedOn).millisecondsSinceEpoch;
    final sorted = [...shown]..sort((a, b) => key(a).compareTo(key(b)));
    String due(Receivable r) => r.dueOn == null
        ? ''
        : format.dates(DateShape.monthDay).format(r.dueOn!);
    String amount(Receivable r) => format
        .moneyIn(r.currency)
        .formatMinor(
          r.stage == ReceivableStage.paid ? r.totalMinor : r.openMinor,
        );
    if (wide) {
      return [
        KitTableHeader(
          columns: _invoiceColumns,
          labels: [
            l.invoicingColCustomer,
            l.invoicingColInvoice,
            l.invoicingColDue,
            l.invoicingColOpen,
            l.invoicingColStatus,
          ],
        ),
        for (final r in sorted)
          KitTableLine(
            key: ValueKey('invoicing-row-${r.invoiceId}'),
            columns: _invoiceColumns,
            cells: [
              Text(
                r.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(r.number),
              Text(due(r)),
              Text(
                amount(r),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              _chipOf(l, format, r),
            ],
            onTap: () => onOpenInvoice(r.invoiceId),
          ),
      ];
    }
    return [
      for (final r in sorted)
        TwoLineRow(
          key: ValueKey('invoicing-row-${r.invoiceId}'),
          title: r.customerName,
          caption: Text(
            r.dueOn == null
                ? r.number
                : '${r.number} · ${l.invoicingDueOn(format.dates(DateShape.monthDay).format(r.dueOn!))}',
          ),
          amount: format
              .moneyIn(r.currency)
              .formatMinor(
                r.stage == ReceivableStage.paid ? r.totalMinor : r.openMinor,
              ),
          trailing: _chipOf(l, format, r),
          onTap: () => onOpenInvoice(r.invoiceId),
        ),
    ];
  }
}
