// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- the Demo's cash drawer: the server's rules of the till sessions, in memory. One open session per till; the
// expected cash is the float plus the cash sales and the paid-in, less the refunds and the paid-out; the expected figure is
// refused (DKN01) while a session is open and counted blind, unless the person may see the finances; a count that differs
// is closed with its reason; a request id answers the same act again.
import 'dart:convert';

import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../codes/dk_code.dart';

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
  bool closed = false;

  int _sum(String kind) => entries.where((e) => e.kind == kind).fold(0, (a, e) => a + e.amount);

  int get expected => floatMinor + cashSales - cashRefunds + _sum('paid_in') - _sum('paid_out');
}

class DemoTillDrawer implements TillDrawerPort {
  DemoTillDrawer({List<DrawerTill>? tills}) : _tills = [...(tills ?? _seeded)];

  static const _seeded = [
    DrawerTill(id: 'demo-till-front', name: 'Front counter', active: true),
    DrawerTill(id: 'demo-till-market', name: 'Market stall', active: true),
  ];

  /// The business's settings, read when an act needs them; the registry defaults until the app wires the real ones.
  DrawerRules Function() rules = () => const DrawerSettings(blindCount: true, byDenomination: false, reasons: ['change', 'expense', 'other'], paidOutLimitMinor: 0);

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
  void recordCashSale(String tillId, int amountMinor) => _openOn(tillId)?.cashSales += amountMinor;

  DrawerTill _view(DrawerTill t) {
    final s = _openOn(t.id);
    return DrawerTill(
      id: t.id,
      name: t.name,
      active: t.active,
      siteId: t.siteId,
      session: s == null ? null : DrawerSession(id: s.id, tillId: s.tillId, floatMinor: s.floatMinor, openedByMemberId: s.openedBy),
    );
  }

  @override
  Future<List<DrawerTill>> tills(String workspaceId) async => [for (final t in _tills) _view(t)];

  T _replayed<T extends Object>(String requestId) => _answered[requestId]! as T;

  @override
  Future<DrawerTill> saveTill(String workspaceId, {required String requestId, String? tillId, required String name, String? siteId, required bool active}) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 60) throw _refused('22023', 'a till has a name');
    final taken = _tills.any((t) => t.id != tillId && t.name.toLowerCase() == clean.toLowerCase());
    if (taken) throw _refused(DkCode.dkl12, 'a till of this business already has this name', reason: 'name_taken');
    if (tillId == null) {
      final made = DrawerTill(id: _id('till'), name: clean, active: active, siteId: siteId);
      _tills.add(made);
      return _answered[requestId] = made;
    }
    final at = _tills.indexWhere((t) => t.id == tillId);
    if (at < 0) throw _refused(DkCode.dkl12, 'not a till of this business', reason: 'till_unknown');
    if (!active && _openOn(tillId) != null) throw _refused(DkCode.dkl12, 'a till with an open session is closed first', reason: 'already_open');
    final saved = DrawerTill(id: tillId, name: clean, active: active, siteId: siteId);
    _tills[at] = saved;
    return _answered[requestId] = saved;
  }

  @override
  Future<DrawerOpened> openSession(String workspaceId, {required String requestId, required String tillId, required int floatMinor, Denominations? denominations}) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    if (floatMinor < 0) throw _refused('22023', 'a session is opened with its float');
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

  @override
  Future<DrawerEntryMade> cashEntry(
    String workspaceId, {
    required String requestId,
    required String sessionId,
    required String kind,
    required int amountMinor,
    required String reason,
    String? purchaseDocumentId,
  }) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    if (amountMinor <= 0) throw _refused('22023', 'an entry has an amount');
    if (!rules().reasons.contains(reason.trim())) throw _refused(DkCode.dkl13, 'this reason is not on the list', reason: 'reason_unknown');
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
  Future<DrawerClosed> closeSession(
    String workspaceId, {
    required String requestId,
    required String sessionId,
    required int countedMinor,
    Denominations? denominations,
    String? differenceReason,
    required int bankedMinor,
  }) async {
    if (_answered[requestId] != null) return _replayed(requestId);
    if (countedMinor < 0 || bankedMinor < 0 || bankedMinor > countedMinor) throw _refused('22023', 'a session is closed with its count');
    if (rules().byDenomination && denominations?.totalMinor != countedMinor) {
      throw _refused(DkCode.dkl13, 'the drawer is counted by denomination and adds up', reason: 'denominations');
    }
    final s = _open(sessionId);
    final difference = countedMinor - s.expected;
    if (difference != 0 && (differenceReason ?? '').trim().isEmpty) {
      throw _refused(DkCode.dkl13, 'a difference is closed with its reason', reason: 'difference_reason', more: canSeeFinances() ? {'difference_minor': '$difference'} : const {});
    }
    s.closed = true;
    return _answered[requestId] = DrawerClosed(
          sessionId: s.id,
          expectedMinor: s.expected,
          countedMinor: countedMinor,
          differenceMinor: difference,
          bankedMinor: bankedMinor,
          unresolvedCardMinor: 0,
        );
  }
}
