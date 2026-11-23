// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's basket and its one sale. The session holds what the operator rang up (items and exact
// quantities), has the server price it after every change (a draft under a request id of its own), and makes the sale
// in ONE command that numbers the receipt and takes the tender. It prices nothing itself and keeps no second sale path:
// a refusal is the server's, kept as it came so the screen can say it in words.
import 'package:flutter/foundation.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_till.dart';
import '../domain/till_quantity.dart';

/// What the till shows: the basket, its price, a sale made, or the refusal of the last act.
@immutable
class TillState {
  const TillState({this.lines = const [], this.draft, this.sold, this.busy = false, this.problem, this.change, this.unconfirmed = false});

  final List<TillLine> lines;
  final TillDraft? draft;
  final TillSold? sold;
  final bool busy;

  /// The error of the last act, as the server (or the client's own check) raised it; null when it went through.
  final Object? problem;

  /// The change due on the sale just made, in minor units.
  final int? change;

  /// The sale was sent and its answer did not come: it may have been made. Nothing else is done to the basket until the
  /// sale is confirmed (sent again under the same request id, which the server answers with the sale it made).
  final bool unconfirmed;

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
    unconfirmed: unconfirmed,
  );

  /// The same state with the sale marked as waiting to be confirmed, or not.
  TillState withUnconfirmed({required bool value}) =>
      TillState(lines: lines, draft: draft, sold: sold, busy: busy, problem: problem, change: change, unconfirmed: value);
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
  TillSession({required this.port, required this.workspaceId, String Function()? requestIds, this.callTimeout = const Duration(seconds: 20)})
    : _requestIds = requestIds ?? newRequestId;

  final TillPort port;
  final String workspaceId;
  final String Function() _requestIds;

  /// How long one call to the server may take: a call that hangs is a problem to retry, not a till that waits forever.
  final Duration callTimeout;

  /// The state the screen listens to.
  final ValueNotifier<TillState> state = ValueNotifier(const TillState());

  /// Every act runs after the one before it: two taps never send the same receipt and revision, and the answer of a sale
  /// is never dropped for a tap that came after it.
  Future<void> _tail = Future.value();
  int _queued = 0;
  bool _disposed = false;

  _Attempt? _draftAttempt;
  _Attempt? _finalAttempt;
  int _givenMinor = 0;

  /// The last draft the server answered: the receipt a new pricing continues.
  TillDraft? _last;

  TillState get _now => state.value;

  void _set(TillState next) {
    if (!_disposed) state.value = next;
  }

  Future<void> _serial(Future<void> Function() work) {
    _queued++;
    _set(_now.copyWith(busy: true));
    final done = _tail.then((_) => work());
    _tail = done.catchError((Object _) {});
    return done.whenComplete(() {
      if (--_queued == 0) _set(_now.copyWith(busy: false));
    });
  }

  /// Whether the basket may still be changed: not once it is sold, and not while a sale is waiting to be confirmed.
  bool get _open => _now.sold == null && !_now.unconfirmed;

  String _linesKey(List<TillLine> lines) => [for (final l in lines) '${l.itemId}:${l.quantity}'].join(',');

  /// Rings up one more of [itemId]: a new line, or one more on the line it already has.
  Future<void> add({required String itemId, required String name, required String unit}) => _serial(() {
    if (!_open) return Future.value();
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
      if (!_open || index >= _now.lines.length) return Future.value();
      final lines = [..._now.lines];
      lines[index] = lines[index].withQuantity(q);
      return _price(lines);
    });
    return true;
  }

  Future<void> remove(int index) => _serial(() {
    if (!_open || index < 0 || index >= _now.lines.length) return Future.value();
    return _price([..._now.lines]..removeAt(index));
  });

  /// Prices the basket again as it is: the retry of a pricing that failed, under the request id it already had.
  Future<void> retry() => _serial(() => _open ? _price(_now.lines, again: true) : Future.value());

  Future<void> _price(List<TillLine> lines, {bool again = false}) async {
    _set(_now.copyWith(lines: lines, problem: () => null, sold: () => null, draft: () => null));
    _finalAttempt = null;
    if (lines.isEmpty) {
      _draftAttempt = null;
      _last = null;
      return;
    }
    try {
      final draft = await _draft(lines, receiptId: _last?.receiptId, revision: _last?.revision, reuse: again ? _draftAttempt : null);
      if (!_describes(draft, lines)) throw const TillDraftMismatch();
      _set(_now.copyWith(draft: () => draft));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till pricing refused', error: e, stackTrace: st);
      _set(_now.copyWith(draft: () => null, problem: () => e));
    }
  }

  /// The draft prices the basket on the screen: the same lines, the same quantities.
  bool _describes(TillDraft draft, List<TillLine> lines) {
    if (draft.lines.length != lines.length) return false;
    for (var i = 0; i < lines.length; i++) {
      final said = draft.lines[i].quantity;
      if (said.isNotEmpty && (tillQuantityOf(said) ?? said) != (tillQuantityOf(lines[i].quantity) ?? lines[i].quantity)) return false;
    }
    return true;
  }

  Future<TillDraft> _draft(List<TillLine> lines, {String? receiptId, int? revision, _Attempt? reuse}) async {
    Future<TillDraft> call(String? rid, int? rev, {_Attempt? same}) {
      final key = '${_linesKey(lines)}|${rid ?? ''}|${rev ?? ''}';
      final attempt = same != null && same.key == key ? same : _Attempt(key, _requestIds(), receiptId: rid, revision: rev);
      _draftAttempt = attempt;
      return port.draft(workspaceId, requestId: attempt.requestId, lines: lines, receiptId: rid, expectedRevision: rev).timeout(callTimeout);
    }

    try {
      final draft = await call(receiptId, revision, same: reuse);
      _last = draft;
      return draft;
    } on Object catch (e, st) {
      // The receipt moved or is no longer open: price the basket once more as a receipt of its own. The receipt is let
      // go first, so a retry after a lost answer finds the same call and its request id.
      if (receiptId != null && const {KnownRefusal.counterChanged, KnownRefusal.counterNotOpen}.contains(knownRefusalOf(e))) {
        TraceLogger.instance.warn('money', 'till receipt moved, priced again', error: e, stackTrace: st);
        _last = null;
        final draft = await call(null, null, same: reuse);
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
    if (draft == null || _now.sold != null) return;
    // A sale that may have been made is confirmed as it was sent, whatever the cash typed now.
    if (_now.unconfirmed) return _finalize(draft);
    final total = draft.totals.grossMinor;
    if (givenMinor < total) {
      _set(_now.copyWith(problem: () => const TillCashShort()));
      return;
    }
    _givenMinor = givenMinor;
    await _finalize(draft);
  });

  /// Sends the sale again, under the request id it has: what a sale whose answer was lost does. The server answers with
  /// the sale it made, or makes it once.
  Future<void> confirmSale() => _serial(() async {
    final draft = _now.draft;
    if (draft == null || !_now.unconfirmed) return;
    await _finalize(draft);
  });

  Future<void> _finalize(TillDraft draft) async {
    final total = draft.totals.grossMinor;
    _set(_now.copyWith(problem: () => null));
    final key = '${draft.receiptId}|${draft.revision}|cash:$total';
    final prior = _finalAttempt;
    final attempt = prior != null && prior.key == key ? prior : _Attempt(key, _requestIds());
    _finalAttempt = attempt;
    try {
      final sold = await port
          .finalize(
            workspaceId,
            requestId: attempt.requestId,
            receiptId: draft.receiptId,
            expectedRevision: draft.revision,
            tenders: [TillTender(kind: 'cash', amountMinor: total)],
          )
          .timeout(callTimeout);
      _finalAttempt = null;
      if (_disposed) {
        TraceLogger.instance.warn('money', 'till sale ${sold.number} made after the till was closed');
        return;
      }
      _set(_now.copyWith(sold: () => sold, change: () => _givenMinor - total).withUnconfirmed(value: false));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till sale not confirmed', error: e, stackTrace: st);
      final refusal = knownRefusalOf(e);
      if (!serverAnswered(e)) {
        // No answer (a timeout, a lost connection): the sale may have been made.
        _set(_now.copyWith(problem: () => e).withUnconfirmed(value: true));
        return;
      }
      // The server answered: the sale was not made, whatever it said.
      _finalAttempt = null;
      _set(_now.copyWith(problem: () => e).withUnconfirmed(value: false));
      if (refusal == KnownRefusal.counterChanged || refusal == KnownRefusal.counterNotOpen) {
        // This receipt is not the one to sell: the basket is priced again as it is, and says why if that fails too.
        _last = null;
        if (_disposed) return;
        await _price(_now.lines);
        if (_now.problem == null) _set(_now.copyWith(problem: () => e));
      }
    }
  }

  /// The till's own refusal of what was typed, said on the screen: [problem] is the sentence.
  void reject(String problem) => _set(_now.copyWith(problem: () => problem));

  /// The next customer: an empty basket and nothing left of the last sale.
  void next() {
    if (_queued > 0 || _now.unconfirmed) return;
    _draftAttempt = null;
    _finalAttempt = null;
    _last = null;
    _set(const TillState());
  }

  /// The till is left: a basket nobody is paying is dropped, a sale that may have been made (or is being made) stays
  /// here, to be confirmed when the till is opened again.
  void leave() {
    if (_queued > 0 || _now.unconfirmed) return;
    next();
  }

  void dispose() {
    _disposed = true;
    state.dispose();
  }
}
