// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the ONE stock ledger of the domain: what each item holds at each place (and lot), the movements that made
// it, the transfers on their way, the returns and the counts, and the rules a command meets before anything moves.
// It does no I/O: the items, the places and the packaging units it judges against are read through the functions it
// is given. The server stays the authority. Every rule here mirrors the SQL it cites (0747 stock_to_inventory, 0847
// stock_apply_lines and the typed commands, 0867 stock_return_v1, 0870 the counts, 0951/0952 the business's units),
// and test/parity/stock_contract_test.dart runs one table of scenarios against this ledger and, as pgTAP 568, against
// the RPCs. What a command refuses it refuses whole and moves nothing. Where the server refuses with a code of its
// own and no reason (DKG04 an unknown item, DKG05 a place, DKG07 a quantity, DKG02 a unit), a stock command names the
// reason the screens word for it (item_foreign, location_foreign, quantity_invalid, unit_unmapped).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../core/codes/dk_code.dart';
import 'stock_config.dart';
import 'stock_operations.dart';
import 'stock_page.dart';
import 'stock_receiving.dart';
import 'stock_reversals.dart';
import 'stock_sites.dart';
import 'stock_where_is.dart';

/// One movement to book: [quantity] (inventory unit) of [item] from [from] to [to], with what the person entered
/// beside it.
class StockPost {
  const StockPost({
    required this.item,
    required this.quantity,
    required this.from,
    required this.to,
    required this.reason,
    this.lotId,
    this.lotCode,
    this.variantId,
    this.entered,
    this.enteredUnit,
    this.at,
    this.id,
    this.causes = const {},
  });

  final StockItem item;
  final ExactQuantity quantity;
  final String from;
  final String to;
  final String reason;
  final String? lotId;
  final String? lotCode;
  final String? variantId;
  final ExactQuantity? entered;
  final String? enteredUnit;

  /// When it happened; the ledger's clock when null.
  final DateTime? at;

  /// The movement's own address; a fresh one when null.
  final String? id;

  /// What caused it, by kind (`invoice`, ...), as the ledger links it.
  final Map<String, String> causes;
}

/// A refusal the server raises under a code of its own rather than with a reason: a return or a count (DKG04, DKG05,
/// DKG07, DKG16 to DKG20).
final class StockCodeRefused implements Exception {
  const StockCodeRefused(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'StockCodeRefused($code, $message)';
}

/// Which command a line belongs to: the in-transit place and the places a reason allows depend on it (0847
/// stock_apply_lines, p_mode).
enum _Mode { transfer, load, takeOut }

typedef _Ask = ({StockItem item, ExactQuantity quantity, String from, String to});
typedef _Key = ({StockItem item, String place, String? lotId, String? lotCode});
typedef _Planned = ({StockMovementRow source, ExactQuantity quantity, StockReturnLineDraft line});

final _quantityText = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// The in-memory goods ledger of one business.
class StockLedger {
  StockLedger(
    this.workspaceId, {
    required this._items,
    required this._places,
    required DateTime Function() clock,
    List<StockUnitDraft> Function(String itemId)? units,
    this.prefix = 'stock',
  }) : _units = units ?? ((_) => const []),
       _now = clock;

  /// The business that keeps the stock.
  final String workspaceId;

  /// What the addresses the ledger makes begin with.
  final String prefix;

  final Iterable<StockItem> Function() _items;
  final Map<String, StockPlaceConfig> Function() _places;
  final List<StockUnitDraft> Function(String itemId) _units;
  final DateTime Function() _now;

  /// What a retried request id answered.
  final Map<String, StockCommandResult> _answers = {};

  final Map<String, ExactQuantity> _balances = {};
  final Map<String, _Key> _keys = {};
  final List<StockMovementRow> _movements = [];
  final List<StockTransfer> _transfers = [];
  int _next = 100;

  bool mine(String id) => id == workspaceId;

  /// The ledger's day (its own clock, read once per use).
  DateTime get today => _now();

  /// The movements, newest first.
  List<StockMovementRow> get movements => List.unmodifiable(_movements);

  StockItem? itemOf(String id) => _items().where((i) => i.id == id).firstOrNull;

  /// What an item holds at one place (and lot), exactly.
  ExactQuantity balance(String itemId, String place, {String? lotId}) =>
      _balances[_key(itemId, place, lotId)] ?? ExactQuantity.zero;

