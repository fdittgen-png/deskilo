// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the Demo's stock commands, behind the same port as the
// server's and on the Demo's ONE ledger: a transfer inside a site is one step;
// between sites goods are loaded onto the road (the in-transit place) and
// received, all or in part, onto a place of the destination site; goods are
// taken out for use or as a loss. What a command refuses, it refuses whole and
// moves nothing: less than asked on hand (named), a place of the wrong site, a
// quantity that is not above zero, more received than was loaded. A retried
// request id answers what it answered. Nothing leaves the process.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_ledger.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_ledger.dart';

/// The in-memory stock commands of the reference business: the rules are the domain ledger's (#4403).
class DemoStockOperations implements StockOperations {
  DemoStockOperations(this._ledger);

  final DemoStockLedger _ledger;

  StockLedger get _core => _ledger.core;

  /// Another business keeps no ledger here: its request is refused as malformed.
  void _check(String workspaceId) {
    if (!_ledger.mine(workspaceId)) throw const StockConfigRefused('request', StockRefusal.malformed);
  }

  @override
  Future<List<StockTransfer>> openTransfers(String workspaceId) async =>
      _ledger.mine(workspaceId) ? _ledger.openTransfers : const [];

  @override
  Future<StockCommandResult> transfer(String workspaceId, List<StockLineDraft> lines, String requestId) async =>
      _core.once(requestId, () {
        _check(workspaceId);
        final moved = _core.transferInSite(lines);
        return (requestId: requestId, movements: moved.length, transferId: null, status: null);
      });

  @override
  Future<StockCommandResult> load(String workspaceId, String toLocationId, List<StockLineDraft> lines, String requestId) async =>
      _core.once(requestId, () {
        _check(workspaceId);
        final t = _core.load(toLocationId, lines);
        return (requestId: requestId, movements: lines.length, transferId: t.id, status: t.status);
      });

  @override
  Future<StockCommandResult> receive(String workspaceId, String transferId, List<StockReceiveDraft> lines, String requestId) async =>
      _core.once(requestId, () {
        _check(workspaceId);
        final (:transfer, :movements) = _core.receive(transferId, lines);
        return (requestId: requestId, movements: movements, transferId: transfer.id, status: transfer.status);
      });

  @override
  Future<StockCommandResult> takeOut(String workspaceId, StockTakeOutReason reason, List<StockLineDraft> lines, String requestId) async =>
      _core.once(requestId, () {
        _check(workspaceId);
        final moved = _core.takeOut(reason, lines);
        return (requestId: requestId, movements: moved.length, transferId: null, status: null);
      });

  @override
  Future<StockProposal> proposal(
    String workspaceId, {
    required String itemId,
    required String locationId,
    required String quantity,
    String? variantId,
  }) async {
    final asked = ExactQuantity.parse(quantity);
    final held = _ledger.balance(itemId, locationId);
    final take = held < asked ? held : asked;
    return StockProposal(
      lots: held.isZero
          ? const []
          : [
              StockLotProposal(
                lotId: null,
                lotCode: null,
                expiresOn: null,
                expired: false,
                available: held,
                take: take,
              ),
            ],
      short: asked - take,
    );
  }
}
