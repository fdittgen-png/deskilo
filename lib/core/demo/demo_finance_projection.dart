// SPDX-License-Identifier: AGPL-3.0-or-later
// The account projection joins memberships to their own workspace's documents.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../features/money/domain/finance_overview.dart';
import 'data/money_repository.dart';
import 'demo_personal_space.dart';

/// The same account-owned projection as the personal RPC, including former
/// members' records. A membership's role never changes document ownership.
FinanceOverview demoFinanceForUser(
  List<DemoPersonalSpace> spaces,
  String? userId,
) {
  final workspaces = [for (final s in spaces) ...s.workspaces.workspaces];
  final names = {for (final w in workspaces) w.id: w.name};
  final zones = {for (final w in workspaces) w.id: w.timezone};
  final parts = [
    for (final space in spaces)
      _overviewOf(space.money, demoMemberIdsFor(space, userId), names, zones),
  ];
  final invoices = [for (final p in parts) ...p.invoices]
    ..sort((a, b) {
      final date = b.issuedAt.compareTo(a.issuedAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
  final reminders = [for (final p in parts) ...p.reminders]
    ..sort((a, b) {
      final date = b.sentAt.compareTo(a.sentAt);
      return date != 0 ? date : b.id.compareTo(a.id);
    });
  return FinanceOverview(invoices: invoices, reminders: reminders);
}

FinanceOverview _overviewOf(
  FakeMoneyRepository money,
  Set<String> members,
  Map<String, String> names,
  Map<String, String> zones,
) {
  final invoices = [
    for (final i in money.invoices)
      if (members.contains(i.memberId) && i.voidedAt == null) i,
  ];
  FinanceInvoice row(Invoice i) {
    final match = money.invoiceMatchesStore[i.id];
    final reminders = money.invoiceReminders[i.id] ?? const <DateTime>[];
    return FinanceInvoice(
      id: i.id,
      workspaceId: i.workspaceId,
      workspaceName: names[i.workspaceId] ?? i.workspaceName,
      number: i.number,
      issuedAt: i.issuedAt,
      dueOn: i.dueOn,
      totalCents: i.totalCents,
      paidCents: match?.paidCents ?? 0,
      currency: i.currency,
      state: _invoiceState(match),
      reminderCount: reminders.length,
      lastReminderAt: reminders.isEmpty ? null : reminders.last,
      timezone: zones[i.workspaceId],
    );
  }

  return FinanceOverview(
    invoices: [
      for (final i in invoices)
        if (i.settledByInvoiceId == null) row(i),
    ],
    reminders: [
      for (final i in invoices)
        for (final (n, sentAt)
            in (money.invoiceReminders[i.id] ?? const <DateTime>[]).indexed)
          FinanceReminder(
            id: '${i.id}-reminder-$n',
            invoiceId: i.id,
            invoiceNumber: i.number,
            workspaceName: names[i.workspaceId] ?? i.workspaceName,
            sentAt: sentAt,
            level: n + 1,
            automatic: true,
            workspaceId: i.workspaceId,
          ),
    ],
  );
}

/// Payment decisions, not amount comparisons, close an invoice. A pending
/// match is still awaiting confirmation even when it covers the face value.
FinanceState _invoiceState(InvoiceMatch? match) => switch (match) {
  null => FinanceState.open,
  InvoiceMatch(pending: true) => FinanceState.awaitingValidation,
  InvoiceMatch(resolution: 'refunded') => FinanceState.refunded,
  InvoiceMatch(resolution: 'under_accepted', writeoffAt: null) =>
    FinanceState.partiallyPaid,
  InvoiceMatch(resolution: 'under_accepted') => FinanceState.closed,
  _ => FinanceState.paid,
};
