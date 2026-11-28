// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the Demo's cash drawer: the server's rules of the till sessions, in memory. One open session per till; the
// expected cash is the float plus the cash sales and the paid-in, less the refunds and the paid-out; the expected figure is
// refused (DKN01) while a session is open and counted blind, unless the person may see the finances; a count that differs
// is closed with its reason; a request id answers the same act again.
import 'dart:convert';

import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/domain/till_drawer_rules.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show cashValuesOf, tillCashValues;
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../codes/dk_code.dart';
import '../../codes/pg_code.dart';
import '../demo_table.dart';

PostgrestException _refused(String code, String message, {String? reason, Map<String, Object?> more = const {}}) => PostgrestException(
  message: message,
  code: code,
  details: reason == null ? null : jsonEncode({'reason': reason, ...more}),
);

/// The settings the drawer's rules read, as the business set them.
typedef DrawerRules = DrawerSettings;

class _Entry {
  _Entry(this.kind, this.amount);

  final String kind;
  final int amount;
}

class _Session {
  _Session(this.id, this.tillId, this.floatMinor, this.openedBy);

  final String id;
  final String tillId;
  final int floatMinor;
  final String openedBy;
  final List<_Entry> entries = [];
  int cashSales = 0;
  int cashRefunds = 0;

  /// #4373 -- the cash of offline sales the server refused: it is in the drawer, so it is in the expected cash.
  int offlineRefused = 0;
  bool closed = false;
  bool inDayClose = false;
  final List<String> receipts = [];
  int counted = 0;
  int banked = 0;
  String reason = '';

  int _sum(String kind) => entries.where((e) => e.kind == kind).fold(0, (a, e) => a + e.amount);

  int get expected => floatMinor + cashSales - cashRefunds + offlineRefused + _sum('paid_in') - _sum('paid_out');
}

class DemoTillDrawer implements TillDrawerPort {
  DemoTillDrawer({List<DrawerTill>? tills, this.currency = 'EUR'}) : _tills = [...(tills ?? _seeded)];

  /// #4511 -- the business currency, whose notes and coins the tills count in.
  final String currency;

  static const _seeded = [
    DrawerTill(id: 'demo-till-front', name: 'Front counter', active: true),
    DrawerTill(id: 'demo-till-market', name: 'Market stall', active: true),
    // #4448 -- laid out with the Bakery template, a keypad and a calculator (demo_till_layouts.dart)
    DrawerTill(id: 'demo-till-bakery', name: 'Bakery counter', active: true),
  ];

  /// The business's settings, read when an act needs them; the registry defaults until the app wires the real ones.
  DrawerRules Function() rules = () => const DrawerSettings(blindCount: true, byDenomination: false, paidOutLimitMinor: 0);

  /// Whether the signed-in person may see the finances (and so the expected cash of a blind count).
  bool Function() canSeeFinances = () => false;

  /// Whether the signed-in person may record outgoing payments (a paid-out above the limit).
  bool Function() canRecordOutgoing = () => false;

  /// The signed-in member.
  String Function() me = () => 'demo-member';

  final List<DrawerTill> _tills;
  final Map<String, _Session> _sessions = {};
  final Map<String, Object> _answered = {};
  int _ids = 0;

  String _id(String prefix) => 'demo-$prefix-${++_ids}';

  _Session? _openOn(String tillId) {
    for (final s in _sessions.values) {
      if (s.tillId == tillId && !s.closed) return s;
    }
    return null;
  }

  /// Whether a session is open on [tillId]: what a sale needs when the sessions are on.
  bool hasOpenSession(String tillId) => _openOn(tillId) != null;

  /// A cash sale of [amountMinor] made on [tillId]'s open session.
  void recordCashSale(String tillId, int amountMinor, {String number = ''}) {
    final s = _openOn(tillId);
    if (s == null) return;
    s.cashSales += amountMinor;
    if (number.isNotEmpty) s.receipts.add(number);
  }

  /// #4373 -- whether [sessionId] is a session still open: an offline sale is sent into it, and a closed one takes nothing.
  bool sessionIsOpen(String sessionId) => _sessions[sessionId]?.closed == false;

  /// #4373 -- an offline sale reaches the session it was made in: an accepted one is a cash sale of it, a refused one leaves its
  /// cash in the drawer count.
  void recordOfflineSale(String sessionId, {required int cashMinor, required bool accepted, String number = ''}) {
    final s = _sessions[sessionId];
    if (s == null || s.closed) return;
    if (accepted) {
      s.cashSales += cashMinor;
      if (number.isNotEmpty) s.receipts.add(number);
    } else {
      s.offlineRefused += cashMinor;
    }
  }

