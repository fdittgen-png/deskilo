// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's year: the rooms and parking the space sells and rents, and the
// bills they make, from three months back to the last day of the year. A
// visitor opening the demo in October still finds bookings for November and
// December, and a company's finance story: room and parking invoices paid in
// full, paid in part, written off and refunded, and the rent and the utilities
// the space itself pays every month. Everything is placed relative to the
// seeded instant (ADR 0028).
import '../../../features/money/domain/expense_schedule.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/site.dart';
import '../../time/date_text.dart';
import '../data/floor_plan_repository.dart';
import '../data/money_repository.dart';
import '../data/reservation_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_clock.dart';
import 'demo_people_seed.dart';
import 'demo_resource_seed.dart';
import 'demo_space_seed.dart';

String _period(DateTime d) => yearMonth(d.year, d.month);

/// Weekly boardroom meetings, parking slots by the day and a monthly meeting
/// room, from three months back to 31 December.
void seedDemoYearOfResources(
  FakeReservationRepository reservations,
  FakeWorkspaceRepository workspaces,
  DateTime now,
) {
  final today = demoDateOf(now);
  final closed = {
    for (final c in workspaces.closureDays)
      DateTime(c.day.year, c.day.month, c.day.day),
  };
  // One place, one time: the story's own bookings keep their slot.
  final taken = {
    for (final r in reservations.reservations)
      (r.seatId ?? r.officeId, demoDateOf(r.startsAt)),
  };
  final added = <Reservation>[];

  void book(
    String id,
    String member,
    DateTime day,
    int from,
    int to, {
    String? seat,
    String? office,
  }) {
    if (closed.contains(day) || taken.contains((seat ?? office, day))) return;
    taken.add((seat ?? office, day));
    final starts = demoAt(day.year, day.month, day.day, from);
    final ends = demoAt(day.year, day.month, day.day, to);
    final past = !ends.isAfter(now);
    added.add(
      Reservation(
        id: id,
        workspaceId: 'ws-1',
        seatId: seat,
        officeId: office,
        memberId: member,
        startsAt: starts,
        endsAt: ends,
        status: past ? ReservationStatus.completed : ReservationStatus.reserved,
        checkedInAt: past ? starts : null,
        checkedOutAt: past ? ends : null,
      ),
    );
  }

  final end = DateTime(today.year, 12, 31);
  for (
    var day = DateTime(today.year, today.month - 3);
    !day.isAfter(end);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final tag = '${day.year}-${day.month}-${day.day}';
    switch (day.weekday) {
      case DateTime.monday || DateTime.thursday:
        book(
          'demo-y-ev-$tag',
          'member-1',
          day,
          8,
          18,
          seat: DemoResources.slotEv,
        );
      case DateTime.tuesday:
        book(
          'demo-y-p1-$tag',
          'member-2',
          day,
          8,
          18,
          seat: DemoResources.slotStandard,
        );
      case DateTime.wednesday:
        book(
          'demo-y-board-$tag',
          'member-3',
          day,
          10,
          11,
          seat: DemoResources.boardroom,
        );
      case DateTime.friday when day.day <= 7:
        book(
          'demo-y-meeting-$tag',
          'member-3',
          day,
          14,
          16,
          office: DemoSpace.meetingRoom,
        );
    }
  }
  reservations.reservations.addAll(added);
}

/// The sales and purchases money of the year: room and parking invoices in
/// every payment state at the French rates, the rent and the utilities the
/// space pays.
void seedDemoYearOfMoney(FakeMoneyRepository money, DateTime now) {
  _seedUsageInvoices(money, now);
  _seedRefund(money, now);
  _seedOwnCosts(money, now);
}

// France's four rates, as the demo's vat_rates list: 20 standard, 10
// intermediate, 5.5 reduced and the exempt line (Article 261 CGI).
InvoiceLine _line(
  String label,
  int gross,
  double rate, {
  String category = '',
}) => InvoiceLine(
  label: label,
  amountCents: gross,
  vatPercent: rate,
  vatCategory: category,
);

Invoice _usageInvoice(
  String id,
  String member,
  String name,
  DateTime issued,
  List<InvoiceLine> lines,
  int number,
) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: member,
  number: 'U-${_period(issued)}-${twoDigits(number)}',
  issuedAt: issued,
  period: _period(issued),
  title: _period(issued),
  lines: lines,
  totalCents: lines.fold(0, (s, l) => s + l.amountCents),
  currency: 'EUR',
  memberName: name,
  memberAddress: '',
  workspaceName: demoSpaceName,
  workspaceAddress: demoSpaceAddress,
  issuerName: 'Ada Lindqvist',
  signature: 'demo',
  dueOn: issued.add(const Duration(days: 10)),
);

