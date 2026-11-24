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
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_sites.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_config_commands.dart';
import 'demo_stock_ledger.dart';

const _transit = 'demo-place-transit';
const _loss = 'demo-place-loss';

/// The in-memory stock commands of the reference business.
class DemoStockOperations implements StockOperations {
  DemoStockOperations(this._ledger, this._config);

  final DemoStockLedger _ledger;
  final DemoStockConfigCommands _config;

  static StockConfigRefused _refused(String field, StockRefusal reason) => StockConfigRefused(field, reason);

  bool _mine(String id) => _ledger.mine(id);

  @override
  Future<List<StockTransfer>> openTransfers(String workspaceId) async =>
      _mine(workspaceId) ? _ledger.openTransfers : const [];

  /// What a line asks of the ledger, in the item's inventory unit.
  Future<({StockItem item, ExactQuantity quantity})> _quantity(StockLineDraft line, int i) async {
    final item = _ledger.itemOf(line.itemId);
    if (item == null) throw _refused('lines[$i].item_id', StockRefusal.itemForeign);
    final ExactQuantity entered;
    try {
      entered = ExactQuantity.parse(line.quantity);
    } on ExactQuantityException {
      throw _refused('lines[$i].quantity', StockRefusal.quantityInvalid);
    }
    if (entered <= ExactQuantity.zero) throw _refused('lines[$i].quantity', StockRefusal.quantityInvalid);
    final unit = line.unit;
    if (unit == null || unit == item.unit) return (item: item, quantity: entered);
    final config = await _config.item(_ledger.workspaceId, item.id);
    final factor = config?.units.where((u) => u.unit == unit).firstOrNull;
    if (factor == null) throw _refused('lines[$i].unit', StockRefusal.unitUnmapped);
    // as the server records it: round(q * num / den, 6) (0840)
    final converted = entered.scaled(factor.factorNum, factor.factorDen, round: true).value;
    if (converted == null) throw _refused('lines[$i].quantity', StockRefusal.quantityInvalid);
    return (item: item, quantity: converted);
  }

  /// Every place of a line is a real place of the business.
  Future<Map<String, StockPlaceConfig>> _real() async => {
    for (final p in stockRealPlaces(await _config.places(_ledger.workspaceId))) p.id: p,
  };

  /// Refuses, whole, when a source holds less than the lines together ask.
  void _checkOnHand(List<({StockItem item, ExactQuantity quantity})> asked, List<String> from) {
    final need = <String, ExactQuantity>{};
    for (var i = 0; i < asked.length; i++) {
      final key = '${asked[i].item.id}|${from[i]}';
      need[key] = (need[key] ?? ExactQuantity.zero) + asked[i].quantity;
    }
    for (final e in need.entries) {
      final [item, place] = e.key.split('|');
      final held = _ledger.balance(item, place);
      if (held < e.value) throw StockNotEnough('${held.text} of ${e.value.text} are there');
    }
  }

  StockCommandResult _answer(String requestId, int movements, {String? transferId, String? status}) =>
      _ledger.answers[requestId] = (
        requestId: requestId,
        movements: movements,
        transferId: transferId,
        status: status,
      );