  DrawerTill _view(DrawerTill t) {
    final s = _openOn(t.id);
    return DrawerTill(
      id: t.id,
      name: t.name,
      active: t.active,
      siteId: t.siteId,
      session: s == null ? null : DrawerSession(id: s.id, tillId: s.tillId, floatMinor: s.floatMinor, openedByMemberId: s.openedBy),
      denominations: t.denominations,
    );
  }

  @override
  Future<List<DrawerTill>> tills(String workspaceId) async => [for (final t in _tills) _view(t)];

  T _replayed<T extends Object>(String requestId) => _answered[requestId]! as T;

  @override
  Future<DrawerTill> saveTill(String workspaceId, {required String requestId, String? tillId, required String name, String? siteId, required bool active}) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    final clean = name.trim();
    if (clean.isEmpty || clean.length > kTillNameMaxLength) throw _refused(PgCode.invalidParameterValue, 'a till has a name');
    final taken = _tills.any((t) => t.id != tillId && t.name.toLowerCase() == clean.toLowerCase());
    if (taken) throw _refused(DkCode.dkl12, 'a till of this business already has this name', reason: 'name_taken');
    if (tillId == null) {
      final made = DrawerTill(id: _id('till'), name: clean, active: active, siteId: siteId);
      _tills.add(made);
      return _answered[requestId] = made;
    }
    final at = _tillAt(tillId);
    if (at < 0) throw _refused(DkCode.dkl12, 'not a till of this business', reason: 'till_unknown');
    if (!active && _openOn(tillId) != null) throw _refused(DkCode.dkl12, 'a till with an open session is closed first', reason: 'already_open');
    final saved = DrawerTill(id: tillId, name: clean, active: active, siteId: siteId, denominations: _tills[at].denominations);
    _tills[at] = saved;
    return _answered[requestId] = saved;
  }

  /// Where [tillId] is in the list, or -1.
  int _tillAt(String tillId) => _tills.indexWhere((t) => t.id == tillId);

  @override
  Future<List<int>?> setTillDenominations(String workspaceId, {required String tillId, required List<int> values}) async {
    final at = _tillAt(tillId);
    if (at < 0) throw _refused(DkCode.dkl02, 'no such till in this business', reason: 'till');
    final current = cashValuesOf(currency);
    for (final v in values) {
      if (!current.contains(v)) throw _refused(DkCode.dkl02, 'a value the currency has no note or coin of', reason: 'denomination');
    }
    final t = _tills[at];
    final picked = values.isEmpty ? null : [for (final v in current) if (values.contains(v)) v];
    _tills[at] = DrawerTill(id: t.id, name: t.name, active: t.active, siteId: t.siteId, denominations: picked);
    return picked;
  }

  /// #4511 (0997) -- a count names only the till's notes and coins; a currency not listed takes any value.
  void _countedInTill(String tillId, Denominations? counted) {
    final till = _tills.where((t) => t.id == tillId).firstOrNull;
    final values = tillCashValues(currency, till?.denominations);
    if (counted == null || values.isEmpty) return;
    for (final v in counted.counts.keys) {
      if (!values.contains(v)) throw _refused(DkCode.dkl02, 'a value this till has no note or coin of', reason: 'denomination');
    }
  }

  @override
  Future<DrawerOpened> openSession(String workspaceId, {required String requestId, required String tillId, required int floatMinor, Denominations? denominations}) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    _countedInTill(tillId, denominations);
    if (floatMinor < 0) throw _refused(PgCode.invalidParameterValue, 'a session is opened with its float');
    if (rules().byDenomination && denominations?.totalMinor != floatMinor) {
      throw _refused(DkCode.dkl13, 'the float is counted by denomination and adds up', reason: 'denominations');
    }
    final till = _tills.where((t) => t.id == tillId).firstOrNull;
    if (till == null || !till.active) throw _refused(DkCode.dkl12, 'not an active till of this business', reason: 'till_unknown');
    if (_openOn(tillId) != null) throw _refused(DkCode.dkl12, 'this till is already open', reason: 'already_open', more: {'till_id': tillId});
    final session = _Session(_id('session'), tillId, floatMinor, me());
    _sessions[session.id] = session;
    return _answered[requestId] = DrawerOpened(sessionId: session.id, tillId: tillId, floatMinor: floatMinor);
  }

  _Session _open(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null) throw _refused(DkCode.dkl12, 'this session is not open', reason: 'session_unknown');
    if (s.closed) throw _refused(DkCode.dkl12, 'this session is not open', reason: 'closed');
    return s;
  }

  /// #4514 (0999) -- the business's cash reasons: the built-in ones, then its own.
  final DemoTable<CashReason> _reasons = DemoTable((r) => r.code, kBuiltinCashReasons);

  /// An active reason of [process], by its code, or the refusal the server gives.
  void _reasonOnList(String code, CashReasonProcess process) {
    if (!_reasons.any((r) => r.code == code.trim() && r.offeredFor(process))) {
      throw _refused(DkCode.dkl13, 'this reason is not on the business\'s list', reason: 'reason_unknown');
    }
  }

  @override
  Future<List<CashReason>> cashReasons(String workspaceId) async => [..._reasons]..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<CashReason> saveCashReason(String workspaceId, {String? code, required String name, required Set<CashReasonProcess> processes, int? position, bool? archived}) async {
    if (processes.isEmpty) throw _refused(DkCode.dkl13, 'a reason serves at least one process', reason: 'reason_process');
    final named = name.trim();
    if (code == null) {
      if (named.isEmpty || named.length > kCashReasonNameMaxLength) throw _refused(DkCode.dkl13, 'a reason of the business has a name', reason: 'reason_name');
      final base = cashReasonCodeOf(named);
      var made = base;
      for (var n = 2; _reasons.any((r) => r.code == made); n++) {
        made = '${base}_$n';
      }
      final reason = CashReason(code: made, builtin: false, name: named, processes: processes, archived: archived ?? false, position: position ?? 100);
      _reasons.add(reason);
      return reason;
    }
    final at = _reasons.indexOfId(code);
    if (at < 0) throw _refused(DkCode.dkl13, 'no such reason in this business', reason: 'reason_unknown');
    final was = _reasons[at];
    if (!was.builtin && (named.isEmpty || named.length > kCashReasonNameMaxLength)) {
      throw _refused(DkCode.dkl13, 'a reason of the business has a name', reason: 'reason_name');
    }
    return _reasons[at] = CashReason(
      code: was.code,
      builtin: was.builtin,
      name: was.builtin ? null : named,
      processes: processes,
      archived: archived ?? was.archived,
      position: position ?? was.position,
    );
  }

  @override
  Future<DrawerEntryMade> cashEntry(String workspaceId, {required String requestId, required String sessionId, required DrawerEntry entry}) async {
    final (kind, amountMinor, reason) = (entry.kind, entry.amountMinor, entry.reason);
    if (_answered[requestId] != null) return _replayed(requestId);
    if (amountMinor <= 0) throw _refused(PgCode.invalidParameterValue, 'an entry has an amount');
    _reasonOnList(reason, CashReasonProcess.ofEntryKind(kind));
    final session = _open(sessionId);
    final limit = rules().paidOutLimitMinor;
    if (kind == 'paid_out' && limit > 0 && amountMinor > limit && !canRecordOutgoing()) {
      throw _refused(DkCode.dkl13, 'a paid-out above the limit', reason: 'above_limit', more: {'limit_minor': '$limit'});
    }
    session.entries.add(_Entry(kind, amountMinor));
    return _answered[requestId] = DrawerEntryMade(entryId: _id('entry'), kind: kind, amountMinor: amountMinor);
  }

  @override
  Future<DrawerCash> expected(String workspaceId, {required String sessionId}) async {
    final s = _sessions[sessionId];
    if (s == null) throw _refused(DkCode.dkl12, 'not a session of this business', reason: 'session_unknown');
    if (!canSeeFinances() && (s.closed || rules().blindCount)) throw _refused(DkCode.dkn01, 'the drawer is counted blind');
    return DrawerCash(
      sessionId: s.id,
      state: s.closed ? 'closed' : 'open',
      floatMinor: s.floatMinor,
      cashSalesMinor: s.cashSales,
      cashRefundsMinor: s.cashRefunds,
      paidInMinor: s._sum('paid_in'),
      paidOutMinor: s._sum('paid_out'),
      unresolvedCardMinor: 0,
      expectedMinor: s.expected,
    );
  }

  @override
  Future<DrawerClosed> closeSession(String workspaceId, {required String requestId, required String sessionId, required DrawerCount count}) async {
    final (countedMinor, bankedMinor, denominations, differenceReason) = (count.countedMinor, count.bankedMinor, count.denominations, count.differenceReason);
    if (_answered[requestId] != null) return _replayed(requestId);
    if (countedMinor < 0 || bankedMinor < 0 || bankedMinor > countedMinor) throw _refused(PgCode.invalidParameterValue, 'a session is closed with its count');
    if (rules().byDenomination && denominations?.totalMinor != countedMinor) {
      throw _refused(DkCode.dkl13, 'the drawer is counted by denomination and adds up', reason: 'denominations');
    }
    final s = _open(sessionId);
    _countedInTill(s.tillId, denominations);
    final difference = countedMinor - s.expected;
    if (difference != 0 && (differenceReason ?? '').trim().isEmpty) {
      throw _refused(DkCode.dkl13, 'a difference is closed with its reason', reason: 'difference_reason', more: canSeeFinances() ? {'difference_minor': '$difference'} : const {});
    }
    if ((differenceReason ?? '').trim().isNotEmpty) _reasonOnList(differenceReason!, CashReasonProcess.countDifference);
    s
      ..closed = true
      ..counted = countedMinor
      ..banked = bankedMinor
      ..reason = (differenceReason ?? '').trim();
    return _answered[requestId] = DrawerClosed(
          sessionId: s.id,
          expectedMinor: s.expected,
          countedMinor: countedMinor,
          differenceMinor: difference,
          bankedMinor: bankedMinor,
          unresolvedCardMinor: 0,
        );
  }

  final List<(String, DayReport)> _closes = [];

  @override
  Future<List<DayCloseRow>> dayCloses(String workspaceId) async {
    if (!canSeeFinances()) throw _refused(DkCode.dkn01, 'not allowed to see the finances of the counter');
    final rows = [for (final (_, r) in _closes) DayCloseRow(id: r.dayCloseId, number: r.number, businessDate: r.businessDate)];
    return rows.reversed.toList();
  }

  /// The report of the closed sessions not yet in a close. Its sales by tax rate stay empty here: the Demo's till keeps the
  /// cash taken per session, not the tax breakdown of each receipt.
  @override
  Future<DayReport> closeDay(String workspaceId, {required String requestId, String? siteId, required String businessDate}) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    if (!canSeeFinances()) throw _refused(DkCode.dkn01, 'not allowed to see the finances of the counter');
    if (_closes.any((c) => c.$2.businessDate == businessDate)) throw _refused(DkCode.dkl14, 'this day is already closed', reason: 'day_closed');
    for (final t in _tills) {
      if (_openOn(t.id) != null) throw _refused(DkCode.dkl14, 'a till is still open', reason: 'till_open', more: {'till_id': t.id, 'name': t.name});
    }
    final sessions = _sessions.values.where((s) => s.closed && !s.inDayClose).toList();
    if (sessions.isEmpty) throw _refused(DkCode.dkl14, 'nothing to close on this day', reason: 'nothing_to_close');
    final sold = sessions.fold<int>(0, (a, s) => a + s.cashSales);
    final numbers = [for (final s in sessions) ...s.receipts];
    final report = DayReport(
      dayCloseId: _id('day'),
      number: 'DC-${(_closes.length + 1).toString().padLeft(4, '0')}',
      businessDate: businessDate,
      sessions: [
        for (final s in sessions)
          DaySession(
            till: _tills.firstWhere((t) => t.id == s.tillId).name,
            floatMinor: s.floatMinor,
            expectedMinor: s.expected,
            countedMinor: s.counted,
            differenceMinor: s.counted - s.expected,
            differenceReason: s.reason,
            bankedMinor: s.banked,
            unresolvedCardMinor: 0,
          ),
      ],
      differencesMinor: sessions.fold(0, (a, s) => a + s.counted - s.expected),
      salesByRate: const [],
      salesByTender: sold == 0 ? const {} : {'cash': sold},
      salesTotalMinor: sold,
      firstReceipt: numbers.isEmpty ? '' : numbers.first,
      lastReceipt: numbers.isEmpty ? '' : numbers.last,
      correctionsMinor: 0,
      refunds: const {},
      paidInMinor: sessions.fold(0, (a, s) => a + s._sum('paid_in')),
      paidOutMinor: sessions.fold(0, (a, s) => a + s._sum('paid_out')),
    );
    for (final s in sessions) {
      s.inDayClose = true;
    }
    _closes.add((businessDate, report));
    return _answered[requestId] = report;
  }

  @override
  Future<DayReport> dayReport(String workspaceId, {required String dayCloseId}) async {
    if (!canSeeFinances()) throw _refused(DkCode.dkn01, 'not allowed to read the day report');
    final found = _closes.where((c) => c.$2.dayCloseId == dayCloseId).firstOrNull;
    if (found == null) throw _refused(DkCode.dkl14, 'not a day close of this business', reason: 'day_unknown');
    return found.$2;
  }
}
