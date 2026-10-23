// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The workspace data report: the workbook's rows on paper. It reads the
// objects the workbook's sheets are written from ([WorkspaceExportDetails])
// with the workbook's own rules (what a confirmed payment is, what a ledger
// row does to a balance), so every total it prints is the sum of the
// workbook's column for the same rows.
import '../../../core/time/workspace_time.dart';
import 'member.dart';
import 'workspace_data_report.dart';
import 'workspace_excel.dart';

/// The report of [d], with the purchase side the workbook reads from its
/// own records.
WorkspaceDataReport buildWorkspaceDataReport(
  WorkspaceExportDetails d, {
  List<DataReportPurchase> purchases = const [],
  List<DataReportSupplier> suppliers = const [],
}) {
  final days = <DateTime>[
    for (final r in d.reservations) WorkspaceTime.wall(r.startsAt),
    for (final i in d.invoices) WorkspaceTime.wall(i.issuedAt),
    for (final e in d.ledger) WorkspaceTime.wall(e.on),
    for (final p in purchases) ?p.date,
  ]..sort();
  return WorkspaceDataReport(
    workspaceName: d.workspace.name,
    timeZone: d.workspace.timezone,
    currency: d.workspace.currencyCode,
    from: days.firstOrNull,
    to: days.lastOrNull,
    sections: [
      DataReportSection(DataReportPart.members, tables: [_members(d)]),
      DataReportSection(DataReportPart.bookings, tables: [_bookings(d)]),
      DataReportSection(DataReportPart.invoices, tables: [_invoices(d)]),
      DataReportSection(
        DataReportPart.payments,
        tables: [_payments(d), _balances(d)],
      ),
      DataReportSection(
        DataReportPart.purchases,
        tables: [_purchases(purchases), _suppliers(suppliers)],
      ),
      DataReportSection(DataReportPart.plan, levels: _levels(d)),
    ],
  );
}

String _name(WorkspaceExportDetails d, String memberId) =>
    d.memberName[memberId] ?? memberId;

String _roleOf(Member m) => m.isOwner
    ? 'owner'
    : m.isAdmin
    ? 'admin'
    : m.isKiosk
    ? 'kiosk'
    : 'member';

DataReportTable _members(WorkspaceExportDetails d) {
  final members = [...d.members]
    ..sort(
      (a, b) =>
          _name(d, a.id).toLowerCase().compareTo(_name(d, b.id).toLowerCase()),
    );
  return DataReportTable(
    key: 'members',
    columns: const [
      DataReportColumn('member_number', DataReportCell.text),
      DataReportColumn('name', DataReportCell.text),
      DataReportColumn('status', DataReportCell.word),
      DataReportColumn('role', DataReportCell.role),
      DataReportColumn('joined_at', DataReportCell.day),
      DataReportColumn('subscription_pct', DataReportCell.percent),
    ],
    rows: [
      for (final m in members)
        [
          m.memberNumber,
          _name(d, m.id),
          m.status.name,
          _roleOf(m),
          if (m.joinedAt case final at?) WorkspaceTime.wall(at) else null,
          m.subscriptionPct,
        ],
    ],
    totals: [null, members.length, null, null, null, null],
  );
}

/// Bookings by the month they start in, at the workspace's wall clock:
/// all of them (the workbook's Bookings rows), those held (booked or
/// done), those attended (checked in) and those cancelled or released.
DataReportTable _bookings(WorkspaceExportDetails d) {
  final months = <DateTime, List<int>>{};
  final hours = <DateTime, double>{};
  for (final r in d.reservations) {
    final wall = WorkspaceTime.wall(r.startsAt);
    final month = DateTime(wall.year, wall.month);
    final c = months.putIfAbsent(month, () => [0, 0, 0, 0]);
    c[0]++;
    if (r.held) {
      c[1]++;
      hours[month] =
          (hours[month] ?? 0) +
          r.endsAt.difference(r.startsAt).inMinutes / Duration.minutesPerHour;
    } else {
      c[3]++;
    }
    if (r.checkedInAt != null) c[2]++;
  }
  final keys = months.keys.toList()..sort();
  int sum(int i) => months.values.fold(0, (s, c) => s + c[i]);
  return DataReportTable(
    key: 'bookings',
    columns: const [
      DataReportColumn('month', DataReportCell.month),
      DataReportColumn('bookings', DataReportCell.count),
      DataReportColumn('held', DataReportCell.count),
      DataReportColumn('attended', DataReportCell.count),
      DataReportColumn('cancelled', DataReportCell.count),
      DataReportColumn('hours', DataReportCell.hours),
    ],
    rows: [
      for (final m in keys) [m, ...months[m]!, hours[m] ?? 0.0],
    ],
    totals: [
      null,
      sum(0),
      sum(1),
      sum(2),
      sum(3),
      hours.values.fold<double>(0, (s, h) => s + h),
    ],
  );
}

