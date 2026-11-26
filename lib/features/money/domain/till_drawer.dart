// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the cash drawer of a till: a session is opened with its float, cash is paid in and out of it, and it is
// closed on a count. The server (`counter_till_save_v1`, `counter_session_open_v1`, `counter_cash_entry_v1`,
// `counter_session_expected_v1`, `counter_session_close_v1`) keeps the figures; this file is what it answers and the port
// the screens use. Amounts are MINOR units; a denomination is the value of one note or coin in minor units, counted.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import 'till_day.dart';

/// One session of a till, open: the float it started with and who opened it.
class DrawerSession {
  const DrawerSession({required this.id, required this.tillId, required this.floatMinor, required this.openedByMemberId});

  final String id;
  final String tillId;
  final int floatMinor;
  final String openedByMemberId;
}

/// A till of the business and the session open on it, when one is.
class DrawerTill {
  const DrawerTill({required this.id, required this.name, required this.active, this.siteId, this.sellingPlaceId, this.session});

  final String id;
  final String name;
  final bool active;
  final String? siteId;

  /// The place this till sells from, with every place below it; null when it sells from the business's selling place.
  final String? sellingPlaceId;

  /// The open session the person may read; null when none is open (or it is another cashier's, which they do not read).
  final DrawerSession? session;

  bool get isOpen => session != null;

  factory DrawerTill.fromJson(Object? json, {DrawerSession? session}) {
    final r = JsonReader.of(json, context: 'counter_tills');
    return DrawerTill(
      id: r.string('id'),
      name: r.string('name'),
      active: r.boolOr('active', fallback: true),
      siteId: r.stringOrNull('site_id'),
      sellingPlaceId: r.stringOrNull('selling_place_id'),
      session: session,
    );
  }

  factory DrawerTill.saved(Object? json) {
    final r = JsonReader.of(json, context: 'counter_till_save');
    return DrawerTill(
      id: r.string('till_id'),
      name: r.string('name'),
      active: r.boolOr('active', fallback: true),
      siteId: r.stringOrNull('site_id'),
      sellingPlaceId: r.stringOrNull('selling_place_id'),
    );
  }
}

/// A place a till may sell from: its code, its name and the codes from the top of its store down to it.
class TillSellingPlace {
  const TillSellingPlace({required this.id, required this.code, this.name = '', this.path = const []});

  factory TillSellingPlace.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_selling_places');
    return TillSellingPlace(
      id: r.string('id'),
      code: r.string('code'),
      name: r.stringOr('name'),
      path: [for (final c in r.list('path')) '$c'],
    );
  }

  final String id;
  final String code;
  final String name;
  final List<String> path;

  /// Where the place is, as a person reads it: its codes from the top down, then its name when it has one.
  String get label {
    final address = path.isEmpty ? code : path.join(' / ');
    return name.isEmpty ? address : '$address · $name';
  }
}

/// The places a till may be given, and the one the business sells from when a till names none (`counter_selling_places_v1`).
class TillSellingPlaces {
  const TillSellingPlaces({required this.defaultCode, required this.places});

  factory TillSellingPlaces.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_selling_places');
    return TillSellingPlaces(
      defaultCode: r.string('default_code'),
      places: [for (final p in r.list('places')) TillSellingPlace.fromJson(p)],
    );
  }

  /// The code of the business's selling place (the setting `counter.selling_place`).
  final String defaultCode;
  final List<TillSellingPlace> places;
}

/// An open session row as the table gives it.
DrawerSession drawerSessionFromRow(Object? json) {
  final r = JsonReader.of(json, context: 'counter_till_sessions');
  return DrawerSession(id: r.string('id'), tillId: r.string('till_id'), floatMinor: _minor(r, 'float_minor'), openedByMemberId: r.stringOr('opened_by_member_id'));
}

/// Minor units as the server sends them: a number or a text.
int _minor(JsonReader r, String key) => int.parse('${r.raw(key)}');

/// What the drawer should hold, derived by the server from what happened in the session.
class DrawerCash {
  const DrawerCash({
    required this.sessionId,
    required this.state,
    required this.floatMinor,
    required this.cashSalesMinor,
    required this.cashRefundsMinor,
    required this.paidInMinor,
    required this.paidOutMinor,
    required this.unresolvedCardMinor,
    required this.expectedMinor,
  });

  final String sessionId;

  /// `open` or `closed`.
  final String state;
  final int floatMinor;
  final int cashSalesMinor;
  final int cashRefundsMinor;
  final int paidInMinor;
  final int paidOutMinor;

  /// Card money asked and not yet answered: listed, never counted as cash.
  final int unresolvedCardMinor;
  final int expectedMinor;

  factory DrawerCash.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_session_expected');
    return DrawerCash(
      sessionId: r.string('session_id'),
      state: r.stringOr('state', 'open'),
      floatMinor: _minor(r, 'float_minor'),
      cashSalesMinor: _minor(r, 'cash_sales_minor'),
      cashRefundsMinor: _minor(r, 'cash_refunds_minor'),
      paidInMinor: _minor(r, 'paid_in_minor'),
      paidOutMinor: _minor(r, 'paid_out_minor'),
      unresolvedCardMinor: _minor(r, 'unresolved_card_minor'),
      expectedMinor: _minor(r, 'expected_minor'),
    );
  }
}

/// A session opened: its id and its float.
class DrawerOpened {
  const DrawerOpened({required this.sessionId, required this.tillId, required this.floatMinor});

  final String sessionId;
  final String tillId;
  final int floatMinor;

