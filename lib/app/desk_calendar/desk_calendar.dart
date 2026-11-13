// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3626 (desk M7) — the calendar at the desk, without a widget: which view and
// day an address names, the days a view spans, what the filter row keeps and
// the rows (places) a grid draws. Dates here are business-calendar dates
// (date-only values); instants come from the business's calendar, never the
// device's.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;

import '../../core/i18n/week_start.dart';
import '../../features/plan/domain/floor_plan.dart';
import '../../features/plan/domain/seat.dart';
import '../../features/reservations/domain/reservation.dart';

/// The three periods a desk calendar shows.
enum DeskView { day, week, month }

/// What the calendar page shows of the period.
enum DeskMode {
  /// The grid: places down, the period across (a month as cells).
  grid,

  /// All bookings of the period as a records table.
  table,

  /// The dated feed of everything (bookings, payments, alerts…), as on a
  /// phone.
  agenda,
}

/// The address of the desk calendar: `/calendar?view=week&day=2026-11-12
/// &res=BOOKING`. The booking open beside the grid is part of it, so a
/// reload or a link opens the same thing.
class DeskCalendarAddress {
  const DeskCalendarAddress({
    required this.view,
    required this.day,
    this.mode = DeskMode.grid,
    this.reservationId,
  });

  static const String path = '/calendar';

  final DeskView view;

  /// The day the period is anchored on (date-only).
  final DateTime day;
  final DeskMode mode;

  /// The booking open beside the grid.
  final String? reservationId;

  /// The address [query] names; anything missing or malformed reads as the
  /// default (a week around [today]).
  factory DeskCalendarAddress.parse(
    Map<String, String> query, {
    required DateTime today,
  }) {
    final day = _dayOf(query['day']) ?? today;
    final res = query['res'];
    return DeskCalendarAddress(
      view: DeskView.values.asNameMap()[query['view']] ?? DeskView.week,
      day: day,
      // `/calendar?view=alerts` (where /events lands) is the hub's feed.
      mode: query['view'] == 'alerts'
          ? DeskMode.agenda
          : DeskMode.values.asNameMap()[query['mode']] ?? DeskMode.grid,
      reservationId: res == null || res.isEmpty ? null : res,
    );
  }

  static DateTime? _dayOf(String? text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text ?? '');
    if (m == null) return null;
    final (y, mo, d) = (
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    final day = DateTime(y, mo, d);
    // 2026-02-30 is not a day: a normalised date is not the one named.
    return day.year == y && day.month == mo && day.day == d ? day : null;
  }

  DeskCalendarAddress copyWith({
    DeskView? view,
    DateTime? day,
    DeskMode? mode,
    String? reservationId,
    bool closeReservation = false,
  }) => DeskCalendarAddress(
    view: view ?? this.view,
    day: day ?? this.day,
    mode: mode ?? this.mode,
    reservationId: closeReservation ? null : reservationId ?? this.reservationId,
  );

  /// The address as a location of the app.
  String get location {
    final query = {
      'view': view.name,
      'day': isoDay(day),
      if (mode != DeskMode.grid) 'mode': mode.name,
      'res': ?reservationId,
    };
    return Uri(path: path, queryParameters: query).toString();
  }
}

/// The days a view spans: [from] to [to], half-open, date-only.
typedef DeskSpan = ({DateTime from, DateTime to});

DateTime _plusDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The days [view] spans around [anchor], in the reader's week
/// ([firstWeekday]).
DeskSpan deskSpanOf(DeskView view, DateTime anchor, int firstWeekday) =>
    switch (view) {
      DeskView.day => (from: anchor, to: _plusDays(anchor, 1)),
      DeskView.week => () {
        final first = startOfWeek(anchor, firstWeekday);
        return (from: first, to: _plusDays(first, 7));
      }(),
      DeskView.month => (
        from: DateTime(anchor.year, anchor.month),
        to: DateTime(anchor.year, anchor.month + 1),
      ),
    };

/// The anchor [steps] periods away: a day, a week, a month (the same day of
/// month where the month has it, else its last).
DateTime shiftDeskAnchor(DeskView view, DateTime anchor, int steps) =>
    switch (view) {
      DeskView.day => _plusDays(anchor, steps),
      DeskView.week => _plusDays(anchor, 7 * steps),
      DeskView.month => () {
        final first = DateTime(anchor.year, anchor.month + steps);
        final last = DateTime(first.year, first.month + 1, 0).day;
        return DateTime(
          first.year,
          first.month,
          anchor.day > last ? last : anchor.day,
        );
      }(),
    };

