// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the money a visitor can walk through: a paid invoice, an
// overdue one with its reminder and a part payment waiting to be matched, an older month, a credit note, the
// payments behind them, VAT rates, a recurring expense with its due
// occurrence and the usage the bookings counted. Every date follows the
// seeded instant.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/einvoice_gateway.dart';
import '../../../features/money/domain/expense_schedule.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/usage_record.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../data/money_repository.dart';
import 'demo_history_seed.dart';
import 'demo_people_seed.dart';

String _period(DateTime d) => yearMonth(d.year, d.month);

/// Completes the money of the session; [seedDemoMoney] already issued
/// last month's two invoices (Ada's and Bruno's).
void seedDemoMoneyStory(
  FakeMoneyRepository money,
  DateTime now,
  List<Reservation> bookings,
) {
  final lastMonth = DateTime(now.year, now.month - 1, 28);
  final twoMonthsAgo = DateTime(now.year, now.month - 2, 28);
  final last = _period(lastMonth);
  final before = _period(twoMonthsAgo);

  // Bruno's bill is overdue: due ten days after issue, reminded once.
  final i = money.invoices.indexWhere((x) => x.id == 'demo-invoice-bruno');
  if (i >= 0) {
    money.invoices[i] = money.invoices[i].copyWith(
      dueOn: lastMonth.add(const Duration(days: 10)),
    );
    // #3292 — reminded two days after it fell due, and only once that day has
    // come: a Demo opened in the first days of a month has the bill not yet
    // due and no reminder dated in its future.
    final reminded = lastMonth.add(const Duration(days: 12));
    if (!reminded.isAfter(now)) {
      money.invoiceReminders['demo-invoice-bruno'] = [reminded];
    }
    // Half of it arrived by transfer yesterday and waits to be matched.
    final yesterday = now.subtract(const Duration(days: 1));
    money.ledger.add(
      LedgerEntry(
        id: 'demo-payment-bruno-unmatched',
        memberId: 'member-2',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: money.invoices[i].totalCents ~/ 2,
        description: 'Bank transfer',
        period: _period(lastMonth),
        createdAt: yesterday,
        occurredOn: yesterday,
      ),
    );
  }

  Invoice invoice(
    String id,
    String member,
    String name,
    String number,
    DateTime issued,
    String period,
    int cents, {
    String? replaces,
    String replacesNumber = '',
  }) => Invoice(
    id: id,
    workspaceId: 'ws-1',
    memberId: member,
    number: number,
    issuedAt: issued,
    period: period,
    title: period,
    lines: [InvoiceLine(label: period, amountCents: cents)],
    totalCents: cents,
    currency: 'EUR',
    memberName: name,
    memberAddress: '',
    workspaceName: demoSpaceName,
    workspaceAddress: demoSpaceAddress,
    issuerName: 'Ada Lindqvist',
    signature: 'demo',
    replacesInvoiceId: replaces,
    replacesNumber: replacesNumber,
    dueOn: issued.add(const Duration(days: 10)),
  );

  // The fee of last month, after the yearly rises of the history.
  int fee(int base) => demoMonthlyCents(base, lastMonth.year, now);
  // Two months back: the history's bill, which a credit note corrects.
  final adaBefore = 'demo-h-inv-member-1-$before';
  money.invoices.addAll([
    invoice(
      'demo-invoice-chiara',
      'member-3',
      'Chiara Rossi',
      demoInvoiceNumber(lastMonth, 3),
      lastMonth,
      last,
      fee(18000),
    ),
    // A credit note: one day of Ada's month before last given back.
    invoice(
      'demo-credit-ada',
      'member-1',
      'Ada Lindqvist',
      'AV-${twoMonthsAgo.year}-0001',
      twoMonthsAgo.add(const Duration(days: 5)),
      before,
      -2000,
      replaces: adaBefore,
      replacesNumber: demoInvoiceNumber(twoMonthsAgo, 1),
    ),
  ]);

  // #3335 — Chiara's invoice was sent to the platform and the answer was
  // lost: the submission is `uncertain`, Send is not offered, and an issuer
  // settles it by hand from the invoice (Demo use case of the resolution).
  money.transmissions['demo-invoice-chiara'] = InvoiceTransmission(
    id: 'demo-transmission-chiara',
    invoiceId: 'demo-invoice-chiara',
    status: EInvoiceSubmissionStatus.uncertain,
    sentAt: lastMonth.add(const Duration(days: 1)),
    provider: 'peppol',
    format: 'peppolBis',
    detail: 'In progress or unresolved - do not resend',
  );

  // The payments behind last month's paid invoices, and their matches.
  void paid(
    String invoiceId,
    String member,
    int cents,
    DateTime on,
    String period,
  ) {
    final ledgerId = 'demo-payment-$invoiceId';
    money.ledger.add(
      LedgerEntry(
        id: ledgerId,
        memberId: member,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: cents,
        description: 'Bank transfer',
        period: period,
        createdAt: on,
        occurredOn: on,
      ),
    );
    money.consumedPaymentIds.add(ledgerId);
    money.invoiceMatchesStore[invoiceId] = InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: cents,
      resolution: 'exact',
      paymentLedgerId: ledgerId,
      matchedAt: on,
      byName: 'Ada Lindqvist',
    );
  }

  paid(
    'demo-invoice-ada',
    'member-1',
    fee(18000),
    lastMonth.add(const Duration(days: 3)),
    last,
  );
  paid(
    'demo-invoice-chiara',
    'member-3',
    fee(18000),
    lastMonth.add(const Duration(days: 5)),
    last,
  );

  // Last month's subscription charges (the history books the others).
  for (final (member, base) in [
    ('member-1', 18000),
    ('member-2', 9000),
    ('member-3', 18000),
  ]) {
    money.ledger.add(
      LedgerEntry(
        id: 'demo-sub-$member-$last',
        memberId: member,
        kind: LedgerKind.charge,
        category: LedgerCategory.subscription,
        amountCents: fee(base),
        description: 'Subscription',
        period: last,
        createdAt: lastMonth,
      ),
    );
  }

  // #3601 — ONE price rule: the fee bands the live statement charges are the
  // plan prices the history invoices (a 50 % plan 90 €, a full plan 180 €,
  // each with the yearly rise), so a member's last invoice and their current
  // month agree for the same plan.
  for (final (index, base) in [(1, 9000), (2, 18000)]) {
    money.feeBands[index] = money.feeBands[index].copyWith(
      feeCents: demoMonthlyCents(base, now.year, now),
    );
  }

  // This month's subscriptions, booked on the first and billed on the
  // 28th: until then the invoicing wizard has them to issue.
  final thisMonth = DateTime(now.year, now.month);
  for (final (member, base) in [
    ('member-1', 18000),
    ('member-2', 9000),
    ('member-3', 18000),
  ]) {
    money.ledger.add(
      LedgerEntry(
        id: 'demo-sub-$member-${_period(thisMonth)}',
        memberId: member,
        kind: LedgerKind.charge,
        category: LedgerCategory.subscription,
        amountCents: demoMonthlyCents(base, now.year, now),
        description: 'Subscription',
        period: _period(thisMonth),
        createdAt: thisMonth,
      ),
    );
  }

  // France's rates (the cast lives in Pézenas): standard, two reduced,
  // and the exempt line.
  money.vatRates = const [
    VatRate(id: 'demo-vat-20', label: 'Standard', percent: 20, isDefault: true),
    VatRate(
      id: 'demo-vat-10',
      label: 'Intermediate',
      percent: 10,
      groupKey: 'reduced',
    ),
    VatRate(
      id: 'demo-vat-55',
      label: 'Reduced',
      percent: 5.5,
      groupKey: 'reduced',
    ),
    VatRate(
      id: 'demo-vat-0',
      label: 'Exempt',
      percent: 0,
      category: 'E',
      groupKey: 'exempt',
      exemptionReason: 'Article 261 CGI',
    ),
  ];

  // A recurring expense Chiara advances every month, and this month's
  // occurrence waiting for her confirmation.
  final firstOfMonth = DateTime(now.year, now.month);
  money.expenseSchedules.add(
    ExpenseSchedule(
      id: 'demo-schedule-cleaning',
      workspaceId: 'ws-1',
      memberId: 'member-3',
      title: 'Cleaning service',
      amountCents: 12000,
      startsOn: DateTime(now.year - 1),
      unit: ScheduleUnit.month,
      status: ScheduleStatus.active,
      occurrencesDone: 12 + now.month - 1,
      nextDue: firstOfMonth,
    ),
  );
  money.expenseOccurrences.add(
    ExpenseOccurrence(
      id: 'demo-occurrence-cleaning',
      scheduleId: 'demo-schedule-cleaning',
      workspaceId: 'ws-1',
      memberId: 'member-3',
      dueOn: firstOfMonth,
      amountCents: 12000,
      scheduleTitle: 'Cleaning service',
      scheduledAmountCents: 12000,
    ),
  );

  // What the bookings counted: every completed booking is a usage line.
  for (final r in bookings) {
    if (r.status != ReservationStatus.completed) continue;
    final minutes = r.endsAt.difference(r.startsAt).inMinutes;
    money.usageRecords.add(
      UsageRecord(
        id: 'demo-usage-${r.id}',
        memberId: r.memberId,
        reservationId: r.id,
        period: _period(r.startsAt),
        reservedFrom: r.startsAt,
        reservedTo: r.endsAt,
        countedMinutes: minutes,
        reservedMinutes: minutes,
        checkedInAt: r.checkedInAt,
        checkedOutAt: r.checkedOutAt,
        actualMinutes: minutes,
      ),
    );
  }
}
