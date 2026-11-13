// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 (desk M1) — the invoicing home's invoices at the desk: a records
// table (#3606) of customer, number, status, due and open; the filters as
// chips with their counts; the footer adds what is open, one total per
// currency, so the open amount is exactly the open rows. A row opens its
// invoice beside the table; its menu opens the customer or shares the
// invoice's reminder. Several reminders are shared from a selection, one
// after the other, through the reminder queue and its states (the decision
// on #3614): never a "send selected" call.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/view_toggle.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_home.dart';
import 'invoicing_home_parts.dart';
import 'invoicing_list.dart';
import 'invoicing_words.dart';

/// What the desk table does with a row or a selection.
typedef _DeskActions = ({
  ValueChanged<String> openInvoice,
  ValueChanged<String> openCustomer,

  /// Shares the reminder of the invoice [id] (its row's menu).
  ValueChanged<String> remind,

  /// Shares the reminders of the invoices [ids], one after the other.
  ValueChanged<Set<String>> shareReminders,
});

/// The chips, in their order: the owed buckets, then what was paid.
const List<InvoicingFilter> _chips = [
  InvoicingFilter.open,
  InvoicingFilter.notYetDue,
  InvoicingFilter.overdue,
  InvoicingFilter.toConfirm,
  InvoicingFilter.paid,
];

class _DeskTable extends StatelessWidget {
  const _DeskTable({
    super.key,
    required this.receivables,
    required this.today,
    required this.mode,
    required this.filter,
    required this.actions,
    this.remindersKnown = true,
    this.holdsUnassigned = const {},
    this.onShown,
  });

  final List<Receivable> receivables;
  final DateTime today;
  final ReminderMode mode;

  /// The chip the table opens with (a legend line or More chose it).
  final InvoicingFilter filter;
  final _DeskActions actions;

  /// False while who holds money is not known: nobody is reminded.
  final bool remindersKnown;

  /// The customers who hold money not assigned: matched, never reminded.
  final Set<String> holdsUnassigned;

  /// The invoices shown, in their order.
  final ValueChanged<List<String>>? onShown;

  /// Whether [r]'s reminder is shared by hand now.
  bool _remindable(Receivable r) =>
      remindersKnown &&
      !holdsUnassigned.contains(r.customerId) &&
      reminderToShare(r, mode);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    String label(InvoicingFilter f) => switch (f) {
      InvoicingFilter.open => l.invoicingFilterOpen,
      InvoicingFilter.notYetDue => l.invoicingOwedNotYetDue,
      InvoicingFilter.overdue => l.invoicingFilterOverdue,
      InvoicingFilter.toConfirm => l.journeyStageConfirm,
      InvoicingFilter.paid => l.invoicingFilterPaid,
    };
    return RecordsTable<Receivable>(
      key: ValueKey('invoicing-table-${filter.name}'),
      tableId: 'invoicing-home',
      rows: receivables,
      keyOf: (r) => r.invoiceId,
      onShown: onShown,
      initialQuery: RecordsQuery(chip: filter.name, sortColumn: 'due'),
      searchText: (r) => '${r.customerName} ${r.number}',
      onOpen: (r) => actions.openInvoice(r.invoiceId),
      empty: Center(child: Text(l.invoicingNothingHere)),
      chips: [
        for (final f in _chips)
          RecordChip(
            id: f.name,
            label: label(f),
            keeps: (r) => f.holds(r, today),
          ),
      ],
      // What is open, per currency: the footer's total is the open rows.
      amountOf: (r) => (currency: r.currency, minor: r.openMinor),
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'customer',
          label: l.invoicingColCustomer,
          flex: 4,
          hideable: false,
          sortKey: (r) => r.customerName.toLowerCase(),
          cell: (_, r) => Text(r.customerName, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'number',
          label: l.invoicingColInvoice,
          flex: 3,
          sortKey: (r) => r.number,
          cell: (_, r) => Text(r.number, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'status',
          label: l.invoicingColStatus,
          flex: 4,
          sortKey: (r) => invoiceStatusOf(r, today).kind.index,
          cell: (_, r) => _status(context, format, r),
        ),
        RecordColumn(
          id: 'due',
          label: l.invoicingColDue,
          flex: 2,
          sortKey: (r) => r.dueOn ?? r.issuedOn,
          cell: (_, r) => Text(
            r.dueOn == null
                ? ''
                : format.dates(DateShape.monthDay).format(r.dueOn!),
          ),
        ),
        RecordColumn(
          id: 'open',
          label: l.invoicingColOpen,
          numeric: true,
          flex: 3,
          sortKey: (r) => r.openMinor,
          cell: (_, r) =>
              Text(format.moneyIn(r.currency).formatMinor(r.openMinor)),
        ),
      ],
      rowActions: (r) => [
        RecordAction(
          id: 'customer',
          label: l.invoicingColCustomer,
          icon: Icons.person_outline,
          onRun: (r) => actions.openCustomer(r.customerId),
        ),
        if (_remindable(r))
          RecordAction(
            id: 'remind',
            label: l.invoicingActionRemind,
            icon: Icons.notifications_active_outlined,
            onRun: (r) => actions.remind(r.invoiceId),
          ),
      ],
      bulkActions: [
        if (remindersKnown && mode == ReminderMode.byHand)
          RecordBulkAction(
            id: 'remind',
            label: l.invoicingShareRemindersSelected,
            icon: Icons.notifications_active_outlined,
            onRun: actions.shareReminders,
          ),
      ],
      cardBuilder: (context, r) => ListTile(
        title: Text(r.customerName, overflow: TextOverflow.ellipsis),
        subtitle: Text(r.number),
        trailing: Text(format.moneyIn(r.currency).formatMinor(r.openMinor)),
      ),
    );
  }

  /// #3773 — a state in a table cell is never cut: its parts wrap.
  Widget _status(BuildContext context, AppFormat format, Receivable r) {
    final l = context.l10n;
    final status = invoiceStatusOf(r, today);
    final tone = statusToneOf(status.kind);
    return Wrap(
      key: ValueKey('invoicing-state-${r.invoiceId}'),
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final part in statusPartsOf(l, format, r, status, today))
          StatusChip(label: part, tone: tone, whole: true),
      ],
    );
  }
}