  @override
  Future<StockCommandResult> transfer(String workspaceId, List<StockLineDraft> lines, String requestId) async {
    if (_ledger.answers[requestId] case final done?) return done;
    if (!_mine(workspaceId) || lines.isEmpty) throw _refused('request', StockRefusal.malformed);
    final places = await _real();
    final all = (await _config.places(workspaceId)).toList();
    final asked = <({StockItem item, ExactQuantity quantity})>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final to = l.toLocationId;
      if (!places.containsKey(l.fromLocationId) || to == null || !places.containsKey(to) || to == l.fromLocationId) {
        throw _refused('lines[$i]', StockRefusal.locationForeign);
      }
      if (stockSiteOf(l.fromLocationId, all) != stockSiteOf(to, all)) {
        throw _refused('lines[$i]', StockRefusal.transferNeedsTransit);
      }
      asked.add(await _quantity(l, i));
    }
    _checkOnHand(asked, [for (final l in lines) l.fromLocationId]);
    for (var i = 0; i < lines.length; i++) {
      await _ledger.post(
        DemoStockPost(item: asked[i].item, quantity: asked[i].quantity, from: lines[i].fromLocationId, to: lines[i].toLocationId!, reason: 'transfer'),
      );
    }
    return _answer(requestId, lines.length);
  }

  @override
  Future<StockCommandResult> load(
    String workspaceId,
    String toLocationId,
    List<StockLineDraft> lines,
    String requestId,
  ) async {
    if (_ledger.answers[requestId] case final done?) return done;
    if (!_mine(workspaceId) || lines.isEmpty) throw _refused('request', StockRefusal.malformed);
    final places = await _real();
    final all = (await _config.places(workspaceId)).toList();
    if (!places.containsKey(toLocationId)) throw _refused('to_location_id', StockRefusal.locationForeign);
    if (lines.map((l) => l.fromLocationId).toSet().length > 1) throw _refused('lines', StockRefusal.oneSource);
    final from = lines.first.fromLocationId;
    if (!places.containsKey(from)) throw _refused('lines[0]', StockRefusal.locationForeign);
    if (stockSiteOf(from, all) == stockSiteOf(toLocationId, all)) throw _refused('to_location_id', StockRefusal.sameSite);
    final asked = <({StockItem item, ExactQuantity quantity})>[
      for (var i = 0; i < lines.length; i++) await _quantity(lines[i], i),
    ];
    _checkOnHand(asked, [for (final _ in lines) from]);
    final loaded = <String, ExactQuantity>{};
    for (final a in asked) {
      await _ledger.post(
        DemoStockPost(item: a.item, quantity: a.quantity, from: from, to: _transit, reason: 'transfer'),
      );
      loaded[a.item.id] = (loaded[a.item.id] ?? ExactQuantity.zero) + a.quantity;
    }
    final id = _ledger.nextTransferId();
    _ledger.addTransfer(
      StockTransfer(
        id: id,
        fromLocationId: from,
        fromCode: places[from]!.code,
        toLocationId: toLocationId,
        toCode: places[toLocationId]!.code,
        status: 'loaded',
        loadedAt: _ledger.today,
        revision: 1,
        lines: [
          for (final e in loaded.entries)
            StockTransferLine(
              id: _ledger.nextLineId(),
              itemId: e.key,
              itemName: _ledger.itemOf(e.key)!.name,
              unit: _ledger.itemOf(e.key)!.unit,
              loaded: e.value,
              received: ExactQuantity.zero,
            ),
        ],
      ),
    );
    return _answer(requestId, lines.length, transferId: id, status: 'loaded');
  }

  @override
  Future<StockCommandResult> receive(
    String workspaceId,
    String transferId,
    List<StockReceiveDraft> lines,
    String requestId,
  ) async {
    if (_ledger.answers[requestId] case final done?) return done;
    if (!_mine(workspaceId) || lines.isEmpty) throw _refused('request', StockRefusal.malformed);
    final transfer = _ledger.transfer(transferId);
    if (transfer == null) throw _refused('transfer', StockRefusal.transferUnknown);
    final places = await _real();
    final all = (await _config.places(workspaceId)).toList();
    final received = {for (final l in transfer.lines) l.id: l.received};
    final plan = <({StockTransferLine line, ExactQuantity quantity, String to})>[];
    for (var i = 0; i < lines.length; i++) {
      final d = lines[i];
      final line = transfer.lines.where((l) => l.id == d.lineId).firstOrNull;
      if (line == null) throw _refused('lines[$i].line_id', StockRefusal.transferUnknown);
      final ExactQuantity quantity;
      try {
        quantity = ExactQuantity.parse(d.quantity);
      } on ExactQuantityException {
        throw _refused('lines[$i].quantity', StockRefusal.quantityInvalid);
      }
      if (quantity <= ExactQuantity.zero) throw _refused('lines[$i].quantity', StockRefusal.quantityInvalid);
      final sofar = received[line.id]! + quantity;
      if (sofar > line.loaded) throw _refused('lines[$i].quantity', StockRefusal.receiveOver);
      received[line.id] = sofar;
      final to = d.toLocationId ?? transfer.toLocationId;
      if (!places.containsKey(to) || stockSiteOf(to, all) != stockSiteOf(transfer.toLocationId, all)) {
        throw _refused('lines[$i].to', StockRefusal.wrongSite);
      }
      plan.add((line: line, quantity: quantity, to: to));
    }
    for (final p in plan) {
      await _ledger.post(
        DemoStockPost(item: _ledger.itemOf(p.line.itemId)!, quantity: p.quantity, from: _transit, to: p.to, reason: 'transfer'),
      );
    }
    final open = transfer.lines.any((l) => received[l.id]! < l.loaded);
    final status = open ? 'partly_received' : 'received';
    _ledger.replaceTransfer(
      StockTransfer(
        id: transfer.id,
        fromLocationId: transfer.fromLocationId,
        fromCode: transfer.fromCode,
        toLocationId: transfer.toLocationId,
        toCode: transfer.toCode,
        status: status,
        loadedAt: transfer.loadedAt,
        revision: transfer.revision + 1,
        lines: [
          for (final l in transfer.lines)
            StockTransferLine(
              id: l.id,
              itemId: l.itemId,
              itemName: l.itemName,
              unit: l.unit,
              variantId: l.variantId,
              lotId: l.lotId,
              loaded: l.loaded,
              received: received[l.id]!,
            ),
        ],
      ),
    );
    return _answer(requestId, plan.length, transferId: transfer.id, status: status);
  }

  @override
  Future<StockCommandResult> takeOut(
    String workspaceId,
    StockTakeOutReason reason,
    List<StockLineDraft> lines,
    String requestId,
  ) async {
    if (_ledger.answers[requestId] case final done?) return done;
    if (!_mine(workspaceId) || lines.isEmpty) throw _refused('request', StockRefusal.malformed);
    final places = await _real();
    final asked = <({StockItem item, ExactQuantity quantity})>[];
    for (var i = 0; i < lines.length; i++) {
      if (!places.containsKey(lines[i].fromLocationId)) throw _refused('lines[$i]', StockRefusal.locationForeign);
      asked.add(await _quantity(lines[i], i));
    }
    _checkOnHand(asked, [for (final l in lines) l.fromLocationId]);
    for (var i = 0; i < lines.length; i++) {
      await _ledger.post(
        DemoStockPost(item: asked[i].item, quantity: asked[i].quantity, from: lines[i].fromLocationId, to: _loss, reason: reason.name),
      );
    }
    return _answer(requestId, lines.length);
  }

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
