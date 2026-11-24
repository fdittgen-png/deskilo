// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — Me › Finances in the demonstration: the acting persona's own
// invoices in every space, read from the same in-memory money the
// workspace's Money pages read, so the two never disagree (the demo used to answer an empty
// overview while Money showed the member's invoices and payments).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:meta/meta.dart';

import '../../features/events/domain/workspace_event.dart';
import '../../features/money/domain/account_activity.dart';
import '../../features/money/domain/billing_rules.dart';
import '../../features/money/domain/finance_overview.dart';
import 'data/account_activity_repository.dart';
import 'data/money_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_ids.dart';
import 'demo_space_routing.dart' show kDemoInstallationId;
import 'demo_spaces.dart';
import 'seed/demo_billing_access_seed.dart';

/// The overview the server's `my_finance_overview` (0380) would answer for
/// the persona [fixture] is acting as.
@visibleForTesting
FinanceOverview demoFinanceOverview(DemoFixture fixture) {
  // Me reads every space the person is in: the main space, Leipzig, London,
  // New York, Zurich and Milan. Each keeps its own currency (euros, pounds,
  // dollars, francs); Me never adds them together (FinanceOverview.owedByCurrency).
  final names = {for (final w in fixture.workspaces.workspaces) w.id: w.name};
  // #3659 — each invoice carries its business's zone, as 0736 answers it.
  final zones = {for (final w in fixture.workspaces.workspaces) w.id: w.timezone};
  final parts = [
    for (final key in DemoSpaceKey.values)
      if (key != DemoSpaceKey.twin)
        _overviewOf(fixture.space(key).money, fixture.actor.memberId, names, zones),
  ];
  return FinanceOverview(
    invoices: [for (final p in parts) ...p.invoices],
    reminders: [for (final p in parts) ...p.reminders],
    // #4164 B2 — the documents of the subjects the account holds a grant for.
    billed: demoBilledInvoices(
      now: fixture.seededAt,
      held: fixture.stores.home.billingAccess.heldSubjects,
      workspaceName: names[demoFirstSpaceId] ?? '',
      timezone: zones[demoFirstSpaceId],
    ),
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
    final claim = _claimOf(money, i);
    final declared = claim != null && claim.startsWith('evt-payment-');
    final open = i.settledByInvoiceId == null && paid < i.totalCents;
    return FinanceInvoice(
      period: i.period,
      inPayment: claim != null,
      claimPaymentId: declared ? null : claim,
      claimCanContinue: money.paymentGateway.continuationState(claim) == 'ready',
      claimPaymentState: _paymentStateOf(money, i),
      claimEventId: declared ? claim : null,
      payable: open && claim == null,
      stillDueCents: open ? i.totalCents - paid : 0,
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

/// The latest original payment keeps its outcome after its active claim ends.
String? _paymentStateOf(FakeMoneyRepository money, Invoice invoice) {
  final prior = money.paymentIntents.where((p) => p.memberId == invoice.memberId &&
      p.claimedInvoiceIds.contains(invoice.id)).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return prior.isEmpty ? null : money.paymentGateway.continuationState(prior.first.orderId);
}

/// #3832 - the persona's own history, derived from the spaces' records.
FakeAccountActivityRepository demoActivityRepository(DemoFixture fixture) =>
    FakeAccountActivityRepository(
      installationId: kDemoInstallationId,
      derive: () => demoFinanceOverview(fixture),
      deriveRows: (kind) => _accountActivity(fixture, kind),
    );

typedef _Space = ({String id, String name, String currency, FakeMoneyRepository money});

/// #3832 - Me > Activity in the demonstration: the acting persona's own
/// invoices, payments and usage, in every space they are in, as the server's
/// my_financial_activity (0304) answers them. Each row keeps its own space's
/// currency; nothing is added across currencies or across people.
List<AccountActivity> _accountActivity(
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
      for (final key in DemoSpaceKey.values)
        space(key.id, fixture.space(key).money),
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
        // #4225 — money that arrived and no invoice has taken yet is said as
        // that, the state the business holds it in (Payments to match).
        status: l.amountCents - (s.money.usedPaymentCents[l.id] ?? 0) > 0
            ? 'awaiting_match'
            : 'confirmed',
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

// #3556 — which payment names [i] in [money]: an online order's claim (by
// its order id) or a declared payment's (by its event id), as 0797 holds
// them; a withdrawn one names nothing, and a declared payment's claim ends
// when the business decides it.
String? _claimOf(FakeMoneyRepository money, Invoice i) => money.claims.entries
    .where((c) => c.value.contains(i.id) && _claimOpen(money, c.key))
    .map((c) => c.key)
    .firstOrNull;

bool _claimOpen(FakeMoneyRepository money, String claim) =>
    !claim.startsWith('evt-payment-') ||
    (money.eventRepository?.events
            .where((e) => e.id == claim)
            .every((e) => e.status == EventStatus.pending) ??
        true);