  factory DrawerOpened.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_session_open');
    return DrawerOpened(sessionId: r.string('session_id'), tillId: r.string('till_id'), floatMinor: _minor(r, 'float_minor'));
  }
}

/// A cash entry recorded.
class DrawerEntryMade {
  const DrawerEntryMade({required this.entryId, required this.kind, required this.amountMinor});

  final String entryId;
  final String kind;
  final int amountMinor;

  factory DrawerEntryMade.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_cash_entry');
    return DrawerEntryMade(entryId: r.string('entry_id'), kind: r.stringOr('kind'), amountMinor: _minor(r, 'amount_minor'));
  }
}

/// A session closed: what it should have held, what was counted, the difference and what goes to the bank.
class DrawerClosed {
  const DrawerClosed({
    required this.sessionId,
    required this.expectedMinor,
    required this.countedMinor,
    required this.differenceMinor,
    required this.bankedMinor,
    required this.unresolvedCardMinor,
  });

  final String sessionId;
  final int expectedMinor;
  final int countedMinor;

  /// Counted minus expected: negative is a shortage.
  final int differenceMinor;
  final int bankedMinor;
  final int unresolvedCardMinor;

  factory DrawerClosed.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'counter_session_close');
    return DrawerClosed(
      sessionId: r.string('session_id'),
      expectedMinor: _minor(r, 'expected_minor'),
      countedMinor: _minor(r, 'counted_minor'),
      differenceMinor: _minor(r, 'difference_minor'),
      bankedMinor: _minor(r, 'banked_minor'),
      unresolvedCardMinor: _minor(r, 'unresolved_card_minor'),
    );
  }
}

/// How the drawer is counted, from the business's settings: `counter.blind_count`, `counter.count_by_denomination`,
/// `counter.cash_reasons` and `counter.paid_out_limit_minor`. The blind count is the server's to enforce: the expected
/// figure is simply not given to the counter.
class DrawerSettings {
  const DrawerSettings({required this.blindCount, required this.byDenomination, required this.reasons, required this.paidOutLimitMinor});

  final bool blindCount;
  final bool byDenomination;
  final List<String> reasons;

  /// 0 means no limit.
  final int paidOutLimitMinor;

  /// The business's comma list, trimmed and without empty entries.
  static List<String> reasonsOf(String list) => [
    for (final r in list.split(','))
      if (r.trim().isNotEmpty) r.trim(),
  ];
}

/// A count by denomination: the value of one note or coin in minor units, and how many of it.
class Denominations {
  const Denominations(this.counts);

  /// Value in minor units -> how many.
  final Map<int, int> counts;

  int get totalMinor => counts.entries.fold(0, (sum, e) => sum + e.key * e.value);

  /// The wire form: `{ "5000": 2 }`, minor units as text.
  Map<String, int> toJson() => {for (final e in counts.entries) '${e.key}': e.value};
}

/// A cash entry: [kind] is `paid_in` or `paid_out`; [reason] is one of the business's reasons; a paid-out expense may name the
/// purchase document it paid.
class DrawerEntry {
  const DrawerEntry({required this.kind, required this.amountMinor, required this.reason, this.purchaseDocumentId});

  final String kind;
  final int amountMinor;
  final String reason;
  final String? purchaseDocumentId;
}

/// What the person counted when closing a session: the cash (as a total, or by denomination), what was taken to the bank and the
/// reason of a difference.
class DrawerCount {
  const DrawerCount({required this.countedMinor, required this.bankedMinor, this.denominations, this.differenceReason});

  final int countedMinor;
  final int bankedMinor;
  final Denominations? denominations;
  final String? differenceReason;
}

/// The cash drawer's server.
abstract interface class TillDrawerPort {
  /// The tills of the business, each with the open session the person may read.
  Future<List<DrawerTill>> tills(String workspaceId);

  /// A new till (null [tillId]) or the edit of one. The till is saved whole: [sellingPlaceId] is the place it sells from,
  /// null putting it on the business's selling place.
  Future<DrawerTill> saveTill(String workspaceId, {required String requestId, String? tillId, required String name, String? siteId, required bool active, String? sellingPlaceId});

  /// The places a till may be given. Read by whoever manages the tills.
  Future<TillSellingPlaces> sellingPlaces(String workspaceId);

  Future<DrawerOpened> openSession(String workspaceId, {required String requestId, required String tillId, required int floatMinor, Denominations? denominations});

  /// A cash entry in or out of the drawer of [sessionId]; a request id replays the entry it made.
  Future<DrawerEntryMade> cashEntry(String workspaceId, {required String requestId, required String sessionId, required DrawerEntry entry});

  /// What the session should hold. Refused (DKN01) while it is open and counted blind, for someone who may not see the finances.
  Future<DrawerCash> expected(String workspaceId, {required String sessionId});

  /// Counts and closes [sessionId]: the count, what was banked and, when the count differs, its reason.
  Future<DrawerClosed> closeSession(String workspaceId, {required String requestId, required String sessionId, required DrawerCount count});

  /// The days closed so far, the latest first (the finances read them).
  Future<List<DayCloseRow>> dayCloses(String workspaceId);

  /// Closes [businessDate] (`YYYY-MM-DD`) for the business, [siteId] null meaning every site: the report of the day. Refused
  /// (DKL14) while a till is open, when the day is closed already or when no session was closed on it.
  Future<DayReport> closeDay(String workspaceId, {required String requestId, String? siteId, required String businessDate});

  /// A close read back.
  Future<DayReport> dayReport(String workspaceId, {required String dayCloseId});
}
