// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — Me › Finances in the demonstration: the acting persona's own
// invoices in every space, read from the same in-memory money the
// workspace's Money pages read, so the two never disagree (the demo used to answer an empty
// overview while Money showed the member's invoices and payments).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../features/money/domain/account_activity.dart';
import '../../features/money/domain/billing_rules.dart';
import '../../features/money/domain/finance_overview.dart';
import '../../features/money/domain/ledger_entry.dart';
import 'data/account_activity_repository.dart';
import 'data/money_repository.dart';
import 'demo_fixture.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_new_york_seed.dart';
import 'seed/demo_second_space_seed.dart';
import 'seed/demo_trade_city_seed.dart';

/// The overview the server's `my_finance_overview` (0380) would answer for
/// the persona [fixture] is acting as.
FinanceOverview demoFinanceOverview(DemoFixture fixture) {
  // Me reads every space the person is in: the main space, Leipzig, London,
  // New York, Zurich and Milan. Each keeps its own currency (euros, pounds,
  // dollars, francs); Me never adds them together (FinanceOverview.owedByCurrency).
  final names = {for (final w in fixture.workspaces.workspaces) w.id: w.name};
  // #3659 — each invoice carries its business's zone, as 0736 answers it.
  final zones = {for (final w in fixture.workspaces.workspaces) w.id: w.timezone};
  final parts = [
    for (final money in [
      fixture.money,
      fixture.secondSpace.money,
      fixture.london.money,
      fixture.newYork.money,
      fixture.zurich.money,
      fixture.milan.money,
    ])
      _overviewOf(money, fixture.actor.memberId, names, zones),
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
  Map<String, String> zones,
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
      timezone: zones[i.workspaceId],
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

/// #3832 - the persona's own history, derived from the spaces' records.
FakeAccountActivityRepository demoActivityRepository(DemoFixture fixture) =>
    FakeAccountActivityRepository(
      derive: () => demoFinanceOverview(fixture),
      deriveRows: (kind) => demoAccountActivity(fixture, kind),
    );

typedef _Space = ({String id, String name, String currency, FakeMoneyRepository money});

/// #3832 - Me > Activity in the demonstration: the acting persona's own
/// invoices, payments and usage, in every space they are in, as the server's
/// my_financial_activity (0304) answers them. Each row keeps its own space's
/// currency; nothing is added across currencies or across people.
List<AccountActivity> demoAccountActivity(
  DemoFixture fixture,
  AccountActivityKind kind,
) {
  final me = fixture.actor.memberId;
  final rows = {for (final w in fixture.workspaces.workspaces) w.id: w};
  _Space space(String id, FakeMoneyRepository money) => (
    id: id,
    name: rows[id]?.name ?? id,
    currency: rows[id]?.currencyCode ?? '',
    money: money,
  );
  return [
    for (final s in [
      space(demoFirstSpaceId, fixture.money),
      space(demoSecondSpaceId, fixture.secondSpace.money),
      space(demoLondonSpaceId, fixture.london.money),
      space(demoNewYorkSpaceId, fixture.newYork.money),
      space(demoZurichSpaceId, fixture.zurich.money),
      space(demoMilanSpaceId, fixture.milan.money),
    ])
      ...switch (kind) {
        AccountActivityKind.invoices => _invoiceRows(s, me),
        AccountActivityKind.payments => _paymentRows(s, me),
        AccountActivityKind.usage => _usageRows(s, me),
      },
  ];
}

List<AccountActivity> _invoiceRows(_Space s, String me) => [
  for (final i in s.money.invoices)
    if (i.memberId == me)
      AccountActivity(
        id: i.id,
        workspaceId: i.workspaceId,
        workspaceName: s.name,
        occurredAt: i.issuedAt,
        reference: i.number,
        description: i.title,
        currency: i.currency,
        status: i.voidedAt != null
            ? 'voided'
            : i.settledByInvoiceId != null
            ? 'regrouped'
            : 'issued',
        amountCents: i.totalCents,
      ),
];

List<AccountActivity> _paymentRows(_Space s, String me) => [
  for (final l in s.money.ledger)
    if (l.memberId == me &&
        l.category == LedgerCategory.payment &&
        l.kind == LedgerKind.credit)
      AccountActivity(
        id: l.id,
        workspaceId: s.id,
        workspaceName: s.name,
        occurredAt: l.createdAt,
        reference: '',
        description: l.description,
        currency: s.currency,
        status: 'confirmed',
        amountCents: l.amountCents,
      ),
];

List<AccountActivity> _usageRows(_Space s, String me) => [
  for (final u in s.money.usageRecords)
    if (u.memberId == me)
      AccountActivity(
        id: u.id,
        workspaceId: s.id,
        workspaceName: s.name,
        occurredAt: u.reservedFrom,
        reference: '',
        description: u.spaceLabel,
        currency: s.currency,
        status: u.basis.name,
        minutes: u.countedMinutes,
      ),
];
