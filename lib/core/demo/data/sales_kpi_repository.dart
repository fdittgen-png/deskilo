// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales figures of a Demo space, computed over that
// space's own invoices and rented rooms by the server's rules (0674): a
// sales line is net of VAT (its own net when it carries one, else its
// gross split at its rate), credits on an invoice are not sales, a credit
// note subtracts; a rented room's margin is what its bookings are charged
// minus its rent falling due or its cost per use. The Demo prices a
// booking by the room's general fees, the cheapest unit, a half day being
// four hours (at most two a day): it keeps no charge record of its own.
import '../../../features/money/domain/billing_rules.dart';
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/room_rental.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/kpi_contract.dart';
import '../../../features/workspace/domain/kpi_sales.dart';
import '../../time/date_text.dart';
import 'room_rental_repository.dart';

class DemoSalesKpiRepository implements SalesKpiRepository {
  DemoSalesKpiRepository({
    required this.invoices,
    required this.rooms,
    required this.bookings,
    required this.roomsEnabled,
    required this.now,
    this.currency = 'EUR',
  });

  final List<Invoice> Function() invoices;
  final FakeRoomRentalRepository rooms;
  final List<Reservation> Function() bookings;

  /// Whether the space rents rooms (`externalRooms`), as the server reads it.
  final bool Function() roomsEnabled;
  final DateTime now;
  final String currency;

  /// A technical bound on the listed rows, as on the server.
  static const _rows = 10;

  /// Credits carried on an invoice: not sales.
  static const _credits = {'payment', 'expense', 'settled_invoice'};

  static String _month(DateTime d) => yearMonth(d.year, d.month);

  static int _net(InvoiceLine l) =>
      l.netCents ?? vatSplit(l.amountCents, l.vatPercent).netCents;

  /// What one booking of [rental] is charged: the cheapest general fee.
  static int? _charge(RoomRental rental, Reservation r) {
    final minutes = r.endsAt.difference(r.startsAt).inMinutes;
    int units(RoomFeeUnit u) => switch (u) {
      RoomFeeUnit.hour => (minutes / 60).ceil(),
      RoomFeeUnit.halfDay => (minutes / 240).ceil().clamp(1, 2),
      RoomFeeUnit.day => 1,
    };
    final totals = [
      for (final f in rental.fees)
        if (f.audience.roleId == null &&
            f.audience.planId == null &&
            f.audience.memberId == null)
          units(f.unit) * f.feeCents,
    ];
    if (totals.isEmpty) return null;
    return totals.reduce((a, b) => a < b ? a : b);
  }

