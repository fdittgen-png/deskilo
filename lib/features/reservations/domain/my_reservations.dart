// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A person's own reservations as one workspace host answers them
// (`my_reservations_page_v1`): the typed page, the query that asked for it
// and the refusals a reader can meet. Pure Dart: no Flutter, no client.
//
// The decoder is strict. A page of another schema version is incompatible,
// a missing or mistyped field is a shape error, an unknown field is ignored;
// nothing is defaulted silently, because a silent default here would draw a
// person's booking as absent or as the wrong one.
import 'package:meta/meta.dart';

import '../../../core/data/json_reader.dart';
import 'reservation.dart';

/// The one schema this reader understands.
const int _schemaVersion = 1;

/// What a reservation booked: one of the four plan objects.
enum MyReservationPlaceKind {
  seat('seat'),
  desk('desk'),
  office('office'),
  level('level');

  const MyReservationPlaceKind(this.wire);
  final String wire;

  static MyReservationPlaceKind fromWire(String wire, {required String context}) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    throw JsonShapeException(context, 'place_kind', 'a place kind', wire);
  }
}

/// One of the person's own bookings, as the host that holds it answers.
@immutable
class MyReservationItem {
  const MyReservationItem({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.placeKind,
    required this.placeId,
    required this.placeLabel,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.checkedInAt,
    required this.checkedOutAt,
  });

  factory MyReservationItem.fromJson(Object? raw, {required String context}) {
    final r = JsonReader.of(raw, context: context);
    final statusWire = r.string('status');
    final ReservationStatus status;
    try {
      status = reservationStatusFromDb(statusWire);
    } on ArgumentError {
      throw JsonShapeException(context, 'status', 'a reservation status', statusWire);
    }
    return MyReservationItem(
      id: r.string('id'),
      workspaceId: r.string('workspace_id'),
      workspaceName: r.string('workspace_name'),
      placeKind: MyReservationPlaceKind.fromWire(r.string('place_kind'), context: context),
      // Null only for a booking whose place was deleted: the label then
      // carries the substitution snapshot.
      placeId: r.stringOrNull('place_id'),
      placeLabel: r.string('place_label'),
      startsAt: r.dateTime('starts_at').toUtc(),
      endsAt: r.dateTime('ends_at').toUtc(),
      status: status,
      checkedInAt: r.dateTimeOrNull('checked_in_at')?.toUtc(),
      checkedOutAt: r.dateTimeOrNull('checked_out_at')?.toUtc(),
    );
  }

  final String id;
  final String workspaceId;
  final String workspaceName;
  final MyReservationPlaceKind placeKind;
  final String? placeId;

  /// The place's name, or the substitution label of a deleted place; may
  /// be empty for an unnamed seat.
  final String placeLabel;
  final DateTime startsAt;
  final DateTime endsAt;
  final ReservationStatus status;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
}

/// Where the next page starts: the last row of the page before it.
@immutable
class MyReservationsCursor {
  const MyReservationsCursor({required this.afterStart, required this.afterId});

  factory MyReservationsCursor.fromJson(JsonReader r) => MyReservationsCursor(
        afterStart: r.dateTime('after_start').toUtc(),
        afterId: r.string('after_id'),
      );

  final DateTime afterStart;
  final String afterId;

  @override
  bool operator ==(Object other) =>
      other is MyReservationsCursor &&
      other.afterStart == afterStart &&
      other.afterId == afterId;

  @override
  int get hashCode => Object.hash(afterStart, afterId);
}

/// Which way a page walks the person's bookings.
enum MyReservationsDirection {
  ascending('asc'),
  descending('desc');

  const MyReservationsDirection(this.wire);
  final String wire;
}

/// One read: the half-open window `[from, to)`, an optional workspace
/// filter, the direction and the cursor to continue from. Equal queries
/// share one feed; a changed window, filter or direction is a new one.
@immutable
class MyReservationsQuery {
  const MyReservationsQuery({
    required this.from,
    required this.to,
    this.workspaceId,
    this.direction = MyReservationsDirection.ascending,
    this.after,
  });

  final DateTime from;
  final DateTime to;
  final String? workspaceId;
  final MyReservationsDirection direction;
  final MyReservationsCursor? after;

  /// The same read, continued after [cursor].
  MyReservationsQuery continuedAfter(MyReservationsCursor cursor) =>
      MyReservationsQuery(
        from: from,
        to: to,
        workspaceId: workspaceId,
        direction: direction,
        after: cursor,
      );

  /// The parameters of `my_reservations_page_v1`, instants in UTC.
  Map<String, Object?> toRpcParams() => {
        'p_from': from.toUtc().toIso8601String(),
        'p_to': to.toUtc().toIso8601String(),
        'p_workspace_id': workspaceId,
        'p_direction': direction.wire,
        'p_after_start': after?.afterStart.toUtc().toIso8601String(),
        'p_after_id': after?.afterId,
      };

  @override
  bool operator ==(Object other) =>
      other is MyReservationsQuery &&
      other.from == from &&
      other.to == to &&
      other.workspaceId == workspaceId &&
      other.direction == direction &&
      other.after == after;

  @override
  int get hashCode => Object.hash(from, to, workspaceId, direction, after);
}

