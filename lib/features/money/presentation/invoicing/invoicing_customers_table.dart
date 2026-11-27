// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 (M1) — the invoicing home's customers at the desk, on the same
// records table as its invoices: a filter, the chips with their counts, the
// footer's total per currency of what the customers shown owe. A row opens
// the customer (so it has no menu of its own); its one action (Remind,
// Confirm, Match) stays a button on the row, as on the customer line before.
// A customer who owes in two currencies
// has a row per currency, so a total never adds two currencies.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/receivables.dart';
import '../../application/receivables_answers.dart';
import 'invoicing_list.dart';
import 'invoicing_words.dart';

/// The chips of the customers' table: the owed buckets. Paid invoices are
/// not a customer's line (the invoices view lists them).
const List<InvoicingFilter> _chips = [
  InvoicingFilter.open,
  InvoicingFilter.notYetDue,
  InvoicingFilter.overdue,
  InvoicingFilter.toConfirm,
];

/// #3773 — an invoice's state in a table cell: its parts (the lateness,
/// then the reminder) are pieces that wrap between each other, never cut.
Widget invoiceStateCell(
  AppLocalizations l,
  AppFormat format,
  Receivable r,
  DateTime today, {
  WrapAlignment alignment = WrapAlignment.start,
}) {
  final status = invoiceStatusOf(r, today);
  final tone = statusToneOf(status.kind);
  return Wrap(
    key: ValueKey('invoicing-state-${r.invoiceId}'),
    alignment: alignment,
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      for (final part in statusPartsOf(l, format, r, status, today))
        StatusChip(label: part, tone: tone, whole: true),
    ],
  );
}

/// A customer's one action as a tonal button, or null when there is none
/// (or a reminder while who holds money is not known).
Widget? customerActionOf(
  AppLocalizations l,
  CustomerLine row, {
  required bool remindersKnown,
  required void Function(String customerId, InvoiceAction action) onAction,
}) {
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
    onPressed: () => onAction(row.customerId, action),
    child: Text(label),
  );
}

/// The customer lines of [invoices], one per customer and currency.
List<CustomerLine> customerLinesByCurrency(
  Iterable<Receivable> invoices, {
  required DateTime today,
  required ReminderMode mode,
  Set<String> holdsUnassigned = const {},
}) => [
  for (final line in customerRowsOf(
    invoices,
    today: today,
    mode: mode,
    holdsUnassigned: holdsUnassigned,
  ))
    if (line.owes.byCurrency.length < 2)
      line
    else
      for (final c in line.owes.byCurrency.keys)
        ...customerRowsOf(
          line.invoices.where((r) => r.currency == c),
          today: today,
          mode: mode,
          holdsUnassigned: holdsUnassigned,
        ),
];

/// The customers at the desk, as the records table.
class InvoicingCustomersTable extends StatelessWidget {
  const InvoicingCustomersTable({
    super.key,
    required this.lines,
    required this.today,
    required this.chip,
    required this.remindersKnown,
    required this.onOpenCustomer,
    required this.onCustomerAction,
  });

  /// The customers, most urgent first ([customerLinesByCurrency]).
  final List<CustomerLine> lines;
  final DateTime today;

  /// The chip the table opens with; null: none (a "To do" entry narrows).
  final InvoicingFilter? chip;

  /// False while who holds money is not known: no Remind is offered.
  final bool remindersKnown;
  final ValueChanged<String> onOpenCustomer;
  final void Function(String customerId, InvoiceAction action) onCustomerAction;

  static String _keyOf(CustomerLine c) => switch (c.owes.byCurrency.keys) {
    final cs when cs.length == 1 => '${c.customerId}-${cs.first}',
    _ => c.customerId,
  };

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
    String owes(CustomerLine c) => [
      for (final e in c.owes.byCurrency.entries)
        format.moneyIn(e.key).formatMinor(e.value),
    ].join(' · ');
    return RecordsTable<CustomerLine>(
      key: ValueKey('invoicing-customers-${chip?.name}'),
      tableId: 'invoicing-customers',
      rows: lines,
      keyOf: _keyOf,
      initialQuery: RecordsQuery(chip: chip?.name),
      searchText: (c) =>
          '${c.customerName} ${[for (final r in c.invoices) r.number].join(' ')}',
      onOpen: (c) => onOpenCustomer(c.customerId),
      empty: Center(child: Text(l.invoicingNothingHere)),
      chips: [
        for (final f in _chips)
          RecordChip(
            id: f.name,
            label: label(f),
            keeps: (c) => c.invoices.any((r) => f.holds(r, today)),
          ),
      ],
      // What the customers shown owe, per currency.
      amountOf: (c) => switch (c.owes.byCurrency.entries) {
        final es when es.length == 1 => (
          currency: es.first.key,
          minor: es.first.value,
        ),
        _ => null,
      },
      amountColumn: 'owes',
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'customer',
          label: l.invoicingColCustomer,
          flex: 4,
          hideable: false,
          sortKey: (c) => c.customerName.toLowerCase(),
          cell: (_, c) => Text(
            c.customerName,
            key: ValueKey('invoicing-customer-${c.customerId}'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        RecordColumn(
          id: 'invoices',
          label: l.featureInvoicing,
          numeric: true,
          flex: 2,
          staysBeside: false,
          sortKey: (c) => c.invoices.length,
          cell: (_, c) => Text('${c.invoices.length}'),
        ),
        RecordColumn(
          id: 'oldest',
          label: l.invoicingColOldest,
          flex: 4,
          sortKey: (c) => -(c.daysLate ?? -1),
          cell: (_, c) => invoiceStateCell(l, format, c.invoices.first, today),
        ),
        RecordColumn(
          id: 'owes',
          label: l.invoicingColOwes,
          numeric: true,
          flex: 3,
          sortKey: (c) =>
              c.owes.byCurrency.values.fold<int>(0, (a, b) => a + b),
          cell: (_, c) => Text(owes(c)),
        ),
        RecordColumn(
          id: 'action',
          label: l.invoicingTodo,
          flex: 3,
          hideable: false,
          cell: (_, c) => Align(
            alignment: AlignmentDirectional.centerEnd,
            child:
                customerActionOf(
                  l,
                  c,
                  remindersKnown: remindersKnown,
                  onAction: onCustomerAction,
                ) ??
                const SizedBox.shrink(),
          ),
        ),
      ],
      cardBuilder: (context, c) => ListTile(
        title: Text(c.customerName, overflow: TextOverflow.ellipsis),
        subtitle: Text(l.invoicingInvoiceCount(c.invoices.length)),
        trailing: Text(owes(c)),
      ),
    );
  }
}
