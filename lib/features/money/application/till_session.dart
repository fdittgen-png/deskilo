// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's basket and its one sale. The session holds what the operator rang up (items and exact
// quantities), has the server price it after every change (a draft under a request id of its own), and makes the sale
// in ONE command that numbers the receipt and takes the tender. It prices nothing itself and keeps no second sale path:
// a refusal is the server's, kept as it came so the screen can say it in words.
import 'package:flutter/foundation.dart';

import '../../../core/ids/request_id.dart';
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

class TillSession {
  TillSession({required this.port, required this.workspaceId, String Function()? requestIds}) : _requestIds = requestIds ?? newRequestId;

  final TillPort port;
  final String workspaceId;
  final String Function() _requestIds;

  /// The state the screen listens to.
  final ValueNotifier<TillState> state = ValueNotifier(const TillState());

  /// A change made while a pricing was in flight supersedes it: only the newest pricing is shown.
  int _generation = 0;

  TillState get _now => state.value;

  /// Rings up one more of [itemId]: a new line, or one more on the line it already has.
  Future<void> add({required String itemId, required String name, required String unit}) {
    final lines = [..._now.lines];
    final at = lines.indexWhere((l) => l.itemId == itemId);
    if (at < 0) {
      lines.add(TillLine(itemId: itemId, name: name, quantity: '1', unit: unit));
    } else {
      final more = tillQuantitySum(lines[at].quantity, '1');
      if (more != null) lines[at] = lines[at].withQuantity(more);
    }
    return _changed(lines);
  }

  /// Sets the quantity of line [index] to [typed]; false when it is not an exact quantity above zero.
  Future<bool> setQuantity(int index, String typed) async {
    final q = tillQuantityOf(typed);
    if (q == null || index < 0 || index >= _now.lines.length) return false;
    final lines = [..._now.lines];
    lines[index] = lines[index].withQuantity(q);
    await _changed(lines);
    return true;
  }

  Future<void> remove(int index) {
    if (index < 0 || index >= _now.lines.length) return Future.value();
    return _changed([..._now.lines]..removeAt(index));
  }

  Future<void> _changed(List<TillLine> lines) async {
    final generation = ++_generation;
    state.value = _now.copyWith(lines: lines, problem: () => null, sold: () => null);
    if (lines.isEmpty) {
      state.value = _now.copyWith(draft: () => null, busy: false);
      return;
    }
    state.value = _now.copyWith(busy: true);
    try {
      final draft = await port.draft(
        workspaceId,
        requestId: _requestIds(),
        lines: lines,
        receiptId: _now.draft?.receiptId,
        expectedRevision: _now.draft?.revision,
      );
      if (generation == _generation) state.value = _now.copyWith(draft: () => draft, busy: false);
    } on Object catch (e) {
      if (generation == _generation) state.value = _now.copyWith(busy: false, problem: () => e);
    }
  }

  /// Takes [givenMinor] in cash for the whole basket: the server records the total as the tender, the till says the
  /// change. Less than the total is refused here, before anything is sent.
  Future<void> payCash(int givenMinor) async {
    final draft = _now.draft;
    if (draft == null || _now.busy) return;
    final total = draft.totals.grossMinor;
    if (givenMinor < total) {
      state.value = _now.copyWith(problem: () => const TillCashShort());
      return;
    }
    final generation = ++_generation;
    state.value = _now.copyWith(busy: true, problem: () => null);
    try {
      final sold = await port.finalize(
        workspaceId,
        requestId: _requestIds(),
        receiptId: draft.receiptId,
        expectedRevision: draft.revision,
        tenders: [TillTender(kind: 'cash', amountMinor: total)],
      );
      if (generation == _generation) {
        state.value = _now.copyWith(busy: false, sold: () => sold, change: () => givenMinor - total);
      }
    } on Object catch (e) {
      if (generation == _generation) state.value = _now.copyWith(busy: false, problem: () => e);
    }
  }

  /// The next customer: an empty basket and nothing left of the last sale.
  void next() {
    _generation++;
    state.value = const TillState();
  }

  void dispose() => state.dispose();
}