  String _key(String itemId, String place, String? lotId) => '$itemId|$place|${lotId ?? ''}';

  /// What [itemId] holds at [place] in all, loose or in a lot.
  ExactQuantity held(String itemId, String place) {
    var total = ExactQuantity.zero;
    for (final MapEntry(:key, :value) in _keys.entries) {
      if (value.item.id == itemId && value.place == place) total = total + (_balances[key] ?? ExactQuantity.zero);
    }
    return total;
  }

  /// The lots of [itemId] with something at [place], as received (a lot without a code is no track ID and is not here).
  List<({String id, String code, ExactQuantity quantity})> lotsAt(String itemId, String place) => [
    for (final MapEntry(:key, :value) in _keys.entries)
      if (value.item.id == itemId && value.place == place && value.lotId != null && (value.lotCode ?? '').isNotEmpty &&
          ExactQuantity.zero < (_balances[key] ?? ExactQuantity.zero))
        (id: value.lotId!, code: value.lotCode!, quantity: _balances[key]!),
  ];

  /// The code a place is read by.
  String codeOf(String id) => _places()[id]?.code ?? id;

  /// A place that holds goods: a real one or the road. The supplier, the customer, the loss and the opening place
  /// are the server's and hold whatever (0747 stock_place_is_virtual; the in-transit place is counted, 0847:743).
  static bool _holds(StockPlaceConfig p) => !p.virtual || p.inTransit;

  String _placeOfKind(String kind) => _places().values.firstWhere((p) => p.kind == kind).id;

  /// What is on hand where, items in the order of [order] (then as first used), places as first used.
  List<StockOnHandRow> onHand({String? itemId, String? locationId, List<String> order = const []}) {
    final places = _places();
    final rows = <StockOnHandRow>[
      for (final MapEntry(:key, value: k) in _keys.entries)
        if ((_balances[key] ?? ExactQuantity.zero) != ExactQuantity.zero &&
            (itemId == null || k.item.id == itemId) &&
            (locationId == null || k.place == locationId))
          StockOnHandRow(
            workspaceId: workspaceId,
            itemId: k.item.id,
            itemName: k.item.name,
            lotId: k.lotId,
            lotCode: k.lotCode,
            locationId: k.place,
            locationCode: places[k.place]?.code ?? '',
            locationName: places[k.place]?.name ?? '',
            quantity: _balances[key]!,
            unit: k.item.unit,
          ),
    ];
    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final indexed = [for (var i = 0; i < rows.length; i++) (i, rows[i])]
      ..sort((a, b) {
        final c = (rank[a.$2.itemId] ?? 99).compareTo(rank[b.$2.itemId] ?? 99);
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, r) in indexed) r];
  }

  /// Books [p] whatever the source holds: the opening story and the parts of a command already checked.
  StockMovementRow book(StockPost p) {
    _add(p.item, p.from, p.lotId, p.lotCode, -p.quantity);
    _add(p.item, p.to, p.lotId, p.lotCode, p.quantity);
    final row = StockMovementRow(
      workspaceId: workspaceId,
      id: p.id ?? '$prefix-stock-movement-${_next++}',
      itemId: p.item.id,
      itemName: p.item.name,
      lotId: p.lotId,
      lotCode: p.lotCode,
      fromLocationId: p.from,
      fromLocationCode: codeOf(p.from),
      toLocationId: p.to,
      toLocationCode: codeOf(p.to),
      quantity: p.quantity,
      unit: p.item.unit,
      enteredQuantity: p.entered ?? p.quantity,
      enteredUnit: p.enteredUnit ?? p.item.unit,
      occurredAt: p.at ?? _now(),
      reason: p.reason,
      unitCost: null,
      causes: p.causes,
      variantId: p.variantId,
    );
    _movements.insert(0, row);
    return row;
  }

  /// Books [p]. A place that holds goods and holds less than asked refuses it, whole (0747 stock_movements_apply:
  /// the balance never goes below zero, DKG03).
  StockMovementRow post(StockPost p) {
    final source = _places()[p.from];
    if (source != null && _holds(source)) {
      final held = balance(p.item.id, p.from, lotId: p.lotId);
      if (held < p.quantity) throw StockNotEnough('${held.text} of ${p.quantity.text} are there');
    }
    return book(p);
  }

