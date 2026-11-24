// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- the Demo's returns, corrections and counts, behind the same
// port as the server's and on the Demo's ONE ledger: a part of a sale comes
// back from the customer to a real place (#4173), a part of a delivery goes
// back to its supplier or is undone by a correction, each bounded by the
// movement it reverses; a count records what was observed and waits for an
// approval, which applies exactly its difference and only if the stock has not
// moved since. A logical return or count sent again answers what it recorded;
// other content under the same identity is refused. What a command refuses, it
// refuses whole and moves nothing. Nothing leaves the process.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../codes/dk_code.dart';
import 'demo_stock_ledger.dart';

const _loss = 'demo-place-loss';
const _customer = 'demo-place-customer';
const _transit = 'demo-place-transit';
const _owner = 'demo-member-owner';

PostgrestException _refused(String code, String message) => PostgrestException(message: message, code: code);

typedef _Planned = ({StockMovementRow source, ExactQuantity quantity, StockReturnLineDraft line});

/// The in-memory returns and counts of the reference business.
class DemoStockReversals implements StockReversals {
  DemoStockReversals(this._ledger);

  final DemoStockLedger _ledger;

  /// What was reversed on each movement, in the order it was done.
  final Map<String, List<StockReversalEntry>> _bySource = {};

  /// Each logical return: its content and what it answered.
  final Map<String, ({String digest, StockReturnResult result})> _returns = {};
  final Map<String, StockReturnResult> _answers = {};

  final List<_Count> _counts = [];

  ExactQuantity _reversed(String movementId) => [
    for (final e in _bySource[movementId] ?? const <StockReversalEntry>[]) e.quantity,
  ].fold(ExactQuantity.zero, (a, b) => a + b);

  StockMovementRow? _movement(String id) => _ledger.movements.where((m) => m.id == id).firstOrNull;

  @override
  Future<Map<String, StockReversible>> reversible(String workspaceId, List<String> movementIds) async => {
    if (_ledger.mine(workspaceId))
      for (final id in movementIds)
        if (_movement(id) case final m?)
          id: StockReversible(
            movementId: id,
            reason: m.reason,
            quantity: m.quantity,
            reversed: _reversed(id),
            remaining: m.quantity - _reversed(id),
            reversals: List.unmodifiable(_bySource[id] ?? const []),
          ),
  };