void _pay(
  FakeMoneyRepository money,
  String invoiceId,
  int cents,
  DateTime on,
  String resolution, {
  DateTime? writeoffAt,
}) {
  final member = money.invoices.firstWhere((i) => i.id == invoiceId).memberId;
  final ledgerId = 'demo-pay-$invoiceId';
  money.ledger.add(
    LedgerEntry(
      id: ledgerId,
      memberId: member,
      kind: LedgerKind.credit,
      category: LedgerCategory.payment,
      amountCents: cents,
      description: 'Bank transfer',
      period: _period(on),
      createdAt: on,
      occurredOn: on,
    ),
  );
  money.consumedPaymentIds.add(ledgerId);
  money.invoiceMatchesStore[invoiceId] = InvoiceMatch(
    invoiceId: invoiceId,
    paidCents: cents,
    resolution: resolution,
    paymentLedgerId: ledgerId,
    matchedAt: on,
    byName: 'Ada Lindqvist',
    writeoffAt: writeoffAt,
  );
}

/// Chiara's rooms, Ada's electric slot, Bruno's slot: paid, paid in part,
/// written off and unpaid, with every rate on the page.
void _seedUsageInvoices(FakeMoneyRepository money, DateTime now) {
  final lastMonth = DateTime(now.year, now.month - 1, 28);
  final twoAgo = DateTime(now.year, now.month - 2, 28);
  final threeAgo = DateTime(now.year, now.month - 3, 28);
  // The boardroom and the meeting room at 20 %, a coffee break at 10 %, a
  // printed guide at 5.5 % and a training day the law exempts.
  final rooms = [
    _line('Boardroom, 3 h', 7500, 20),
    _line('Meeting room, 2 h', 8000, 20),
    _line('Coffee break for 8', 1100, 10),
    _line('Printed guide', 1055, 5.5),
    _line('Training day (non-profit)', 5000, 0, category: 'E'),
  ];
  final roomsTotal = rooms.fold(0, (s, l) => s + l.amountCents);
  money.invoices.addAll([
    _usageInvoice(
      'demo-usage-chiara-a',
      'member-3',
      'Chiara Rossi',
      threeAgo,
      rooms,
      1,
    ),
    _usageInvoice(
      'demo-usage-chiara-b',
      'member-3',
      'Chiara Rossi',
      twoAgo,
      rooms,
      1,
    ),
    _usageInvoice(
      'demo-usage-chiara-c',
      'member-3',
      'Chiara Rossi',
      lastMonth,
      rooms,
      1,
    ),
    _usageInvoice('demo-usage-ada-a', 'member-1', 'Ada Lindqvist', twoAgo, [
      _line('Parking P2, 8 days', 4800, 20),
      _line('EV charging, 62 kWh', 2170, 20),
    ], 2),
    _usageInvoice('demo-usage-ada-b', 'member-1', 'Ada Lindqvist', lastMonth, [
      _line('Parking P2, 9 days', 5400, 20),
      _line('EV charging, 71 kWh', 2485, 20),
    ], 2),
    _usageInvoice('demo-usage-bruno', 'member-2', 'Bruno Okafor', lastMonth, [
      _line('Parking P1, 4 days', 2400, 20),
    ], 3),
  ]);
  _pay(
    money,
    'demo-usage-chiara-a',
    roomsTotal,
    threeAgo.add(const Duration(days: 4)),
    'exact',
  );
  // Two months ago she paid 200.00 of 226.55 and the owner wrote the rest off.
  _pay(
    money,
    'demo-usage-chiara-b',
    20000,
    twoAgo.add(const Duration(days: 6)),
    'under_accepted',
    writeoffAt: twoAgo.add(const Duration(days: 20)),
  );
  // Last month she paid half so far.
  _pay(
    money,
    'demo-usage-chiara-c',
    roomsTotal ~/ 2,
    lastMonth.add(const Duration(days: 5)),
    'under_accepted',
  );
  _pay(
    money,
    'demo-usage-ada-a',
    6970,
    twoAgo.add(const Duration(days: 3)),
    'exact',
  );
  money.invoiceReminders['demo-usage-bruno'] = [
    lastMonth.add(const Duration(days: 12)),
  ];
}

/// The credit note of two months ago was refunded by bank transfer.
void _seedRefund(FakeMoneyRepository money, DateTime now) {
  const refundId = 'demo-credit-ada';
  if (!money.invoices.any((i) => i.id == refundId)) return;
  final refunded = DateTime(
    now.year,
    now.month - 2,
    28,
  ).add(const Duration(days: 9));
  money.ledger.add(
    LedgerEntry(
      id: 'demo-refund-ada',
      memberId: 'member-1',
      kind: LedgerKind.charge,
      category: LedgerCategory.refund,
      amountCents: 2000,
      description: 'Refund of the credit note',
      period: _period(refunded),
      createdAt: refunded,
      occurredOn: refunded,
    ),
  );
  money.invoiceMatchesStore[refundId] = InvoiceMatch(
    invoiceId: refundId,
    paidCents: 2000,
    resolution: 'refunded',
    matchedAt: refunded,
    byName: 'Ada Lindqvist',
  );
}