  void _add(StockItem item, String place, String? lotId, String? lotCode, ExactQuantity delta) {
    final config = _places()[place];
    if (config != null && !_holds(config)) return;
    final k = _key(item.id, place, lotId);
    _keys.putIfAbsent(k, () => (item: item, place: place, lotId: lotId, lotCode: lotCode));
    _balances[k] = (_balances[k] ?? ExactQuantity.zero) + delta;
  }

  /// The movements of [itemId] (of its lot [lotId]) up to [at], newest first.
  List<StockMovementRow> movesOf(String itemId, {String? lotId, DateTime? at}) => [
    for (final m in _movements)
      if (m.itemId == itemId && (lotId == null || m.lotId == lotId) && (at == null || !m.occurredAt.isAfter(at))) m,
  ];

  /// Where [moves] left the goods: each adds to the place it went to and takes from the one it left, the server's
  /// own places included (0926 stock_where_is_v1 replays the movements the same way). A place with nothing is left
  /// out; the real places come first, then by code.
  List<WhereIsPlace> whereIs(List<StockMovementRow> moves) {
    final places = _places();
    final held = <String, ({String place, String? lotId, String? lotCode, ExactQuantity quantity})>{};
    void add(StockMovementRow m, String place, ExactQuantity q) {
      final key = '$place|${m.lotId ?? ''}';
      held[key] = (place: place, lotId: m.lotId, lotCode: m.lotCode, quantity: (held[key]?.quantity ?? ExactQuantity.zero) + q);
    }

    for (final m in moves) {
      add(m, m.toLocationId, m.quantity);
      add(m, m.fromLocationId, ExactQuantity.zero - m.quantity);
    }
    return [
      for (final h in held.values)
        if (h.quantity != ExactQuantity.zero)
          WhereIsPlace(
            locationId: h.place,
            locationCode: places[h.place]?.code ?? '',
            locationName: places[h.place]?.name ?? '',
            locationKind: places[h.place]?.kind ?? '',
            isVirtual: places[h.place]?.virtual ?? false,
            quantity: h.quantity,
            lotId: h.lotId,
            lotCode: h.lotCode,
          ),
    ]..sort((a, b) {
      if (a.isVirtual != b.isVirtual) return a.isVirtual ? 1 : -1;
      return a.locationCode.compareTo(b.locationCode);
    });
  }

  // ── the transfers on their way ──────────────────────────────────────────

  /// The transfers not fully received, oldest first.
  List<StockTransfer> get openTransfers => [for (final t in _transfers) if (t.open) t];

  StockTransfer? transfer(String id) => _transfers.where((t) => t.id == id).firstOrNull;

  void addTransfer(StockTransfer t) => _transfers.add(t);

  // ── the commands ────────────────────────────────────────────────────────

  /// What [requestId] answered, or [run]'s answer kept for it: a retried request does nothing twice (0847
  /// purchase_request_begin).
  StockCommandResult once(String requestId, StockCommandResult Function() run) =>
      _answers[requestId] ??= run();

  /// A quantity as the server reads it: up to twelve digits and six decimals, above zero (0847:511, 0847:835).
  static ExactQuantity quantityOf(String text, String field) {
    final q = _quantityText.hasMatch(text) ? ExactQuantity.tryParse(text).value : null;
    if (q == null || q <= ExactQuantity.zero) throw StockConfigRefused(field, StockRefusal.quantityInvalid);
    return q;
  }

  /// [entered] in [unit] as [item]'s inventory unit: its own unit as it is, a packaging unit by its exact factor,
  /// any other refused (0747 stock_to_inventory:317-330, read per business since 0952), kept to six decimals as the
  /// movement stores it (numeric(18, 6), 0840:355).
  ExactQuantity toInventory(StockItem item, ExactQuantity entered, String? unit, int i) {
    if (unit == null || unit == item.unit) return entered;
    final factor = _units(item.id).where((u) => u.unit == unit).firstOrNull;
    if (factor == null) throw StockConfigRefused('lines[$i].unit', StockRefusal.unitUnmapped);
    final converted = entered.scaled(factor.factorNum, factor.factorDen, round: true).value;
    if (converted == null) throw StockConfigRefused('lines[$i].quantity', StockRefusal.quantityInvalid);
    return converted;
  }