  @override
  Future<StockReturnResult> makeReturn(
    String workspaceId,
    String returnId,
    StockReturnKind kind,
    List<StockReturnLineDraft> lines,
    String requestId,
  ) async {
    if (_answers[requestId] case final done?) return done;
    if (!_ledger.mine(workspaceId) || lines.isEmpty) throw _refused(DkCode.dkg07, 'a return has lines');
    final digest = '${kind.wire}|${[for (final l in lines) '${l.lineId}:${l.sourceMovementId}:${l.quantity}:${l.locationId}'].join(',')}';
    if (_returns[returnId] case final known?) {
      if (known.digest != digest) throw _refused(DkCode.dkg16, 'this return was already recorded with other content');
      return _answers[requestId] = known.result;
    }
    // everything is checked before anything moves: a refusal moves nothing
    final planned = _plan(kind, lines, await _ledger.placeConfigs());
    final movementIds = <String>[];
    var remaining = ExactQuantity.zero;
    final item = _ledger.itemOf(planned.first.source.itemId);
    if (item == null) throw _refused(DkCode.dkg04, 'not a stock item of this business');
    for (final p in planned) {
      final (from, to) = switch (kind) {
        StockReturnKind.customer => (p.source.toLocationId, p.line.locationId!),
        StockReturnKind.supplier => (p.line.locationId!, p.source.fromLocationId),
        StockReturnKind.correction => (p.source.toLocationId, p.source.fromLocationId),
      };
      final row = await _ledger.post(
        DemoStockPost(
          item: _ledger.itemOf(p.source.itemId) ?? item,
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
    return _answers[requestId] = result;
  }

  /// Checks every line against its source before anything moves.
  List<_Planned> _plan(StockReturnKind kind, List<StockReturnLineDraft> lines, Map<String, StockPlaceConfig> places) {
    final planned = <_Planned>[];
    final taken = <String, ExactQuantity>{};
    for (final l in lines) {
      final source = _movement(l.sourceMovementId);
      if (source == null) throw _refused(DkCode.dkg04, 'a line names a movement of another business or none');
      final quantity = _quantity(l.quantity);
      _kindAllows(kind, source, l, places);
      final already = taken[source.id] ?? ExactQuantity.zero;
      final left = source.quantity - _reversed(source.id) - already;
      if (quantity > left) throw _refused(DkCode.dkg17, 'only ${left.text} can still be reversed on this movement');
      taken[source.id] = already + quantity;
      planned.add((source: source, quantity: quantity, line: l));
    }
    return planned;
  }

  ExactQuantity _quantity(String text) {
    final ExactQuantity quantity;
    try {
      quantity = ExactQuantity.parse(text);
    } on ExactQuantityException {
      throw _refused(DkCode.dkg07, 'a quantity above zero');
    }
    if (quantity <= ExactQuantity.zero) throw _refused(DkCode.dkg07, 'a quantity above zero');
    return quantity;
  }

  /// A place of this business the goods can really be at: active, not virtual, not the road.
  bool _real(Map<String, StockPlaceConfig> places, String? id) {
    final p = places[id];
    return p != null && p.active && !p.virtual && p.id != _transit;
  }

  void _kindAllows(StockReturnKind kind, StockMovementRow source, StockReturnLineDraft l, Map<String, StockPlaceConfig> places) {
    switch (kind) {
      case StockReturnKind.customer:
        if (source.reason != 'sale' || source.toLocationId != _customer) throw _refused(DkCode.dkg18, 'a customer return follows a sale');
        if (!_real(places, l.locationId)) throw _refused(DkCode.dkg05, 'the goods come back to a real place');
      case StockReturnKind.supplier:
        if (source.reason != 'receipt') throw _refused(DkCode.dkg18, 'a supplier return follows a receipt');
        if (l.locationId == null) throw _refused(DkCode.dkg05, 'the goods leave from a real place');
      case StockReturnKind.correction:
        if (source.reason == 'opening') throw _refused(DkCode.dkg18, 'this movement is not corrected here');
    }
  }

  int _moves(String itemId, String place) =>
      _ledger.movements.where((m) => m.itemId == itemId && (m.fromLocationId == place || m.toLocationId == place)).length;

  @override
  Future<List<StockCountRow>> counts(String workspaceId) async => [
    if (_ledger.mine(workspaceId)) for (final c in _counts.reversed) c.row(_moves(c.itemId, c.locationId)),
  ];

  @override
  Future<void> recordCount(String workspaceId, StockCountDraft draft) async {
    if (!_ledger.mine(workspaceId)) throw _refused(DkCode.dkg07, 'a count has an identity and a scope');
    final ExactQuantity observed;
    try {
      observed = ExactQuantity.parse(draft.observed);
    } on ExactQuantityException {
      throw _refused(DkCode.dkg07, 'a count has a quantity');
    }
    if (observed < ExactQuantity.zero || _ledger.itemOf(draft.itemId) == null) {
      throw _refused(DkCode.dkg07, 'a count has an identity and a scope');
    }
    final known = _counts.where((c) => c.countId == draft.countId).firstOrNull;
    if (known != null) {
      if (known.itemId != draft.itemId || known.locationId != draft.locationId || known.observed != observed) {
        throw _refused(DkCode.dkg16, 'this count was already recorded with other content');
      }
      return;
    }
    _counts.add(
      _Count(
        countId: draft.countId,
        itemId: draft.itemId,
        locationId: draft.locationId,
        observed: observed,
        baseline: _ledger.balance(draft.itemId, draft.locationId, lotId: draft.lotId),
        baselineMoves: _moves(draft.itemId, draft.locationId),
        reason: draft.reason,
      ),
    );
  }

  @override
  Future<void> decideCount(
    String workspaceId,
    String countId,
    StockCountDecision decision,
    String requestId, {
    String note = '',
  }) async {
    final c = _counts.where((x) => x.countId == countId).firstOrNull;
    if (!_ledger.mine(workspaceId) || c == null) throw _refused(DkCode.dkg04, 'not a count of this business');
    final state = switch (decision) {
      StockCountDecision.apply => StockCountState.applied,
      StockCountDecision.reject => StockCountState.rejected,
      StockCountDecision.cancel => StockCountState.cancelled,
    };
    if (c.state != StockCountState.recorded) {
      if (c.state == state) return;
      throw _refused(DkCode.dkg19, 'this count was already decided');
    }
    if (decision == StockCountDecision.apply) {
      if (_moves(c.itemId, c.locationId) != c.baselineMoves) throw _refused(DkCode.dkg20, 'the stock moved since it was counted: count it again');
      final diff = c.observed - c.baseline;
      final item = _ledger.itemOf(c.itemId)!;
      if (diff > ExactQuantity.zero) {
        c.movementId = (await _ledger.post(DemoStockPost(item: item, quantity: diff, from: _loss, to: c.locationId, reason: 'adjustment'))).id;
      } else if (diff < ExactQuantity.zero) {
        c.movementId = (await _ledger.post(DemoStockPost(item: item, quantity: ExactQuantity.zero - diff, from: c.locationId, to: _loss, reason: 'adjustment'))).id;
      }
    }
    c
      ..state = state
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
  });

  final String countId;
  final String itemId;
  final String locationId;
  final ExactQuantity observed;
  final ExactQuantity baseline;
  final int baselineMoves;
  final String reason;
  StockCountState state = StockCountState.recorded;
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
    authorMemberId: _owner,
    decidedByMemberId: state == StockCountState.recorded ? null : _owner,
    decidedAt: decidedAt,
    movementId: movementId,
  );
}