/// The space's own costs: the rent, the internet and the coffee, advanced by
/// the members who pay them and confirmed every month.
void _seedOwnCosts(FakeMoneyRepository money, DateTime now) {
  final first = DateTime(now.year, now.month);
  void schedule(
    String id,
    String member,
    String title,
    int cents,
    DateTime from,
  ) {
    money.expenseSchedules.add(
      ExpenseSchedule(
        id: id,
        workspaceId: 'ws-1',
        memberId: member,
        title: title,
        amountCents: cents,
        startsOn: from,
        unit: ScheduleUnit.month,
        status: ScheduleStatus.active,
        occurrencesDone: (now.year - from.year) * 12 + now.month - from.month,
        nextDue: first,
      ),
    );
    for (
      var month = from;
      !month.isAfter(first);
      month = DateTime(month.year, month.month + 1)
    ) {
      money.expenseOccurrences.add(
        ExpenseOccurrence(
          id: 'demo-occ-$id-${_period(month)}',
          scheduleId: id,
          workspaceId: 'ws-1',
          memberId: member,
          dueOn: month,
          amountCents: cents,
          scheduleTitle: title,
          scheduledAmountCents: cents,
          status: month == first
              ? OccurrenceStatus.awaitingMember
              : OccurrenceStatus.added,
        ),
      );
    }
  }

  // 1,850.00 net of tax plus 20 % VAT.
  schedule(
    'demo-schedule-rent',
    'member-1',
    'Rent of the premises',
    222000,
    DateTime(now.year - 1, 7),
  );
  schedule(
    'demo-schedule-internet',
    'member-3',
    'Fibre internet',
    4900,
    DateTime(now.year - 1, 3),
  );
  schedule(
    'demo-schedule-coffee',
    'member-2',
    'Coffee beans',
    3600,
    DateTime(now.year),
  );
}

/// The two sites of the space in Pézenas: the studio, and the garage with
/// the parking; every invoice and bill carries France's rates.
void seedDemoSites(
  FakeWorkspaceRepository workspaces,
  FakeFloorPlanRepository plan,
) {
  workspaces.sites.addAll(const [
    Site(
      id: 'demo-site-studio',
      workspaceId: 'ws-1',
      name: 'Atelier du Marché',
      street: '4 place du Marché',
      postalCode: '34120',
      city: 'Pézenas',
      countryCode: 'FR',
      legalId: '81234567800017',
      isDefault: true,
    ),
    Site(
      id: 'demo-site-garage',
      workspaceId: 'ws-1',
      name: 'Garage Saint-Jean',
      street: '9 rue Saint-Jean',
      postalCode: '34120',
      city: 'Pézenas',
      countryCode: 'FR',
      legalId: '81234567800025',
      sortOrder: 1,
    ),
  ]);
  const level = 'demo-level-parking';
  plan.levelSites[level] = 'demo-site-garage';
  final i = plan.levels.indexWhere((l) => l.id == level);
  if (i >= 0) {
    plan.levels[i] = plan.levels[i].copyWith(siteId: 'demo-site-garage');
  }
}

/// France's rates on every sales document the other seeds issued: a
/// subscription period is taxed at 20 %, and each invoice states its VAT per
/// rate, exactly as the server freezes it.
void applyDemoVat(FakeMoneyRepository money) {
  final period = RegExp(r'^\d{4}-\d{2}$');
  InvoiceLine taxed(InvoiceLine l) =>
      l.vatPercent == 0 && l.vatCategory.isEmpty && period.hasMatch(l.label)
      ? l.copyWith(vatPercent: 20)
      : l;
  InvoiceVatTotal stated(InvoiceVatTotal t) => t.percent > 0
      ? t
      : InvoiceVatTotal(
          percent: 0,
          category: 'E',
          grossCents: t.grossCents,
          netCents: t.netCents,
          vatCents: t.vatCents,
          exemptionReason: 'Article 261 CGI',
        );
  for (var i = 0; i < money.invoices.length; i++) {
    final invoice = money.invoices[i];
    final lines = invoice.lines.map(taxed).toList();
    money.invoices[i] = invoice.copyWith(
      lines: lines,
      vatTotals: vatTotalsOf(
        [
          for (final l in lines)
            (amountCents: l.amountCents, vatPercent: l.vatPercent),
        ],
        zeroCategory: 'E',
        sellerCountry: 'FR',
      ).map(stated).toList(),
    );
  }
}