  /// A command has 1 to 200 lines (0847 stock_command_args:662).
  static void _count(List<Object> lines) {
    if (lines.isEmpty || lines.length > 200) throw const StockConfigRefused('request', StockRefusal.malformed);
  }

  /// A place the server counts as virtual: the in-transit place is not (0747 stock_location_kinds).
  static bool _virtual(StockPlaceConfig p) => p.virtual && !p.inTransit;

  /// One line as 0847 stock_apply_lines reads it, in its order: the item (DKG04, 0847:467-471), two distinct active
  /// places of the business (DKG05, 0847:476-483), the in-transit place for the two-step transfer only
  /// (0847:487-490), the places the reason allows (0847:491-504), one step only inside a site (0847:505-509), a
  /// quantity above zero (0847:511-513) and its unit (0847:515-516).
  _Ask _ask(int i, StockLineDraft l, String? toId, _Mode mode) {
    final item = itemOf(l.itemId);
    if (item == null) throw StockConfigRefused('lines[$i].item_id', StockRefusal.itemForeign);
    final places = _places();
    final from = places[l.fromLocationId];
    final to = toId == null ? null : places[toId];
    if (from == null || to == null || !from.active || !to.active || from.id == to.id) {
      throw StockConfigRefused('lines[$i]', StockRefusal.locationForeign);
    }
    if ((from.inTransit || to.inTransit) && mode != _Mode.load) {
      throw StockConfigRefused('lines[$i]', StockRefusal.transitIsSystem);
    }
    final fits = switch (mode) {
      _Mode.transfer || _Mode.load => !_virtual(from) && !_virtual(to),
      _Mode.takeOut => !_virtual(from) && to.kind == 'loss',
    };
    if (!fits) throw StockConfigRefused('lines[$i]', StockRefusal.reasonPlaces);
    if (mode == _Mode.transfer && stockSiteOf(from.id, places.values) != stockSiteOf(to.id, places.values)) {
      throw StockConfigRefused('lines[$i]', StockRefusal.transferNeedsTransit);
    }
    final entered = quantityOf(l.quantity, 'lines[$i].quantity');
    return (item: item, quantity: toInventory(item, entered, l.unit, i), from: from.id, to: to.id);
  }

  /// Refuses, whole, when a source holds less than the lines together ask (0847 stock_take: the request is one
  /// transaction, DKG03).
  void _enough(List<_Ask> asked) {
    final need = <String, ExactQuantity>{};
    for (final a in asked) {
      final key = '${a.item.id}|${a.from}';
      need[key] = (need[key] ?? ExactQuantity.zero) + a.quantity;
    }
    for (final e in need.entries) {
      final [item, place] = e.key.split('|');
      final held = balance(item, place);
      if (held < e.value) throw StockNotEnough('${held.text} of ${e.value.text} are there');
    }
  }

  List<StockMovementRow> _move(List<_Ask> asked, String reason) => [
    for (final a in asked) post(StockPost(item: a.item, quantity: a.quantity, from: a.from, to: a.to, reason: reason)),
  ];

  /// One step between two places of one site (0847 stock_transfer_v1, mode transfer_one).
  List<StockMovementRow> transferInSite(List<StockLineDraft> lines) {
    _count(lines);
    final asked = [for (var i = 0; i < lines.length; i++) _ask(i, lines[i], lines[i].toLocationId, _Mode.transfer)];
    _enough(asked);
    return _move(asked, 'transfer');
  }