/// The home at the desk: [header] (the owed card and "To do") above, taking
/// at most half the page and scrolling inside it, and the [table] filling
/// the rest, so the table keeps its header and footer in sight.
class _DeskLayout extends StatelessWidget {
  const _DeskLayout({required this.header, required this.table});

  final List<Widget> header;
  final Widget table;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Column(
      key: const ValueKey('invoicing-home'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: box.maxHeight * _headerShare),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: header,
            ),
          ),
        ),
        Expanded(child: table),
      ],
    ),
  );
}

/// The most of the page the cards above the table take.
const double _headerShare = 0.5;

/// The cards the desk shows above the table.
typedef InvoicingDeskCards = ({
  Widget owed,
  Widget todo,
  List<Widget>? legalNotes,
});

/// #3614 — the home at the desk: the failed sources, the owed card and
/// "To do" above; the invoices as a records table, narrowed to the "To do"
/// entry chosen ([todo]) until [onClearTodo].
class InvoicingDeskHome extends StatelessWidget {
  const InvoicingDeskHome({
    super.key,
    required this.data,
    required this.actions,
    required this.filter,
    required this.cards,
    required this.onView,
    this.todo,
    this.onClearTodo,
    this.onShown,
    this.customers,
  });

  /// The list by customer, as on a phone (#3587); null: the invoices, as
  /// the records table.
  final Widget? customers;

  /// Switches between the customers and the invoices.
  final ValueChanged<InvoicingView> onView;

  final InvoicingHomeData data;
  final InvoicingHomeActions actions;
  final InvoicingFilter filter;
  final InvoicingDeskCards cards;
  final ({TodoKind kind, String title})? todo;
  final VoidCallback? onClearTodo;
  final ValueChanged<List<String>>? onShown;

  @override
  Widget build(BuildContext context) {
    final kind = todo?.kind;
    return _DeskLayout(
      header: [
        for (final s in data.failed) ...[
          InvoicingFailedSource(source: s, onRetry: () => actions.onRetry(s)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.md,
          children: [
            Expanded(child: cards.owed),
            Expanded(child: cards.todo),
          ],
        ),
        if (cards.legalNotes case final notes?)
          ExpansionTile(
            key: const ValueKey('invoicing-legal-notes'),
            title: Text(context.l10n.invoicingLegalNotes),
            tilePadding: EdgeInsets.zero,
            children: notes,
          ),
        // The list by customer shows the "To do" entry itself.
        if (todo case (:final title, kind: _) when customers == null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InputChip(
              key: const ValueKey('invoicing-todo-selected'),
              label: Text(title),
              selected: true,
              onDeleted: onClearTodo,
            ),
          ),
      ],
      table: switch (customers) {
        final list? => CustomScrollView(slivers: [list]),
        null => _invoices(context, kind),
      },
    );
  }

  /// The invoices as the records table, under the switch back to customers.
  Widget _invoices(BuildContext context, TodoKind? kind) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ViewToggle<InvoicingView>(
              key: const ValueKey('invoicing-view'),
              selected: InvoicingView.invoices,
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
          ),
        ),
        Expanded(
          child: _DeskTable(
            key: ValueKey('invoicing-desk-${kind?.name}'),
            receivables: [
              for (final r in data.receivables)
                if (kind == null ||
                    todoKindOf(
                          r,
                          data.mode,
                          holdsUnassigned: data.holdsUnassigned,
                        ) ==
                        kind)
                  r,
            ],
            today: data.today,
            mode: data.mode,
            filter: filter,
            remindersKnown: data.creditsKnown,
            holdsUnassigned: data.holdsUnassigned,
            onShown: onShown,
            actions: (
              openInvoice: actions.onOpenInvoice,
              openCustomer: actions.onOpenCustomer,
              remind: actions.onRemind ?? (_) {},
              shareReminders: actions.onShareReminders ?? (_) {},
            ),
          ),
        ),
      ],
    );
  }
}
