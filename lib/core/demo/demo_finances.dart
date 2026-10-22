// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — Me › Finances in the demonstration: the acting persona's own
// invoices in every space, read from the same in-memory money the
// workspace's Money pages read, so the two never disagree (the demo used to answer an empty
// overview while Money showed the member's invoices and payments).
import '../../features/money/domain/billing_rules.dart';
import '../../features/money/domain/finance_overview.dart';
import '../../features/money/domain/invoice.dart';
import 'data/money_repository.dart';
import 'demo_fixture.dart';

/// The overview the server's `my_finance_overview` (0380) would answer for
/// the persona [fixture] is acting as.
FinanceOverview demoFinanceOverview(DemoFixture fixture) {
  // Me reads every space the person is in: the main space and Leipzig.
  final names = {for (final w in fixture.workspaces.workspaces) w.id: w.name};
  final parts = [
    for (final money in [fixture.money, fixture.secondSpace.money])
      _overviewOf(money, fixture.actor.memberId, names),
  ];
  return FinanceOverview(
    invoices: [for (final p in parts) ...p.invoices],
    reminders: [for (final p in parts) ...p.reminders],
  );
}

FinanceOverview _overviewOf(
  FakeMoneyRepository money,
  String me,
  Map<String, String> names,
) {
  final invoices = [
    for (final i in money.invoices)
      if (i.memberId == me &&
          i.voidedAt == null &&
          i.kind != InvoiceKind.settlement &&
          i.totalCents > 0)
        i,
  ];
  FinanceInvoice row(Invoice i) {
    final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
    final reminders = money.invoiceReminders[i.id] ?? const <DateTime>[];
    return FinanceInvoice(
      id: i.id,
      workspaceId: i.workspaceId,
      workspaceName: names[i.workspaceId] ?? i.workspaceName,
      number: i.number,
      issuedAt: i.issuedAt,
      dueOn: i.dueOn,
      totalCents: i.totalCents,
      paidCents: paid,
      currency: i.currency,
      state: i.settledByInvoiceId != null
          ? FinanceState.closed
          : paid <= 0
          ? FinanceState.open
          : paid >= i.totalCents
          ? FinanceState.paid
          : FinanceState.partiallyPaid,
      reminderCount: reminders.length,
      lastReminderAt: reminders.isEmpty ? null : reminders.last,
    );
  }

  return FinanceOverview(
    invoices: [for (final i in invoices) row(i)],
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
          ),
    ],
  );
}