/// The weeks a month grid draws: whole weeks (of the reader's week) from the
/// one holding the month's first day to the one holding its last.
List<List<DateTime>> deskMonthWeeks(DateTime anchor, int firstWeekday) {
  final first = DateTime(anchor.year, anchor.month);
  final last = DateTime(anchor.year, anchor.month + 1, 0);
  var week = startOfWeek(first, firstWeekday);
  final weeks = <List<DateTime>>[];
  while (!week.isAfter(last)) {
    weeks.add([for (var i = 0; i < 7; i++) _plusDays(week, i)]);
    week = _plusDays(week, 7);
  }
  return weeks;
}

/// The filter row's choices. A null field keeps everything.
class DeskFilter {
  const DeskFilter({this.levelId, this.kind, this.memberId, this.status});

  final String? levelId;
  final ResourceKind? kind;
  final String? memberId;
  final ReservationStatus? status;

  bool get isEmpty =>
      levelId == null && kind == null && memberId == null && status == null;

  DeskFilter withLevel(String? id) =>
      DeskFilter(levelId: id, kind: kind, memberId: memberId, status: status);
  DeskFilter withKind(ResourceKind? k) =>
      DeskFilter(levelId: levelId, kind: k, memberId: memberId, status: status);
  DeskFilter withMember(String? id) =>
      DeskFilter(levelId: levelId, kind: kind, memberId: id, status: status);
  DeskFilter withStatus(ReservationStatus? s) =>
      DeskFilter(levelId: levelId, kind: kind, memberId: memberId, status: s);
}

/// What a booking is booked on: its seat, desk, office or level.
String bookingTargetId(Reservation r) =>
    r.seatId ?? r.deskId ?? r.officeId ?? r.levelId ?? '';

/// What a place is, for the filters and the rows.
typedef DeskPlaceFacts = ({
  Map<String, String> levelOf,
  Map<String, ResourceKind> kindOf,
});

/// The bookings [filter] keeps among [all], those overlapping the instants
/// [from] to [to] (half-open), earliest first. Without a state chosen a
/// booking that held its place counts (reserved, checked in, completed); a
/// state chosen shows exactly that state.
///
/// One list serves the grid and the table, so they cannot disagree.
List<Reservation> deskBookingsIn(
  Iterable<Reservation> all,
  DeskFilter filter, {
  required DateTime from,
  required DateTime to,
  required DeskPlaceFacts facts,
}) {
  final seen = <String>{};
  final out = <Reservation>[];
  for (final r in all) {
    if (!seen.add(r.id)) continue;
    if (!(r.startsAt.isBefore(to) && r.endsAt.isAfter(from))) continue;
    if (filter.status != null ? r.status != filter.status : !r.held) continue;
    if (filter.memberId != null && r.memberId != filter.memberId) continue;
    final target = bookingTargetId(r);
    final level = r.levelId ?? facts.levelOf[target];
    if (filter.levelId != null && level != filter.levelId) continue;
    // A booking of an office, a desk or a level is not one kind of place: it
    // stays while no kind is asked for.
    if (filter.kind != null && facts.kindOf[target] != filter.kind) continue;
    out.add(r);
  }
  return out..sort((a, b) {
    final c = a.startsAt.compareTo(b.startsAt);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
}

/// One row of a places-down grid.
class DeskPlace {
  const DeskPlace({
    required this.id,
    required this.name,
    this.levelId,
    this.seat,
  });

  /// The seat, desk, office or level id a booking names.
  final String id;
  final String name;
  final String? levelId;

  /// The seat itself, when the row is one: only a seat is booked from a free
  /// cell.
  final Seat? seat;
}

/// The rows a grid draws for [bookings]: every seat of [plans] that passes the
/// level and kind filters (a free seat is a row to click), then a row for each
/// other place a booking names (an office, a desk, a level) so a booking is
/// drawn once, never repeated on every seat of its office.
List<DeskPlace> deskPlaceRows({
  required List<FloorPlan> plans,
  required DeskFilter filter,
  required List<Reservation> bookings,
  required Map<String, String> names,
  required Map<String, String> levelOf,
}) {
  final rows = <DeskPlace>[];
  final taken = <String>{};
  for (final plan in plans) {
    if (filter.levelId != null && plan.levelId != filter.levelId) continue;
    for (final seat in plan.seats) {
      if (filter.kind != null && seat.resourceKind != filter.kind) continue;
      taken.add(seat.id);
      rows.add(
        DeskPlace(id: seat.id, name: seat.name, levelId: plan.levelId, seat: seat),
      );
    }
  }
  for (final r in bookings) {
    final id = bookingTargetId(r);
    if (id.isEmpty || !taken.add(id)) continue;
    rows.add(
      DeskPlace(
        id: id,
        name: names[id] ?? r.spaceLabel ?? '',
        levelId: r.levelId ?? levelOf[id],
      ),
    );
  }
  return rows;
}

/// The bookings of [place] among [bookings].
Iterable<Reservation> bookingsOfPlace(
  DeskPlace place,
  Iterable<Reservation> bookings,
) => bookings.where((r) => bookingTargetId(r) == place.id);
