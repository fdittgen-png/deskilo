// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the returns, corrections and counts kept on one stock ledger (stock_ledger.dart), with the rules each
// meets before anything moves. Pure, as the ledger is. The server stays the authority: 0867 stock_return_v1 and
// 0870 the counts, at the lines cited. A refusal the server raises under a code of its own is a [StockCodeRefused].
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import '../../../core/failure/app_failure.dart';
import 'stock_config.dart';
import 'stock_ledger.dart';
import 'stock_page.dart';
import 'stock_reversals.dart';

/// A refusal the server raises under a code of its own rather than with a reason: a return or a count (DKG04, DKG05,
/// DKG07, DKG16 to DKG20).
final class StockCodeRefused implements TypedRefusal {
  const StockCodeRefused(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'StockCodeRefused($code, $message)';
}

typedef _Planned = ({StockMovementRow source, ExactQuantity quantity, StockReturnLineDraft line});

final _observed = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// The returns and the counts of one business, on its [StockLedger].
class StockReversalBook {
  StockReversalBook(this._ledger);

  final StockLedger _ledger;


  /// What was reversed on each movement, in the order it was done.
  final Map<String, List<StockReversalEntry>> _bySource = {};

  /// Each logical return: its content and what it answered.
  final Map<String, ({String digest, StockReturnResult result})> _returns = {};

  ExactQuantity _reversed(String movementId) => [
    for (final e in _bySource[movementId] ?? const <StockReversalEntry>[]) e.quantity,
  ].fold(ExactQuantity.zero, (a, b) => a + b);


  /// What each of [movementIds] allows to be reversed (0867 stock_reversible_v1).
  Map<String, StockReversible> reversible(List<String> movementIds) => {
    for (final id in movementIds)
      if (_ledger.movement(id) case final m?)
        id: StockReversible(
          movementId: id,
          reason: m.reason,
          quantity: m.quantity,
          reversed: _reversed(id),
          remaining: m.quantity - _reversed(id),
          reversals: List.unmodifiable(_bySource[id] ?? const []),
        ),
  };

  /// A return, a supplier return or a correction of one movement per line, bounded by what that movement still
  /// allows. The same return sent again answers what it recorded; other content under its identity is refused
  /// (0867:292-303, DKG16).
  StockReturnResult makeReturn(String returnId, StockReturnKind kind, List<StockReturnLineDraft> lines) {
    if (lines.isEmpty || lines.length > 200) throw const StockCodeRefused(DkCode.dkg07, 'a return has lines');
    final digest = '${kind.wire}|${[for (final l in lines) '${l.lineId}:${l.sourceMovementId}:${l.quantity}:${l.locationId}'].join(',')}';
    if (_returns[returnId] case final known?) {
      if (known.digest != digest) throw const StockCodeRefused(DkCode.dkg16, 'this return was already recorded with other content');
      return known.result;
    }
    // everything is checked before anything moves: a refusal moves nothing
    final planned = _plan(kind, lines);
    final movementIds = <String>[];
    var remaining = ExactQuantity.zero;
    for (final p in planned) {
      final (from, to) = switch (kind) {
        StockReturnKind.customer => (p.source.toLocationId, p.line.locationId!),
        StockReturnKind.supplier => (p.line.locationId!, p.source.fromLocationId),
        StockReturnKind.correction => (p.source.toLocationId, p.source.fromLocationId),
      };
      final row = _ledger.post(
        StockPost(
          item: _ledger.itemOf(p.source.itemId)!,
          quantity: p.quantity,
          from: from,
          to: to,
          reason: switch (kind) {
            StockReturnKind.customer => 'return_in',
            StockReturnKind.supplier => 'return_out',
            StockReturnKind.correction => 'correction',
          },
          lotId: p.source.lotId,
          lotCode: p.source.lotCode,
          variantId: p.source.variantId,
        ),
      );
      movementIds.add(row.id);
      (_bySource[p.source.id] ??= []).add(
        StockReversalEntry(returnId: returnId, lineId: p.line.lineId, kind: kind.wire, quantity: p.quantity, movementId: row.id),
      );
      remaining = p.source.quantity - _reversed(p.source.id);
    }
    final result = (returnId: returnId, movementIds: movementIds, remaining: remaining);
    _returns[returnId] = (digest: digest, result: result);
    return result;
  }

  /// Checks every line against its source before anything moves (0867:265-380).
  List<_Planned> _plan(StockReturnKind kind, List<StockReturnLineDraft> lines) {
    final planned = <_Planned>[];
    final taken = <String, ExactQuantity>{};
    for (final l in lines) {
      final source = _ledger.movement(l.sourceMovementId);
      // a movement of this business, of an item it keeps (0867:309-313)
      if (source == null || _ledger.itemOf(source.itemId) == null) {
        throw const StockCodeRefused(DkCode.dkg04, 'a line names a movement of another business or none');
      }
      final ExactQuantity quantity;
      try {
        quantity = StockLedger.quantityOf(l.quantity, 'quantity');
      } on StockConfigRefused {
        throw const StockCodeRefused(DkCode.dkg07, 'a quantity above zero');
      }
      _kindAllows(kind, source, l);
      // the bound: what the movement still allows, an earlier line of this return counted (0867:374-380, DKG17)
      final already = taken[source.id] ?? ExactQuantity.zero;
      final left = source.quantity - _reversed(source.id) - already;
      if (quantity > left) throw StockCodeRefused(DkCode.dkg17, 'only ${left.text} can still be reversed on this movement');
      taken[source.id] = already + quantity;
      planned.add((source: source, quantity: quantity, line: l));
    }
    return planned;
  }

