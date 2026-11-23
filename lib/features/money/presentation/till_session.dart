// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's basket and its one sale. The session holds what the operator rang up (items and exact
// quantities), has the server price it after every change (a draft under a request id of its own), and makes the sale
// in ONE command that numbers the receipt and takes the tender. It prices nothing itself and keeps no second sale path:
// a refusal is the server's, kept as it came so the screen can say it in words.
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/ids/request_id.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_till.dart';
import '../domain/till_quantity.dart';

/// What the till shows: the basket, its price, a sale made, or the refusal of the last act.
@immutable
class TillState {
  const TillState({this.lines = const [], this.draft, this.sold, this.busy = false, this.problem, this.change});

  final List<TillLine> lines;
  final TillDraft? draft;
  final TillSold? sold;
  final bool busy;

  /// The error of the last act, as the server (or the client's own check) raised it; null when it went through.
  final Object? problem;

  /// The change due on the sale just made, in minor units.
  final int? change;

  bool get empty => lines.isEmpty;

  TillState copyWith({
    List<TillLine>? lines,
    TillDraft? Function()? draft,
    TillSold? Function()? sold,
    bool? busy,
    Object? Function()? problem,
    int? Function()? change,
  }) => TillState(
    lines: lines ?? this.lines,
    draft: draft == null ? this.draft : draft(),
    sold: sold == null ? this.sold : sold(),
    busy: busy ?? this.busy,
    problem: problem == null ? this.problem : problem(),
    change: change == null ? this.change : change(),
  );
}

/// The cash given is less than the total: said by the till itself before anything is sent.
class TillCashShort implements Exception {
  const TillCashShort();
}

/// The server's draft does not describe the basket on the screen: it is not sold.
class TillDraftMismatch implements Exception {
  const TillDraftMismatch();
}

/// One pricing call as it was sent: the same call again (a retry after a lost answer) reuses its request id, so the
/// server answers the first one instead of making a second.
class _Attempt {
  const _Attempt(this.key, this.requestId, {this.receiptId, this.revision});

  final String key;
  final String requestId;
  final String? receiptId;
  final int? revision;
}

class TillSession {
  TillSession({required this.port, required this.workspaceId, String Function()? requestIds}) : _requestIds = requestIds ?? newRequestId;

  final TillPort port;
  final String workspaceId;
  final String Function() _requestIds;

  /// The state the screen listens to.
  final ValueNotifier<TillState> state = ValueNotifier(const TillState());

  /// Every act runs after the one before it: two taps never send the same receipt and revision, and the answer of a sale
  /// is never dropped for a tap that came after it.
  Future<void> _tail = Future.value();
  int _queued = 0;

  _Attempt? _draftAttempt;
  _Attempt? _finalAttempt;

  TillState get _now => state.value;

  Future<void> _serial(Future<void> Function() work) {
    _queued++;
    state.value = _now.copyWith(busy: true);
    final done = _tail.then((_) => work());
    _tail = done.catchError((Object _) {});
    return done.whenComplete(() {
      if (--_queued == 0) state.value = _now.copyWith(busy: false);
    });
  }

  String _linesKey(List<TillLine> lines) => [for (final l in lines) '${l.itemId}:${l.quantity}'].join(',');

  /// Rings up one more of [itemId]: a new line, or one more on the line it already has.
  Future<void> add({required String itemId, required String name, required String unit}) => _serial(() {
    if (_now.sold != null) return Future.value();
    final lines = [..._now.lines];
    final at = lines.indexWhere((l) => l.itemId == itemId);
    if (at < 0) {
      lines.add(TillLine(itemId: itemId, name: name, quantity: '1', unit: unit));
    } else {
      final more = tillQuantitySum(lines[at].quantity, '1');
      if (more != null) lines[at] = lines[at].withQuantity(more);
    }
    return _price(lines);
  });

  /// Sets the quantity of line [index] to [typed]; false when it is not an exact quantity above zero.
  Future<bool> setQuantity(int index, String typed) async {
    final q = tillQuantityOf(typed);
    if (q == null || index < 0 || index >= _now.lines.length) return false;
    await _serial(() {
      if (_now.sold != null || index >= _now.lines.length) return Future.value();
      final lines = [..._now.lines];
      lines[index] = lines[index].withQuantity(q);
      return _price(lines);
    });
    return true;
  }

