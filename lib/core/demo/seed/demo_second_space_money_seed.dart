// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Leipzig space's money and requests: a monthly bill per member with
// no VAT (the space is a small business exempt under § 19 UStG), the
// transfers that paid them, Ada's bill of this month still open — the one
// Me › Home names beside what she owes nobody at home — and her request
// for two more half-days, waiting for Jonas.
import '../../../features/events/domain/event_decision.dart';
import '../../../features/events/domain/workspace_event.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/service_item.dart';
import '../../time/date_text.dart';
import '../data/event_repository.dart';
import '../data/money_repository.dart';
import 'demo_second_space_seed.dart';

/// The month's fee of each member who has one, in cents.
const _fees = {
  'de-member-jonas': 0,
  'de-member-lena': 19000,
  'de-member-mehmet': 9500,
  'member-1': 9500,
};

String _nameOf(String memberId) =>
    demoSecondCast.firstWhere((p) => p.memberId == memberId).name;

/// Bills of last month (all paid) and of this month (Ada's open), a
/// pay-per-use bill of Bruno's, and the space's small service list.
void seedLeipzigMoney(FakeMoneyRepository money, DateTime now) {
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);
  money
    ..invoices.clear()
    ..services.clear()
    ..services.addAll(const [
      ServiceItem(
        id: 'de-service-coffee',
        workspaceId: demoSecondSpaceId,
        name: 'Kaffee',
        priceCents: 120,
        active: true,
      ),
      ServiceItem(
        id: 'de-service-locker',
        workspaceId: demoSecondSpaceId,
        name: 'Schließfach (Monat)',
        priceCents: 1500,
        active: true,
      ),
    ]);
  var seq = 0;
  String number(DateTime d) =>
      'RE-${d.year}-${(++seq).toString().padLeft(4, '0')}';
  for (final (month, paid) in [(lastMonth, true), (thisMonth, false)]) {
    for (final entry in _fees.entries) {
      if (entry.value == 0) continue;
      final invoice = _invoice(
        'de-inv-${entry.key}-${_period(month)}',
        entry.key,
        number(month),
        month,
        [InvoiceLine(label: _period(month), amountCents: entry.value)],
      );
      money.invoices.add(invoice);
      _charge(money, invoice, 'Mitgliedschaft');
      // Ada's bill of this month is the one still open.
      if (paid || entry.key != 'member-1') _pay(money, invoice, now);
    }
  }
  // Bruno pays per use: two half-days last month.
  final bruno = _invoice(
    'de-inv-member-2-${_period(lastMonth)}',
    'member-2',
    number(lastMonth),
    DateTime(lastMonth.year, lastMonth.month, 28),
    [InvoiceLine(label: _period(lastMonth), amountCents: 3000)],
  );
  money.invoices.add(bruno);
  _charge(money, bruno, 'Halbtage');
  _pay(money, bruno, now);
}

String _period(DateTime d) => yearMonth(d.year, d.month);

Invoice _invoice(
  String id,
  String member,
  String number,
  DateTime issued,
  List<InvoiceLine> lines,
) {
  final total = lines.fold(0, (s, l) => s + l.amountCents);
  return Invoice(
    id: id,
    workspaceId: demoSecondSpaceId,
    memberId: member,
    number: number,
    issuedAt: issued,
    period: _period(issued),
    title: _period(issued),
    lines: lines,
    totalCents: total,
    currency: 'EUR',
    memberName: _nameOf(member),
    memberAddress: '',
    workspaceName: demoSecondSpaceName,
    workspaceAddress: demoSecondSpaceAddress,
    issuerName: 'Jonas Becker',
    signature: 'demo',
    dueOn: issued.add(const Duration(days: 30)),
  );
}

void _charge(FakeMoneyRepository money, Invoice invoice, String what) =>
    money.ledger.add(
      LedgerEntry(
        id: 'de-charge-${invoice.id}',
        memberId: invoice.memberId,
        kind: LedgerKind.charge,
        category: LedgerCategory.subscription,
        amountCents: invoice.totalCents,
        description: what,
        period: _period(invoice.issuedAt),
        createdAt: invoice.issuedAt,
      ),
    );

/// The transfer that paid [invoice] five days after it was issued (or
/// today, when that is still ahead), and its match.
void _pay(FakeMoneyRepository money, Invoice invoice, DateTime now) {
  final day = invoice.issuedAt.add(const Duration(days: 5));
  final on = day.isAfter(now) ? now : day;
  final ledgerId = 'de-payment-${invoice.id}';
  money.ledger.add(
    LedgerEntry(
      id: ledgerId,
      memberId: invoice.memberId,
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: invoice.totalCents,
      description: 'Überweisung',
      period: _period(invoice.issuedAt),
      createdAt: on,
      occurredOn: on,
    ),
  );
  money.consumedPaymentIds.add(ledgerId);
  money.invoiceMatchesStore[invoice.id] = InvoiceMatch(
    invoiceId: invoice.id,
    paidCents: invoice.totalCents,
    resolution: 'exact',
    paymentLedgerId: ledgerId,
    matchedAt: on,
    byName: 'Jonas Becker',
  );
}

/// Ada's request for two more half-days this month, waiting for the
/// owner, and how she joined: her request, confirmed by Jonas.
void seedLeipzigRequests(FakeEventRepository events, DateTime now) {
  events.events
    ..clear()
    ..addAll([
      WorkspaceEvent(
        id: 'de-quota-ada',
        workspaceId: demoSecondSpaceId,
        type: EventType.quota,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: {'half_days': 2, 'period': yearMonth(now.year, now.month)},
        status: EventStatus.pending,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      WorkspaceEvent(
        id: 'de-join-ada',
        workspaceId: demoSecondSpaceId,
        type: EventType.memberJoin,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-1',
        payload: const {'reason': 'demo'},
        status: EventStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 90)),
        decidedAt: now.subtract(const Duration(days: 89)),
      ),
    ]);
  events.decisions.add(
    EventDecision(
      id: 'de-decision-join-ada',
      eventId: 'de-join-ada',
      memberId: 'de-member-jonas',
      accept: true,
      decidedBySystem: false,
      decidedAt: now.subtract(const Duration(days: 89)),
    ),
  );
}