  /// What each kind follows, and the place its line names (0867:337-366).
  void _kindAllows(StockReturnKind kind, StockMovementRow source, StockReturnLineDraft l) {
    final places = _ledger.places;
    switch (kind) {
      case StockReturnKind.customer:
        // the sale went to a place of the customer kind (0867:338-341)
        if (source.reason != 'sale' || places[source.toLocationId]?.kind != 'customer') {
          throw const StockCodeRefused(DkCode.dkg18, 'a customer return follows a sale');
        }
        if (!_ledger.isReal(l.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'the goods come back to a real place');
      case StockReturnKind.supplier:
        if (source.reason != 'receipt') throw const StockCodeRefused(DkCode.dkg18, 'a supplier return follows a receipt');
        if (!_ledger.isReal(l.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'the goods leave from a real place');
      case StockReturnKind.correction:
        // an opening, and a leg of a transfer between sites, are not corrected here (0867:357-362)
        if (source.reason == 'opening' ||
            places[source.fromLocationId]?.inTransit == true ||
            places[source.toLocationId]?.inTransit == true) {
          throw const StockCodeRefused(DkCode.dkg18, 'this movement is not corrected here');
        }
    }
  }

  // ── counts (0870 stock_count_record_core, stock_count_decide_v1) ─────────

  final List<_Count> _counts = [];

  /// How many movements touched [itemId] at [place] (0870 stock_scope_moves).
  int _moves(String itemId, String place) =>
      _ledger.movements.where((m) => m.itemId == itemId && (m.fromLocationId == place || m.toLocationId == place)).length;

  /// The counts, newest first.
  List<StockCountRow> get counts => [for (final c in _counts.reversed) c.row(_moves(c.itemId, c.locationId))];

  /// Records what [draft] observed against what the ledger holds, by [author]. The same count sent again changes
  /// nothing; other content under its identity is refused (0870:184-232).
  void recordCount(StockCountDraft draft, {required String author}) {
    if (!_observed.hasMatch(draft.observed)) throw const StockCodeRefused(DkCode.dkg07, 'a count has a quantity');
    final observed = ExactQuantity.parse(draft.observed);
    final known = _counts.where((c) => c.countId == draft.countId).firstOrNull;
    if (known != null) {
      if (known.itemId != draft.itemId || known.locationId != draft.locationId || known.observed != observed) {
        throw const StockCodeRefused(DkCode.dkg16, 'this count was already recorded with other content');
      }
      return;
    }
    if (_ledger.itemOf(draft.itemId) == null) throw const StockCodeRefused(DkCode.dkg04, 'not a stock item of this business');
    if (!_ledger.isReal(draft.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'a count is taken at a real place of this business');
    _counts.add(
      _Count(
        countId: draft.countId,
        itemId: draft.itemId,
        locationId: draft.locationId,
        observed: observed,
        baseline: _ledger.balance(draft.itemId, draft.locationId, lotId: draft.lotId),
        baselineMoves: _moves(draft.itemId, draft.locationId),
        reason: draft.reason,
        author: author,
      ),
    );
  }

  /// Applies, rejects or cancels a count, by [decider]. Applying moves exactly its difference to or from the loss
  /// place, and only if nothing moved since it was counted (DKG20); a decided count answers the same decision again
  /// and refuses another (DKG19) (0870:302-367).
  void decideCount(String countId, StockCountDecision decision, {required String decider}) {
    final c = _counts.where((x) => x.countId == countId).firstOrNull;
    if (c == null) throw const StockCodeRefused(DkCode.dkg04, 'not a count of this business');
    final state = switch (decision) {
      StockCountDecision.apply => StockCountState.applied,
      StockCountDecision.reject => StockCountState.rejected,
      StockCountDecision.cancel => StockCountState.cancelled,
    };
    if (c.state != StockCountState.recorded) {
      if (c.state == state) return;
      throw const StockCodeRefused(DkCode.dkg19, 'this count was already decided');
    }
    if (decision == StockCountDecision.apply) {
      if (_moves(c.itemId, c.locationId) != c.baselineMoves) {
        throw const StockCodeRefused(DkCode.dkg20, 'the stock moved since it was counted: count it again');
      }
      final diff = c.observed - c.baseline;
      final item = _ledger.itemOf(c.itemId)!;
      final loss = _ledger.placeOfKind('loss');
      if (diff > ExactQuantity.zero) {
        c.movementId = _ledger.post(StockPost(item: item, quantity: diff, from: loss, to: c.locationId, reason: 'adjustment')).id;
      } else if (diff < ExactQuantity.zero) {
        c.movementId = _ledger.post(StockPost(item: item, quantity: ExactQuantity.zero - diff, from: c.locationId, to: loss, reason: 'adjustment')).id;
      }
    }
    c
      ..state = state
      ..decider = decider
      ..decidedAt = _ledger.today;
  }
}

class _Count {
  _Count({
    required this.countId,
    required this.itemId,
    required this.locationId,
    required this.observed,
    required this.baseline,
    required this.baselineMoves,
    required this.reason,
    required this.author,
  });

  final String countId;
  final String itemId;
  final String locationId;
  final ExactQuantity observed;
  final ExactQuantity baseline;
  final int baselineMoves;
  final String reason;
  final String author;
  StockCountState state = StockCountState.recorded;
  String? decider;
  DateTime? decidedAt;
  String? movementId;

  StockCountRow row(int movesNow) => StockCountRow(
    countId: countId,
    itemId: itemId,
    locationId: locationId,
    observed: observed,
    baseline: baseline,
    state: state,
    stale: state == StockCountState.recorded && movesNow != baselineMoves,
    reason: reason,
    authorMemberId: author,
    decidedByMemberId: decider,
    decidedAt: decidedAt,
    movementId: movementId,
  );
}