  /// Goods loaded for another site: they leave their one source for the in-transit place and a transfer remembers
  /// each item (0847 stock_transfer_load_v1:760-792).
  StockTransfer load(String toLocationId, List<StockLineDraft> lines) {
    _count(lines);
    final places = _places();
    final to = places[toLocationId];
    // a real, active place of the business, not the road (0847:764-768)
    if (to == null || !to.active || _virtual(to) || to.inTransit) {
      throw const StockConfigRefused('to_location_id', StockRefusal.locationForeign);
    }
    // one source place per transfer (0847:770-772)
    if (lines.map((l) => l.fromLocationId).toSet().length > 1) throw const StockConfigRefused('lines', StockRefusal.oneSource);
    final from = lines.first.fromLocationId;
    // two steps are for goods that change site (0847:775-777)
    if (stockSiteOf(toLocationId, places.values) == stockSiteOf(from, places.values)) {
      throw const StockConfigRefused('to_location_id', StockRefusal.sameSite);
    }
    final transit = _placeOfKind('in_transit');
    final asked = [for (var i = 0; i < lines.length; i++) _ask(i, lines[i], transit, _Mode.load)];
    _enough(asked);
    _move(asked, 'transfer');
    final loaded = <String, ExactQuantity>{};
    for (final a in asked) {
      loaded[a.item.id] = (loaded[a.item.id] ?? ExactQuantity.zero) + a.quantity;
    }
    final t = StockTransfer(
      id: '$prefix-transfer-${_next++}',
      fromLocationId: from,
      fromCode: codeOf(from),
      toLocationId: toLocationId,
      toCode: codeOf(toLocationId),
      status: 'loaded',
      loadedAt: today,
      revision: 1,
      lines: [
        for (final e in loaded.entries)
          StockTransferLine(
            id: '$prefix-transfer-line-${_next++}',
            itemId: e.key,
            itemName: itemOf(e.key)!.name,
            unit: itemOf(e.key)!.unit,
            loaded: e.value,
            received: ExactQuantity.zero,
          ),
      ],
    );
    _transfers.add(t);
    return t;
  }

  /// What was loaded, received all or in part onto a real place of the destination's site; what is not received
  /// stays on the road (0847 stock_transfer_receive_v1:819-863). Answers the transfer as it now stands and the
  /// movements made.
  ({StockTransfer transfer, int movements}) receive(String transferId, List<StockReceiveDraft> lines) {
    _count(lines);
    final transfer = this.transfer(transferId);
    if (transfer == null) throw const StockConfigRefused('transfer', StockRefusal.transferUnknown);
    final places = _places();
    final received = {for (final l in transfer.lines) l.id: l.received};
    final plan = <({StockTransferLine line, ExactQuantity quantity, String to})>[];
    for (var i = 0; i < lines.length; i++) {
      final d = lines[i];
      final line = transfer.lines.where((l) => l.id == d.lineId).firstOrNull;
      if (line == null) throw StockConfigRefused('lines[$i].line_id', StockRefusal.transferUnknown);
      final quantity = quantityOf(d.quantity, 'lines[$i].quantity');
      // never more than is still on its way, an earlier line of this request counted (0847:839-841)
      final sofar = received[line.id]! + quantity;
      if (sofar > line.loaded) throw StockConfigRefused('lines[$i].quantity', StockRefusal.receiveOver);
      received[line.id] = sofar;
      // a real place of the destination's own site (0847:844-850)
      final to = d.toLocationId ?? transfer.toLocationId;
      final place = places[to];
      if (place == null || !place.active || _virtual(place) || place.inTransit ||
          stockSiteOf(to, places.values) != stockSiteOf(transfer.toLocationId, places.values)) {
        throw StockConfigRefused('lines[$i].to', StockRefusal.wrongSite);
      }
      plan.add((line: line, quantity: quantity, to: to));
    }
    final transit = _placeOfKind('in_transit');
    for (final p in plan) {
      post(StockPost(item: itemOf(p.line.itemId)!, quantity: p.quantity, from: transit, to: p.to, reason: 'transfer'));
    }
    final open = transfer.lines.any((l) => received[l.id]! < l.loaded);
    final now = StockTransfer(
      id: transfer.id,
      fromLocationId: transfer.fromLocationId,
      fromCode: transfer.fromCode,
      toLocationId: transfer.toLocationId,
      toCode: transfer.toCode,
      status: open ? 'partly_received' : 'received',
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
    );
    _transfers[_transfers.indexWhere((t) => t.id == transfer.id)] = now;
    return (transfer: now, movements: plan.length);
  }

  /// Goods taken out for use or as a loss, to the loss place (0847 stock_take_out:694-717, mode take_out).
  List<StockMovementRow> takeOut(StockTakeOutReason reason, List<StockLineDraft> lines) {
    _count(lines);
    final loss = _placeOfKind('loss');
    final asked = [for (var i = 0; i < lines.length; i++) _ask(i, lines[i], loss, _Mode.takeOut)];
    _enough(asked);
    return _move(asked, reason.name);
  }

  // ── a delivery put away (0840 stock_put_away_apply) ──────────────────────