  @override
  Future<SalesQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  }) async {
    bool inRange(String? m) =>
        m != null && m.compareTo(fromMonth) >= 0 && m.compareTo(toMonth) <= 0;
    final documents = [
      for (final i in invoices())
        if (!i.isVoided &&
            i.kind != InvoiceKind.settlement &&
            inRange(i.period))
          i,
    ];
    final mixed =
        documents.any((i) => i.currency != currency) ||
        (roomsEnabled() &&
            rooms.rentals.any(
              (r) =>
                  r.status != RoomRentalStatus.draft && r.currency != currency,
            ));
    int? money(int v) => mixed ? null : v;
    final lines = [
      for (final i in documents)
        for (final l in i.lines)
          if (!_credits.contains(l.kind))
            (invoice: i.id, period: i.period!, line: l),
    ];
    final sales = _Sales.of(lines);
    final partial = toMonth.compareTo(_month(now)) >= 0;
    return SalesQualityKpi(
      fromMonth: fromMonth,
      toMonth: toMonth,
      currency: currency,
      invoices: {for (final x in lines) x.invoice}.length,
      lines: lines.length,
      netMinor: money(sales.net),
      grossMinor: money(sales.gross),
      kinds: sales.kinds(money),
      months: sales.months(money),
      serviceCount: sales.byService.length,
      serviceNetMinor: money(
        sales.byService.values.fold<int>(0, (s, v) => s + v.net),
      ),
      services: sales.services(money, _rows),
      rooms: roomsEnabled()
          ? _margins(fromMonth, toMonth, inRange, money)
          : null,
      quality: {
        if (mixed) KpiQuality.unavailable,
        if (partial) KpiQuality.partial,
      },
      reasons: [
        if (mixed) 'currency_mix',
        if (partial) 'period_not_over',
        if (!roomsEnabled()) 'external_rooms_off',
      ],
      computedAt: now,
    );
  }

  /// The rented rooms of the months, the largest margin first.
  RoomMargins _margins(
    String fromMonth,
    String toMonth,
    bool Function(String? month) inRange,
    int? Function(int v) money,
  ) {
    final first = DateTime.parse('$fromMonth-01');
    final last = DateTime.parse('$toMonth-01');
    final rows =
        <RoomMargin>[
          for (final rental in rooms.rentals)
            if (rental.status != RoomRentalStatus.draft)
              ?_room(rental, first, last, inRange, money),
        ]..sort((a, b) {
          final c = (b.marginMinor ?? 0).compareTo(a.marginMinor ?? 0);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    int sum(int? Function(RoomMargin r) f) =>
        rows.fold<int>(0, (s, r) => s + (f(r) ?? 0));
    return RoomMargins(
      rooms: rows.length,
      uses: rows.fold<int>(0, (s, r) => s + r.uses),
      chargesMinor: money(sum((r) => r.chargesMinor)),
      costMinor: money(sum((r) => r.costMinor)),
      marginMinor: money(sum((r) => r.marginMinor)),
      rows: rows,
    );
  }

  /// One rented room's uses, charges, cost and margin; null for a room
  /// with nothing in the months and not rented in them.
  RoomMargin? _room(
    RoomRental rental,
    DateTime first,
    DateTime last,
    bool Function(String? month) inRange,
    int? Function(int v) money,
  ) {
    var uses = 0, charges = 0;
    for (final b in bookings()) {
      if (b.officeId != rental.officeId ||
          !inRange(_month(b.startsAt)) ||
          b.status == ReservationStatus.cancelled ||
          b.status == ReservationStatus.released) {
        continue;
      }
      if (_charge(rental, b) case final c?) {
        uses++;
        charges += c;
      }
    }
    final cost = rental.costKind == 'per_use'
        ? rental.costCents * uses
        : _rent(rental, first, last);
    final active =
        rental.status == RoomRentalStatus.active &&
        !rental.availableFrom.isAfter(DateTime(last.year, last.month + 1, 0)) &&
        (rental.availableUntil == null ||
            !rental.availableUntil!.isBefore(first));
    if (uses == 0 && cost == 0 && !active) return null;
    return (
      officeId: rental.officeId,
      name: rental.officeName.trim(),
      costKind: rental.costKind,
      uses: uses,
      chargesMinor: money(charges),
      costMinor: money(cost),
      marginMinor: money(charges - cost),
    );
  }

  /// The rent of a fixed-cost room falling due in [first, last] and by now.
  int _rent(RoomRental rental, DateTime first, DateTime last) {
    final step = switch (rental.period) {
      'quarter' => 3,
      'year' => 12,
      _ => 1,
    };
    final until = rental.availableUntil;
    var cost = 0;
    for (
      var m = DateTime(rental.availableFrom.year, rental.availableFrom.month);
      !m.isAfter(last) && !m.isAfter(now);
      m = DateTime(m.year, m.month + step)
    ) {
      if (m.isBefore(first)) continue;
      if (until != null && m.isAfter(until)) break;
      cost += rental.costCents;
    }
    return cost;
  }
}

typedef _Sum = ({int lines, int net, int gross});

/// The sales lines of the months, summed by kind, by month and by service.
class _Sales {
  _Sales._();

  final byKind = <String, _Sum>{};
  final byMonth = <String, ({int net, int gross})>{};
  final byService = <(String, String), _Sum>{};

  static _Sales of(
    List<({String invoice, String period, InvoiceLine line})> lines,
  ) {
    final s = _Sales._();
    _Sum add(_Sum? was, int net, int gross) => (
      lines: (was?.lines ?? 0) + 1,
      net: (was?.net ?? 0) + net,
      gross: (was?.gross ?? 0) + gross,
    );
    for (final x in lines) {
      final kind = x.line.kind.isEmpty ? 'other' : x.line.kind;
      final net = DemoSalesKpiRepository._net(x.line);
      final gross = x.line.amountCents;
      s.byKind[kind] = add(s.byKind[kind], net, gross);
      final m = s.byMonth[x.period] ?? (net: 0, gross: 0);
      s.byMonth[x.period] = (net: m.net + net, gross: m.gross + gross);
      if (kind == 'service' || kind == 'package') {
        final key = (x.line.label.trim(), kind);
        s.byService[key] = add(s.byService[key], net, gross);
      }
    }
    return s;
  }

  int get net => byKind.values.fold<int>(0, (s, k) => s + k.net);
  int get gross => byKind.values.fold<int>(0, (s, k) => s + k.gross);

  List<SalesKind> kinds(int? Function(int v) money) => [
    for (final e
        in byKind.entries.toList()..sort((a, b) {
          final c = b.value.net.compareTo(a.value.net);
          return c != 0 ? c : a.key.compareTo(b.key);
        }))
      (
        kind: e.key,
        lines: e.value.lines,
        netMinor: money(e.value.net),
        grossMinor: money(e.value.gross),
      ),
  ];

  List<SalesMonth> months(int? Function(int v) money) => [
    for (final m in byMonth.keys.toList()..sort())
      (
        month: m,
        netMinor: money(byMonth[m]!.net),
        grossMinor: money(byMonth[m]!.gross),
      ),
  ];

  List<ServiceSales> services(int? Function(int v) money, int rows) {
    final sorted = byService.entries.toList()
      ..sort((a, b) {
        final c = b.value.net.compareTo(a.value.net);
        if (c != 0) return c;
        final n = a.key.$1.compareTo(b.key.$1);
        return n != 0 ? n : a.key.$2.compareTo(b.key.$2);
      });
    return [
      for (final (i, e) in sorted.take(rows).indexed)
        (
          rank: i + 1,
          name: e.key.$1,
          kind: e.key.$2,
          lines: e.value.lines,
          netMinor: money(e.value.net),
          grossMinor: money(e.value.gross),
        ),
    ];
  }
}