/// One page of a person's own bookings from one host, with the host it
/// came from attached by the adapter that verified it.
@immutable
class MyReservationsPage {
  const MyReservationsPage({
    required this.source,
    required this.items,
    required this.next,
    required this.hasMore,
  });

  /// The strict read of the wire page. [source] is the installation the
  /// adapter asked, never anything the answer claims.
  factory MyReservationsPage.decode(Object? raw, {required String source}) {
    const context = 'my_reservations_page_v1';
    final r = JsonReader.of(raw, context: context);
    final version = r.integer('schema_version');
    if (version != _schemaVersion) {
      throw MyReservationsRefused(
        MyReservationsFailure.incompatible,
        detail: 'schema_version $version',
      );
    }
    final hasMore = r.raw('has_more');
    if (hasMore is! bool) {
      throw JsonShapeException(context, 'has_more', 'bool', '${hasMore.runtimeType}');
    }
    final itemsRaw = r.raw('items');
    if (itemsRaw is! List) {
      throw JsonShapeException(context, 'items', 'List', '${itemsRaw.runtimeType}');
    }
    final next = r.objectOrNull('next');
    if (hasMore && next == null) {
      throw const JsonShapeException(context, 'next', 'a cursor when has_more', 'null');
    }
    return MyReservationsPage(
      source: source,
      items: List.unmodifiable([
        for (final item in itemsRaw)
          MyReservationItem.fromJson(item, context: '$context.items'),
      ]),
      next: next == null ? null : MyReservationsCursor.fromJson(next),
      hasMore: hasMore,
    );
  }

  /// The installation id the page was read from.
  final String source;
  final List<MyReservationItem> items;
  final MyReservationsCursor? next;
  final bool hasMore;
}

/// Why a read answered nothing usable. Each one is shown in its own words;
/// none of them is a reason to read the window another way.
enum MyReservationsFailure {
  /// The host has no `my_reservations_page_v1`: an older installation.
  unsupported,

  /// The host refused the caller (anonymous, delegated, no right).
  forbidden,

  /// The host refused the question (window, direction, cursor).
  invalid,

  /// The host's registry lacks the personal settings the read needs.
  misconfigured,

  /// The answer did not have the shape this reader understands.
  malformed,

  /// The answer is of another schema version.
  incompatible,

  /// No workspace context: nobody signed in or no workspace selected.
  noContext,
}

/// A typed refusal of the read, carrying the server's detail when one came.
class MyReservationsRefused implements Exception {
  const MyReservationsRefused(this.failure, {this.detail});

  final MyReservationsFailure failure;
  final String? detail;

  @override
  String toString() =>
      'MyReservationsRefused(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// What the host lets a window be: the default span a person starts with
/// and the longest one it answers (`personal.reservation_window_days`,
/// `personal.reservation_max_window_days`), as its registry says.
@immutable
class MyReservationsLimits {
  const MyReservationsLimits({required this.windowDays, required this.maxDays});

  final int windowDays;
  final int maxDays;
}

/// The boundary a page reads through: one host, the caller's own rows.
abstract class MyReservationsRepository {
  /// The host's window limits; a registry without the rows is
  /// [MyReservationsFailure.misconfigured], never a literal.
  Future<MyReservationsLimits> limits();

  /// One page for [query]; throws [MyReservationsRefused] for a typed
  /// refusal and lets a transport failure through unchanged.
  Future<MyReservationsPage> page(MyReservationsQuery query);
}

/// The window a person may ask for: [from] inclusive to [to] exclusive,
/// never longer than [maxDays] (the host's ceiling), with the default span
/// of [defaultDays].
@immutable
class MyReservationsWindow {
  const MyReservationsWindow({
    required this.from,
    required this.to,
    required this.maxDays,
  });

  /// The default window: [defaultDays] local days from the start of today.
  factory MyReservationsWindow.fromToday(
    DateTime now, {
    required int defaultDays,
    required int maxDays,
  }) {
    final start = DateTime(now.year, now.month, now.day);
    return MyReservationsWindow(
      from: start,
      to: DateTime(start.year, start.month, start.day + defaultDays),
      maxDays: maxDays,
    );
  }

  final DateTime from;
  final DateTime to;
  final int maxDays;

  /// The last day the window covers (the day before [to]).
  DateTime get lastDay => DateTime(to.year, to.month, to.day - 1);

  /// The window of the local days [firstDay]..[lastDay] inclusive, cut to
  /// [maxDays] from [firstDay] when it is longer: the host would refuse the
  /// longer one whole, and a person who dragged past the ceiling still gets
  /// the days they can have.
  MyReservationsWindow covering(DateTime firstDay, DateTime lastDay) {
    final from = DateTime(firstDay.year, firstDay.month, firstDay.day);
    var to = DateTime(lastDay.year, lastDay.month, lastDay.day + 1);
    final ceiling = DateTime(from.year, from.month, from.day + maxDays);
    if (to.isAfter(ceiling)) to = ceiling;
    if (!to.isAfter(from)) to = DateTime(from.year, from.month, from.day + 1);
    return MyReservationsWindow(from: from, to: to, maxDays: maxDays);
  }

  @override
  bool operator ==(Object other) =>
      other is MyReservationsWindow &&
      other.from == from &&
      other.to == to &&
      other.maxDays == maxDays;

  @override
  int get hashCode => Object.hash(from, to, maxDays);
}