/// The invoice register. A cancelled (voided) invoice is listed and
/// counted in no total; what is open is what remains after the standing
/// payment, nothing for a document settled, refunded or written off.
DataReportTable _invoices(WorkspaceExportDetails d) {
  final invoices = [...d.invoices]
    ..sort((a, b) {
      final byDay = a.issuedAt.compareTo(b.issuedAt);
      return byDay != 0 ? byDay : a.number.compareTo(b.number);
    });
  final totals = List<int>.filled(5, 0);
  final rows = <List<Object?>>[];
  for (final i in invoices) {
    final match = d.invoiceMatches[i.id];
    final paid = match == null || match.pending ? 0 : match.paidCents;
    final closed =
        i.isVoided ||
        i.settledByInvoiceId != null ||
        match?.resolution == 'refunded' ||
        match?.writeoffAt != null;
    final open = closed ? 0 : i.totalCents - paid;
    final amounts = [i.netCents, i.vatCents, i.totalCents, paid, open];
    if (!i.isVoided) {
      for (var k = 0; k < amounts.length; k++) {
        totals[k] += amounts[k];
      }
    }
    rows.add([
      i.number,
      d.memberName[i.memberId] ?? i.memberName,
      WorkspaceTime.wall(i.issuedAt),
      i.period ?? '',
      i.kind.name,
      ...amounts,
      if (i.voidedAt case final at?) WorkspaceTime.wall(at) else null,
    ]);
  }
  return DataReportTable(
    key: 'invoices',
    columns: const [
      DataReportColumn('number', DataReportCell.text),
      DataReportColumn('member', DataReportCell.text),
      DataReportColumn('issued_at', DataReportCell.day),
      DataReportColumn('period', DataReportCell.text),
      DataReportColumn('kind', DataReportCell.word),
      DataReportColumn('net', DataReportCell.money),
      DataReportColumn('vat', DataReportCell.money),
      DataReportColumn('total', DataReportCell.money),
      DataReportColumn('paid', DataReportCell.money),
      DataReportColumn('open', DataReportCell.money),
      DataReportColumn('voided_at', DataReportCell.day),
    ],
    rows: rows,
    totals: [null, null, null, null, null, ...totals, null],
  );
}

/// The confirmed member payments: the workbook's `confirmed` Payments rows.
DataReportTable _payments(WorkspaceExportDetails d) {
  final paid = [
    for (final e in d.ledger)
      if (isExportedPayment(e)) e,
  ]..sort((a, b) => a.on.compareTo(b.on));
  return DataReportTable(
    key: 'payments',
    columns: const [
      DataReportColumn('occurred_on', DataReportCell.day),
      DataReportColumn('member', DataReportCell.text),
      DataReportColumn('period', DataReportCell.text),
      DataReportColumn('description', DataReportCell.text),
      DataReportColumn('amount', DataReportCell.money),
    ],
    rows: [
      for (final e in paid)
        [
          WorkspaceTime.wall(e.on),
          _name(d, e.memberId),
          e.period,
          e.description,
          e.amountCents,
        ],
    ],
    totals: [
      null,
      null,
      null,
      null,
      paid.fold<int>(0, (s, e) => s + e.amountCents),
    ],
  );
}

/// Each member's account: what was charged, what settled it, and the
/// balance the Ledger sheet's signed amounts sum to.
DataReportTable _balances(WorkspaceExportDetails d) {
  final byMember = <String, List<int>>{};
  for (final e in d.ledger) {
    final c = byMember.putIfAbsent(e.memberId, () => [0, 0, 0]);
    final signed = exportedSignedCents(e);
    c[signed >= 0 ? 0 : 1] += signed.abs();
    c[2] += signed;
  }
  final ids = byMember.keys.toList()
    ..sort(
      (a, b) => _name(d, a).toLowerCase().compareTo(_name(d, b).toLowerCase()),
    );
  int sum(int i) => byMember.values.fold(0, (s, c) => s + c[i]);
  return DataReportTable(
    key: 'balances',
    columns: const [
      DataReportColumn('member', DataReportCell.text),
      DataReportColumn('charges', DataReportCell.money),
      DataReportColumn('credits', DataReportCell.money),
      DataReportColumn('balance', DataReportCell.money),
    ],
    rows: [
      for (final id in ids) [_name(d, id), ...byMember[id]!],
    ],
    totals: [null, sum(0), sum(1), sum(2)],
  );
}

