// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's basket and its one sale. The session holds what the operator rang up (items and exact
// quantities), has the server price it after every change (a draft under a request id of its own), and makes the sale
// in ONE command that numbers the receipt and takes the tender. It prices nothing itself and keeps no second sale path:
// a refusal is the server's, kept as it came so the screen can say it in words.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/trace/refusal_text.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/counter_book.dart' show TenderKind, TenderState;
import '../domain/counter_till.dart';
import '../domain/till_keypad.dart';
import '../domain/till_quantity.dart';
import 'till_offline_controller.dart';
import 'till_offline_mode.dart';
import 'till_state.dart';

export 'till_state.dart';

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

  /// The till the sales are made on: set by the screen when the business runs till sessions, null otherwise (a sale then
  /// carries no till). The cashier's choice among several open tills stays here while the basket is being served.
  final ValueNotifier<String?> chosenTill = ValueNotifier(null);
  String? tillId;

  /// #4373 -- selling offline: what the till shows of it, and what it needs to do it (no kit: the business sells online only).
  late final TillOfflineController _offlineMode = TillOfflineController(_Host(this));
  ValueNotifier<TillOfflineStatus> get offline => _offlineMode.status;
  void configureOffline(TillOfflineKit? kit, {String? sessionId}) => _offlineMode.configure(kit, sessionId: sessionId);
  Future<void> cacheOfflinePrices(List<TillKey> keys) => _offlineMode.cachePrices(keys);
  Future<void> reconnect({bool force = false}) => _offlineMode.reconnect(force: force);
  void dismissOfflineReport() => _offlineMode.dismissReport();
  Future<void> discardOfflineStore() => _offlineMode.discardStore();

  /// Every act runs after the one before it: two taps never send the same receipt and revision, and the answer of a sale
  /// is never dropped for a tap that came after it.
  Future<void> _tail = Future.value();
  int _queued = 0;
  bool _disposed = false;

  _Attempt? _draftAttempt;
  _Attempt? _finalAttempt;
  _Attempt? _cardAttempt;
  _Attempt? _answerAttempt;
  List<TillTender>? _tenders;
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

  /// #4476 -- the receipt of the last sale this till made, kept past the next customer: what Reprint prints again.
  String? lastSold;

  /// Whether the basket may still be changed: not once it is sold, and not while a sale is waiting to be confirmed.
  bool get _open => _now.sold == null && !_now.unconfirmed && _now.card == null;

  String _linesKey(List<TillLine> lines) => [
    for (final l in lines) '${l.itemId}:${l.quantity}:${l.pieces.join('+')}:${l.price ?? ''}:${l.priceReason ?? ''}:${l.discount ?? ''}',
  ].join(',');

  /// Rings up [quantity] (one by default) of [itemId]: a new line, or more on the line it already has. [ageConfirmed] is
  /// the age the operator confirmed for the line; [deposit] is the item whose deposit goes with it, as a line that
  /// follows this one's quantity. A quantity that is not exact and above zero rings up nothing and says so.
  Future<void> add({
    required String itemId,
    required String name,
    required String unit,
    String quantity = '1',
    int? ageConfirmed,
    ({String itemId, String name, String unit})? deposit,
  }) => _serial(() {
    final q = tillQuantityOf(quantity);
    if (!_open) return Future.value();
    if (q == null) {
      _set(_now.copyWith(problem: () => const TillQuantityMissing()));
      return Future.value();
    }
    final lines = [..._now.lines];
    final at = lines.indexWhere((l) => l.itemId == itemId && l.depositFor == null);
    if (at < 0) {
      lines.add(TillLine(itemId: itemId, name: name, quantity: q, unit: unit, ageConfirmed: ageConfirmed));
    } else {
      final more = tillQuantitySum(lines[at].quantity, q);
      if (more == null) return Future.value();
      final had = lines[at];
      lines[at] = TillLine(itemId: itemId, name: name, quantity: more, unit: unit, ageConfirmed: ageConfirmed ?? had.ageConfirmed)
          .withPricing(price: had.price, reason: had.priceReason, discount: had.discount);
    }
    if (deposit != null) _followDeposit(lines, itemId, deposit);
    return _price(lines);
  });

  /// #4436 -- rings up the piece tagged [tag] of [itemId]: a new line naming it, or one more named piece on the item's
  /// line. The same piece twice is refused here: it is one piece, sold once.
  Future<void> addPiece({required String itemId, required String name, required String unit, required String tag, required String twice}) =>
      _serial(() {
        if (!_open) return Future.value();
        final lines = [..._now.lines];
        if (lines.any((l) => l.pieces.contains(tag))) {
          _set(_now.copyWith(problem: () => twice));
          return Future.value();
        }
        final at = lines.indexWhere((l) => l.itemId == itemId);
        if (at < 0) {
          lines.add(TillLine(itemId: itemId, name: name, quantity: '0', unit: unit).withPiece(tag));
        } else {
          lines[at] = lines[at].withPiece(tag);
        }
        return _price(lines);
      });

  /// Sets the quantity of line [index] to [typed]; false when it is not an exact quantity above zero.

  /// Keeps the deposit line of [itemId] at the quantity of the line it belongs to.
  void _followDeposit(List<TillLine> lines, String itemId, ({String itemId, String name, String unit}) deposit) {
    final parent = lines.indexWhere((l) => l.itemId == itemId && l.depositFor == null);
    final at = lines.indexWhere((l) => l.depositFor == itemId);
    final line = TillLine(itemId: deposit.itemId, name: deposit.name, quantity: lines[parent].quantity, unit: deposit.unit, depositFor: itemId);
    if (at < 0) {
      lines.insert(parent + 1, line);
    } else {
      lines[at] = line;
    }
  }

  /// Sets the quantity of line [index] to [typed]; false when it is not an exact quantity above zero. The deposit line
  /// that belongs to it follows.
  Future<bool> setQuantity(int index, String typed) async {
    final q = tillQuantityOf(typed);
    if (q == null || index < 0 || index >= _now.lines.length) return false;
    await _serial(() {
      if (!_open || index >= _now.lines.length) return Future.value();
      final lines = [..._now.lines];
      final line = lines[index];
      lines[index] = line.withQuantity(q);
      if (line.depositFor == null) {
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].depositFor == line.itemId) lines[i] = lines[i].withQuantity(q);
        }
      }
      return _price(lines);
    });
    return true;
  }

  /// #4476 -- line [index] at [price] (an exact decimal) for [reason], or [discount] percent off, or (both null) at the
  /// item's price again; the server decides whether this cashier may. False when the line is not there or a value is not
  /// an exact decimal.
  Future<bool> setPricing(int index, {String? price, String? reason, String? discount}) async {
    final p = price == null ? null : tillMillionths(price);
    final d = discount == null ? null : tillMillionths(discount);
    if ((price != null && (p == null || p < 0)) || (discount != null && (d == null || d <= 0)) || index < 0 || index >= _now.lines.length) {
      return false;
    }
    await _serial(() {
      if (!_open || index >= _now.lines.length) return Future.value();
      final lines = [..._now.lines];
      lines[index] = lines[index].withPricing(
        price: p == null ? null : tillDecimalText(p),
        reason: reason?.trim(),
        discount: d == null ? null : tillDecimalText(d),
      );
      return _price(lines);
    });
    return true;
  }

  /// Takes line [index] out; a line's deposit goes with it.
  Future<void> remove(int index) => _serial(() {
    if (!_open || index < 0 || index >= _now.lines.length) return Future.value();
    final gone = _now.lines[index];
    return _price([
      for (var i = 0; i < _now.lines.length; i++)
        if (i != index && (gone.depositFor != null || _now.lines[i].depositFor != gone.itemId)) _now.lines[i],
    ]);
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
    // selling offline: the device prices the basket from what it holds, until the connection is back
    if (_offlineMode.status.value.active) {
      _offlineMode.priceLocally(lines);
      return;
    }
    try {
      final draft = await _draft(lines, receiptId: _last?.receiptId, revision: _last?.revision, reuse: again ? _draftAttempt : null);
      if (!_describes(draft, lines)) throw const TillDraftMismatch();
      _set(_now.copyWith(draft: () => draft));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till pricing refused', error: e, stackTrace: st);
      // no answer at all: the till goes on selling for cash, when the business has that on and the till has its session
      if (_offlineMode.connectionLost(e) && await _offlineMode.enter()) {
        _offlineMode.priceLocally(lines);
        return;
      }
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
      final key = '${_linesKey(lines)}|${rid ?? ''}|${rev ?? ''}|${tillId ?? ''}';
      final attempt = same != null && same.key == key ? same : _Attempt(key, _requestIds(), receiptId: rid, revision: rev);
      _draftAttempt = attempt;
      return port.draft(workspaceId, requestId: attempt.requestId, lines: lines, receiptId: rid, expectedRevision: rev, tillId: tillId).timeout(callTimeout);
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
    if (_offlineMode.status.value.active) return _offlineMode.payLocally(givenMinor);
    // A sale that may have been made is confirmed as it was sent, whatever the cash typed now.
    if (_now.unconfirmed) return _finalize(draft);
    final total = draft.totals.grossMinor;
    if (givenMinor < total) {
      _set(_now.copyWith(problem: () => const TillCashShort()));
      return;
    }
    _givenMinor = givenMinor;
    await _finalize(draft, [TillTender(kind: 'cash', amountMinor: total)]);
  });

  /// #4185 -- asks the terminal for the total by card: the server records the authorization (its key is what the
  /// terminal is given), and the till waits for the terminal's answer. A retry after a lost answer goes under the same
  /// request id, so the authorization is recorded once.
  Future<void> payCard() => _serial(() async {
    final draft = _now.draft;
    if (draft == null || !_open) return;
    final total = draft.totals.grossMinor;
    final key = '${draft.receiptId}|${draft.revision}|card:$total';
    final prior = _cardAttempt;
    final attempt = prior != null && prior.key == key ? prior : _Attempt(key, _requestIds());
    _cardAttempt = attempt;
    _set(_now.copyWith(problem: () => null));
    try {
      final asked = await port.requestCard(workspaceId, requestId: attempt.requestId, receiptId: draft.receiptId, amountMinor: total).timeout(callTimeout);
      _set(_now.withCard(asked));
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till card authorization not recorded', error: e, stackTrace: st);
      if (serverAnswered(e)) _cardAttempt = null;
      _set(_now.copyWith(problem: () => e));
    }
  });

  /// #4185 -- the terminal's answer to the card asked: `accepted` makes the sale with it, `refused` leaves the sale to be
  /// paid, `unknown` (no answer, the terminal is off) leaves it waiting in the receipts for someone who may see the
  /// finances. The same answer again goes under the same request id.
  Future<void> cardAnswer(String outcome, {String providerRef = ''}) => _serial(() async {
    final card = _now.card;
    final draft = _now.draft;
    if (card == null || draft == null || _now.cardUnknown || _now.sold != null) return;
    final key = '${card.tenderId}|$outcome|$providerRef';
    final prior = _answerAttempt;
    final attempt = prior != null && prior.key == key ? prior : _Attempt(key, _requestIds());
    _answerAttempt = attempt;
    _set(_now.copyWith(problem: () => null));
    try {
      final answer = await port
          .resolveCard(workspaceId, requestId: attempt.requestId, tenderId: card.tenderId, outcome: outcome, providerRef: providerRef)
          .timeout(callTimeout);
      _answerAttempt = null;
      switch (TenderState.of(answer.state)) {
        case TenderState.accepted:
          _givenMinor = draft.totals.grossMinor;
          await _finalize(draft, [TillTender(kind: TenderKind.card.wire, amountMinor: card.amountMinor, tenderId: card.tenderId)]);
        case TenderState.refused:
          _cardAttempt = null;
          _set(_now.withCard(null).copyWith(problem: () => const TillCardDeclined()));
        case TenderState.recorded || TenderState.requested || TenderState.unknown:
          _set(_now.withCardUnknown(value: true));
      }
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'till card answer not recorded', error: e, stackTrace: st);
      if (serverAnswered(e)) _answerAttempt = null;
      _set(_now.copyWith(problem: () => e));
    }
  });

  /// Sends the sale again, under the request id it has: what a sale whose answer was lost does. The server answers with
  /// the sale it made, or makes it once.
  Future<void> confirmSale() => _serial(() async {
    final draft = _now.draft;
    if (draft == null || !_now.unconfirmed) return;
    await _finalize(draft);
  });

  /// Makes the sale with [tenders]; none given is the sale already sent, confirmed as it was.
  Future<void> _finalize(TillDraft draft, [List<TillTender>? tenders]) async {
    final total = draft.totals.grossMinor;
    final sent = tenders ?? _tenders ?? [TillTender(kind: 'cash', amountMinor: total)];
    _tenders = sent;
    _set(_now.copyWith(problem: () => null));
    final key = '${draft.receiptId}|${draft.revision}|${[for (final t in sent) t.tenderId ?? '${t.kind}:${t.amountMinor}'].join(',')}';
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
            tenders: sent,
          )
          .timeout(callTimeout);
      _finalAttempt = null;
      if (_disposed) {
        TraceLogger.instance.warn('money', 'till sale ${sold.number} made after the till was closed');
        return;
      }
      lastSold = sold.receiptId;
      _set(_now.copyWith(sold: () => sold, change: () => _givenMinor - total).withCard(null).withUnconfirmed(value: false));
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
      if (sent.any((t) => t.tenderId != null)) {
        // The card's money is taken and the sale refused: it is not taken again here, the receipts settle it.
        _set(_now.copyWith(problem: () => e).withCardUnknown(value: true).withUnconfirmed(value: false));
        return;
      }
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
    if (_queued > 0 || _now.unconfirmed || (_now.card != null && !_now.cardUnknown && _now.sold == null)) return;
    _draftAttempt = null;
    _finalAttempt = null;
    _cardAttempt = null;
    _answerAttempt = null;
    _tenders = null;
    _last = null;
    _offlineMode.clearSale();
    _set(const TillState());
  }

  /// The till is left: a basket nobody is paying is dropped, a sale that may have been made (or is being made) stays
  /// here, to be confirmed when the till is opened again.
  void leave() {
    if (_queued > 0 || _now.unconfirmed) return;
    next();
    chosenTill.value = null;
  }

  void dispose() {
    _disposed = true;
    _offlineMode.dispose();
    chosenTill.dispose();
    state.dispose();
  }
}

/// The session as the offline selling sees it: what the till shows, how an act is run in order, and how the basket is priced again.
class _Host implements TillOfflineHost {
  _Host(this._session);

  final TillSession _session;

  @override
  TillState get current => _session._now;

  @override
  void show(TillState next) => _session._set(next);

  @override
  Future<void> serial(Future<void> Function() work) => _session._serial(work);

  @override
  Future<void> priceAgain() => _session._price(_session._now.lines);

  @override
  TillPort get port => _session.port;

  @override
  String get workspaceId => _session.workspaceId;

  @override
  Duration get callTimeout => _session.callTimeout;
}
