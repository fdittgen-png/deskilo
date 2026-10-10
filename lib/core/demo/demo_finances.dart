// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — Me › Finances in the demonstration: the acting persona's own
// invoices, read from the same in-memory money the workspace's Money pages
// read, so the two never disagree (the demo used to answer an empty
// overview while Money showed the member's invoices and payments).
import '../../features/money/domain/finance_overview.dart';
import '../../features/money/domain/billing_rules.dart';
import '../../features/money/domain/invoice.dart';
import 'demo_fixture.dart';
import 'seed/demo_people_seed.dart' show demoSpaceName;

/// The overview the server's `my_finance_overview` (0380) would answer for
/// the persona [fixture] is acting as.
FinanceOverview demoFinanceOverview(DemoFixture fixture) {
  final me = fixture.actor.memberId;
  final money = fixture.money;
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
      workspaceName: demoSpaceName,
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
            workspaceName: demoSpaceName,
            sentAt: sentAt,
            level: n + 1,
            automatic: true,
          ),
    ],
  );
}
