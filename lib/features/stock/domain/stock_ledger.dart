// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4403 -- the ONE stock ledger of the domain: what each item holds at each place (and lot), the movements that made
// it, the transfers on their way, and the rules a command meets before anything moves (the returns and counts:
// stock_reversal_book.dart; the rules that only read it: stock_ledger_rules.dart).
// It does no I/O: the items, the places and the packaging units it judges against are read through the functions it
// is given. The server stays the authority. Every rule here mirrors the SQL it cites (0747 stock_to_inventory, 0847
// stock_apply_lines and the typed commands, 0867 stock_return_v1, 0870 the counts, 0951/0952 the business's units),
// and test/parity/stock_contract_test.dart runs one table of scenarios against this ledger and, as pgTAP 568, against
// the RPCs. What a command refuses it refuses whole and moves nothing. Where the server refuses with a code of its
// own and no reason (DKG04 an unknown item, DKG05 a place, DKG07 a quantity, DKG02 a unit), a stock command names the
// reason the screens word for it (item_foreign, location_foreign, quantity_invalid, unit_unmapped).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'stock_config.dart';
import 'stock_operations.dart';
import 'stock_page.dart';
import 'stock_sites.dart';
import 'unit_conversions.dart';

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
    this.lossCause,
    this.lossNote,
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

  /// Why the goods of a loss were lost, by the server's key, and the note beside it.
  final String? lossCause;
  final String? lossNote;
}

/// Which command a line belongs to: the in-transit place and the places a reason allows depend on it (0847
/// stock_apply_lines, p_mode).
enum _Mode { transfer, load, takeOut }

typedef _Ask = ({StockItem item, ExactQuantity quantity, String from, String to});
typedef _Key = ({StockItem item, String place, String? lotId, String? lotCode});

final _quantityText = RegExp(r'^[0-9]{1,12}(\.[0-9]{1,6})?$');

/// The in-memory goods ledger of one business.
class StockLedger {
  StockLedger(
    this.workspaceId, {
    required this._items,
    required this._places,
    required DateTime Function() clock,
    List<StockUnitDraft> Function(String itemId)? units,
    Iterable<UnitConversion> Function()? conversions,
    this.prefix = 'stock',
  }) : _units = units ?? ((_) => const []),
       _conversions = conversions ?? (() => builtInConversions),
       _now = clock;

  /// The business that keeps the stock.
  final String workspaceId;

  /// What the addresses the ledger makes begin with.
  final String prefix;

  final Iterable<StockItem> Function() _items;
  final Map<String, StockPlaceConfig> Function() _places;
  final List<StockUnitDraft> Function(String itemId) _units;

  /// The business's general conversions (1 kg = 1000 g): what an entered unit may convert through when the item has no conversion of its own.
  final Iterable<UnitConversion> Function() _conversions;

  /// #4479 -- the factor of [unit] to the inventory unit of [item] (its own conversion, else the business's general one, one step); null: none.
  ({int num, int den})? configFactor(StockItemConfig item, String unit) =>
      unitFactor(from: unit, to: item.inventoryUnit, inventoryUnit: item.inventoryUnit, itemUnits: item.units, general: _conversions());
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

  /// The business's place of [kind] (`in_transit`, `loss`): the server keeps one of each.
  String placeOfKind(String kind) => _places().values.firstWhere((p) => p.kind == kind).id;

  /// The places of the business, by id.
  Map<String, StockPlaceConfig> get places => _places();

  /// A movement of the ledger by its address.
  StockMovementRow? movement(String id) => _movements.where((m) => m.id == id).firstOrNull;

  /// A place of this business the goods can really be at: active, not virtual, not the road.
  bool isReal(String? id) {
    final p = _places()[id];
    return p != null && p.active && !p.virtual && !p.inTransit;
  }

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
      lossCause: p.lossCause,
      lossNote: p.lossNote,
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

  /// [entered] in [unit] as [item]'s inventory unit: its own unit as it is, any other by the one defined conversion
  /// (`unitFactor`: the item's own, else the business's general one, one step), none defined refused (0968 unit_convert),
  /// kept to six decimals as the movement stores it (numeric(18, 6), 0840:355).
  ExactQuantity toInventory(StockItem item, ExactQuantity entered, String? unit, int i) {
    if (unit == null || unit == item.unit) return entered;
    final factor = unitFactor(from: unit, to: item.unit, inventoryUnit: item.unit, itemUnits: _units(item.id), general: _conversions());
    if (factor == null) throw StockConfigRefused('lines[$i].unit', StockRefusal.unitUnmapped);
    final converted = entered.scaled(factor.num, factor.den, round: true).value;
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

  List<StockMovementRow> _move(List<_Ask> asked, String reason, {StockLoss? loss}) => [
    for (final a in asked)
      post(StockPost(item: a.item, quantity: a.quantity, from: a.from, to: a.to, reason: reason, lossCause: loss?.cause.wire, lossNote: loss?.noteOrNull)),
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
    final transit = placeOfKind('in_transit');
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
    final transit = placeOfKind('in_transit');
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

  /// Goods taken out for use or as a loss, to the loss place (0847 stock_take_out:694-717, mode take_out). The
  /// movements of a loss keep why the goods were lost ([loss]); goods used keep nothing of it.
  List<StockMovementRow> takeOut(StockTakeOutReason reason, List<StockLineDraft> lines, {StockLoss? loss}) {
    _count(lines);
    final lossPlace = placeOfKind('loss');
    final asked = [for (var i = 0; i < lines.length; i++) _ask(i, lines[i], lossPlace, _Mode.takeOut)];
    _enough(asked);
    return _move(asked, reason.name, loss: reason == StockTakeOutReason.loss ? loss : null);
  }

}