  /// One allocation [i] of a put-away as 0840 stock_put_away_apply reads it, in its order: a stock item
  /// (0840:330), the order line's unit by its exact factor (0840:332-338), a quantity above zero (0840:340-345),
  /// never more than [left] of what the line received, earlier allocations counted (0840:347-351), a real place of the
  /// business (0840:372-374), a variant when the item has some (0840:368-369), and the lot code and the date its
  /// tracking asks for (0840:391-399). Answers the quantity in the line's unit and in the inventory unit.
  ({ExactQuantity entered, ExactQuantity inventory}) putAwayPart(
    int i, {
    required StockItemConfig? item,
    required String unit,
    required PutAwayAllocation part,
    required ExactQuantity left,
    required bool hasVariants,
  }) {
    if (item == null || !item.stockable) throw StockConfigRefused('allocations[$i].line', StockRefusal.itemNotStocked);
    final factor = unit == item.inventoryUnit
        ? (1, 1)
        : item.units.where((u) => u.unit == unit).map((u) => (u.factorNum, u.factorDen)).firstOrNull;
    if (factor == null) throw StockConfigRefused('allocations[$i].line', StockRefusal.unitUnmapped);
    final qty = ExactQuantity.tryParse(part.quantity).value;
    if (qty == null || qty <= ExactQuantity.zero) throw StockConfigRefused('allocations[$i].quantity', StockRefusal.quantityInvalid);
    // in the inventory unit, as the server records it: round(q * num / den, 6) (0840:355)
    final inventory = qty.scaled(factor.$1, factor.$2, round: true).value;
    if (inventory == null || inventory <= ExactQuantity.zero) {
      throw StockConfigRefused('allocations[$i].quantity', StockRefusal.quantityInvalid);
    }
    if (qty > left) throw StockConfigRefused('allocations[$i].quantity', StockRefusal.overAllocated);
    if (!_real(part.locationId)) throw StockConfigRefused('allocations[$i].location_id', StockRefusal.locationForeign);
    if (hasVariants && part.variantId == null) throw StockConfigRefused('allocations[$i].variant_id', StockRefusal.variantRequired);
    if ((item.tracking == 'lot' || item.tracking == 'expiry') && (part.lotCode ?? '').isEmpty) {
      throw StockConfigRefused('allocations[$i].lot.code', StockRefusal.lotCodeRequired);
    }
    if (item.tracking == 'expiry' && part.expiresOn == null) {
      throw StockConfigRefused('allocations[$i].lot.expires_on', StockRefusal.expiryRequired);
    }
    return (entered: qty, inventory: inventory);
  }

  // ── reorder points (0856) ────────────────────────────────────────────────