  Future<void> remove(int index) => _serial(() {
    if (_now.sold != null || index < 0 || index >= _now.lines.length) return Future.value();
    return _price([..._now.lines]..removeAt(index));
  });

  /// Prices the basket again as it is: the retry of a pricing that failed, under the request id it already had.
  Future<void> retry() => _serial(() => _now.sold != null ? Future.value() : _price(_now.lines, again: true));

  Future<void> _price(List<TillLine> lines, {bool again = false}) async {
    state.value = _now.copyWith(lines: lines, problem: () => null, sold: () => null, draft: () => null);
    _finalAttempt = null;
    if (lines.isEmpty) {
      _draftAttempt = null;
      _last = null;
      return;
    }
    try {
      final draft = await _draft(lines, receiptId: _last?.receiptId, revision: _last?.revision, reuse: again ? _draftAttempt : null);
      if (draft.lines.length != lines.length) throw const TillDraftMismatch();
      state.value = _now.copyWith(draft: () => draft);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till pricing refused', error: e, stackTrace: st);
      state.value = _now.copyWith(draft: () => null, problem: () => e);
    }
  }

  /// The last draft the server answered: the receipt a new pricing continues.
  TillDraft? _last;

  Future<TillDraft> _draft(List<TillLine> lines, {String? receiptId, int? revision, _Attempt? reuse}) async {
    Future<TillDraft> call(String? rid, int? rev, {_Attempt? same}) {
      final key = '${_linesKey(lines)}|${rid ?? ''}|${rev ?? ''}';
      final attempt = same != null && same.key == key ? same : _Attempt(key, _requestIds(), receiptId: rid, revision: rev);
      _draftAttempt = attempt;
      return port.draft(workspaceId, requestId: attempt.requestId, lines: lines, receiptId: rid, expectedRevision: rev);
    }

    try {
      final draft = await call(receiptId, revision, same: reuse);
      _last = draft;
      return draft;
    } on Object catch (e) {
      // The receipt moved or is no longer open: price the basket once more as a receipt of its own.
      if (receiptId != null && e is PostgrestException && (e.code == 'DKL10' || e.code == 'DKL04')) {
        final draft = await call(null, null);
        _last = draft;
        return draft;
      }
      rethrow;
    }
  }

  /// Takes [givenMinor] in cash for the whole basket: the server records the total as the tender, the till says the
  /// change. Less than the total is refused here, before anything is sent. The same sale again (a retry after a lost
  /// answer) goes under the request id it already had.
  Future<void> payCash(int givenMinor) => _serial(() async {
    final draft = _now.draft;
    if (draft == null) return;
    final total = draft.totals.grossMinor;
    if (givenMinor < total) {
      state.value = _now.copyWith(problem: () => const TillCashShort());
      return;
    }
    state.value = _now.copyWith(problem: () => null);
    final key = '${draft.receiptId}|${draft.revision}|cash:$total';
    final prior = _finalAttempt;
    final attempt = prior != null && prior.key == key ? prior : _Attempt(key, _requestIds());
    _finalAttempt = attempt;
    try {
      final sold = await port.finalize(
        workspaceId,
        requestId: attempt.requestId,
        receiptId: draft.receiptId,
        expectedRevision: draft.revision,
        tenders: [TillTender(kind: 'cash', amountMinor: total)],
      );
      _finalAttempt = null;
      state.value = _now.copyWith(sold: () => sold, change: () => givenMinor - total);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till sale refused', error: e, stackTrace: st);
      state.value = _now.copyWith(problem: () => e);
    }
  });

  /// The till's own refusal of what was typed, said on the screen: [problem] is the sentence.
  void reject(String problem) => state.value = _now.copyWith(problem: () => problem);

  /// The next customer: an empty basket and nothing left of the last sale.
  void next() {
    if (_queued > 0) return;
    _draftAttempt = null;
    _finalAttempt = null;
    _last = null;
    state.value = const TillState();
  }

  void dispose() => state.dispose();
}