const _uncountedPurchaseStates = {'rejected', 'cancelled'};

/// The purchase documents. A credit note reduces what was bought; a
/// refused or cancelled document is listed and counted in no total.
DataReportTable _purchases(List<DataReportPurchase> purchases) {
  final sorted = [...purchases]
    ..sort((a, b) => (a.date ?? DateTime(0)).compareTo(b.date ?? DateTime(0)));
  int signed(DataReportPurchase p) =>
      p.kind == 'credit_note' ? -p.grossCents : p.grossCents;
  return DataReportTable(
    key: 'purchases',
    columns: const [
      DataReportColumn('occurred_on', DataReportCell.day),
      DataReportColumn('reference', DataReportCell.text),
      DataReportColumn('kind', DataReportCell.word),
      DataReportColumn('state', DataReportCell.word),
      DataReportColumn('category', DataReportCell.text),
      DataReportColumn('total', DataReportCell.money),
    ],
    rows: [
      for (final p in sorted)
        [p.date, p.reference, p.kind, p.state, p.category, signed(p)],
    ],
    totals: [
      null,
      sorted.length,
      null,
      null,
      null,
      sorted
          .where((p) => !_uncountedPurchaseStates.contains(p.state))
          .fold<int>(0, (s, p) => s + signed(p)),
    ],
  );
}

DataReportTable _suppliers(List<DataReportSupplier> suppliers) {
  final sorted = [...suppliers]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return DataReportTable(
    key: 'suppliers',
    columns: const [
      DataReportColumn('number', DataReportCell.text),
      DataReportColumn('name', DataReportCell.text),
      DataReportColumn('vat_id', DataReportCell.text),
      DataReportColumn('city', DataReportCell.text),
      DataReportColumn('country', DataReportCell.text),
      DataReportColumn('status', DataReportCell.word),
    ],
    rows: [
      for (final s in sorted)
        [s.number, s.name, s.taxId, s.city, s.country, s.status],
    ],
    totals: [null, sorted.length, null, null, null, null],
  );
}

/// Every level in its order: each room, then its tables, with the places
/// they hold, whether they are booked whole and their price.
List<DataReportLevel> _levels(WorkspaceExportDetails d) {
  final levels = [...d.levels]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [
    for (final level in levels)
      if (d.plansByLevel[level.id] case final plan?)
        DataReportLevel(
          levelId: level.id,
          name: level.name,
          wholePriceCents: level.bookableAsWhole ? level.priceCents : null,
          table: _places(level.id, [
            for (final office in plan.offices)
              (
                office: office.name,
                desks: [
                  for (final desk in plan.desksOf(office.id))
                    (
                      name: desk.name,
                      seats: plan.seatsOf(desk.id).length,
                      whole: desk.bookableAsWhole,
                      price: desk.priceCents,
                    ),
                ],
                whole: office.bookableAsWhole,
                price: office.priceCents,
              ),
          ]),
        ),
  ];
}

typedef _Desk = ({String name, int seats, bool whole, int price});
typedef _Room = ({String office, List<_Desk> desks, bool whole, int price});

DataReportTable _places(String levelId, List<_Room> rooms) {
  var seats = 0;
  final rows = <List<Object?>>[];
  for (final room in rooms) {
    final inRoom = room.desks.fold<int>(0, (s, desk) => s + desk.seats);
    seats += inRoom;
    rows.add([room.office, '', inRoom, room.whole, room.price]);
    for (final desk in room.desks) {
      rows.add(['', desk.name, desk.seats, desk.whole, desk.price]);
    }
  }
  return DataReportTable(
    key: 'places_$levelId',
    columns: const [
      DataReportColumn('office', DataReportCell.text),
      DataReportColumn('desk', DataReportCell.text),
      DataReportColumn('seats', DataReportCell.count),
      DataReportColumn('bookable_as_whole', DataReportCell.flag),
      DataReportColumn('price', DataReportCell.money),
    ],
    rows: rows,
    totals: [null, null, seats, null, null],
  );
}