  /// A quantity of a reorder point's payload as 0856:358-365 reads it: absent keeps [fallback], empty clears, any
  /// other text is a quantity of up to twelve digits and six decimals.
  static ExactQuantity? reorderQuantityOf(Map<String, Object?> point, String key, ExactQuantity? fallback) {
    if (!point.containsKey(key)) return fallback;
    final text = (point[key] as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    if (!_quantityText.hasMatch(text)) throw StockConfigRefused(key, StockRefusal.quantityInvalid);
    return ExactQuantity.parse(text);
  }

  /// What to order when an item is low (0856:441-446): a level; then a quantity above zero or a level to order up
  /// to above the point, not both.
  static ExactQuantity reorderRule(ExactQuantity? level, ExactQuantity? quantity, ExactQuantity? target) {
    if (level == null) throw const StockConfigRefused('reorder_point', StockRefusal.quantityInvalid);
    if (quantity != null && target != null) throw const StockConfigRefused('target_quantity', StockRefusal.quantityAndTarget);
    if (quantity != null && quantity.compareTo(ExactQuantity.zero) <= 0) {
      throw const StockConfigRefused('reorder_quantity', StockRefusal.quantityInvalid);
    }
    if (target != null && target.compareTo(level) <= 0) throw const StockConfigRefused('target_quantity', StockRefusal.targetBelowPoint);
    return level;
  }

  /// What [itemId] holds in all at the site [siteId] and every place inside it, loose and in lots (0856, what is
  /// low is read from the whole site).
  ExactQuantity heldInSite(String itemId, String siteId) {
    final places = _places();
    var total = ExactQuantity.zero;
    for (final MapEntry(:key, :value) in _keys.entries) {
      if (value.item.id == itemId && stockSiteOf(value.place, places.values) == siteId) {
        total = total + (_balances[key] ?? ExactQuantity.zero);
      }
    }
    return total;
  }

  // ── returns and corrections (0867 stock_return_v1) ───────────────────────

  /// What was reversed on each movement, in the order it was done.
  final Map<String, List<StockReversalEntry>> _bySource = {};

  /// Each logical return: its content and what it answered.
  final Map<String, ({String digest, StockReturnResult result})> _returns = {};

  ExactQuantity _reversed(String movementId) => [
    for (final e in _bySource[movementId] ?? const <StockReversalEntry>[]) e.quantity,
  ].fold(ExactQuantity.zero, (a, b) => a + b);

  StockMovementRow? _movement(String id) => _movements.where((m) => m.id == id).firstOrNull;

  /// What each of [movementIds] allows to be reversed (0867 stock_reversible_v1).
  Map<String, StockReversible> reversible(List<String> movementIds) => {
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
      final row = post(
        StockPost(
          item: itemOf(p.source.itemId)!,
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
      final source = _movement(l.sourceMovementId);
      // a movement of this business, of an item it keeps (0867:309-313)
      if (source == null || itemOf(source.itemId) == null) {
        throw const StockCodeRefused(DkCode.dkg04, 'a line names a movement of another business or none');
      }
      final ExactQuantity quantity;
      try {
        quantity = quantityOf(l.quantity, 'quantity');
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

  /// A place of this business the goods can really be at: active, not virtual, not the road.
  bool _real(String? id) {
    final p = _places()[id];
    return p != null && p.active && !p.virtual && !p.inTransit;
  }

  /// What each kind follows, and the place its line names (0867:337-366).
  void _kindAllows(StockReturnKind kind, StockMovementRow source, StockReturnLineDraft l) {
    final places = _places();
    switch (kind) {
      case StockReturnKind.customer:
        // the sale went to a place of the customer kind (0867:338-341)
        if (source.reason != 'sale' || places[source.toLocationId]?.kind != 'customer') {
          throw const StockCodeRefused(DkCode.dkg18, 'a customer return follows a sale');
        }
        if (!_real(l.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'the goods come back to a real place');
      case StockReturnKind.supplier:
        if (source.reason != 'receipt') throw const StockCodeRefused(DkCode.dkg18, 'a supplier return follows a receipt');
        if (!_real(l.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'the goods leave from a real place');
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
      _movements.where((m) => m.itemId == itemId && (m.fromLocationId == place || m.toLocationId == place)).length;

  /// The counts, newest first.
  List<StockCountRow> get counts => [for (final c in _counts.reversed) c.row(_moves(c.itemId, c.locationId))];

  /// Records what [draft] observed against what the ledger holds, by [author]. The same count sent again changes
  /// nothing; other content under its identity is refused (0870:184-232).
  void recordCount(StockCountDraft draft, {required String author}) {
    if (!_quantityText.hasMatch(draft.observed)) throw const StockCodeRefused(DkCode.dkg07, 'a count has a quantity');
    final observed = ExactQuantity.parse(draft.observed);
    final known = _counts.where((c) => c.countId == draft.countId).firstOrNull;
    if (known != null) {
      if (known.itemId != draft.itemId || known.locationId != draft.locationId || known.observed != observed) {
        throw const StockCodeRefused(DkCode.dkg16, 'this count was already recorded with other content');
      }
      return;
    }
    if (itemOf(draft.itemId) == null) throw const StockCodeRefused(DkCode.dkg04, 'not a stock item of this business');
    if (!_real(draft.locationId)) throw const StockCodeRefused(DkCode.dkg05, 'a count is taken at a real place of this business');
    _counts.add(
      _Count(
        countId: draft.countId,
        itemId: draft.itemId,
        locationId: draft.locationId,
        observed: observed,
        baseline: balance(draft.itemId, draft.locationId, lotId: draft.lotId),
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
      final item = itemOf(c.itemId)!;
      final loss = _placeOfKind('loss');
      if (diff > ExactQuantity.zero) {
        c.movementId = post(StockPost(item: item, quantity: diff, from: loss, to: c.locationId, reason: 'adjustment')).id;
      } else if (diff < ExactQuantity.zero) {
        c.movementId = post(StockPost(item: item, quantity: ExactQuantity.zero - diff, from: c.locationId, to: loss, reason: 'adjustment')).id;
      }
    }
    c
      ..state = state
      ..decider = decider
      ..decidedAt = today;
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
