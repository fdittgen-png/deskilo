// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the Demo's ONE goods ledger. The reference business keeps a
// small shop stock (beans by the kilogram, oat milk by the litre, mugs, a syrup
// received in thirds of a litre) at a main store with a shelf and at a branch
// shop, with the movements behind each figure, one transfer already on its way
// and one sale of two mugs from the shelf to a customer (#4173: the movement a
// customer return reverses). The Stock screen's reads, a delivery put away from a purchase order and
// the transfer and take-out commands all read and write THIS object, so what
// one does is what the others show: a put-away raises the figure the Stock
// screen reads, a transfer moves it between the places and through the
// in-transit place, and nothing is invented twice. Quantities are exact. A
// source that holds less than asked refuses the whole command and moves
// nothing, as the server does. Another Demo business keeps no ledger.
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_candidates.dart';
import 'demo_stock_config_commands.dart';
import 'money/demo_standalone_invoice_commands.dart' show DemoInvoiceGoods;

const _beans = StockItem(id: 'demo-item-beans', name: 'Coffee beans', unit: 'kg');
const _milk = StockItem(id: 'demo-item-milk', name: 'Oat milk', unit: 'l');
const _mugs = StockItem(id: 'demo-item-mugs', name: 'Mugs', unit: 'piece');
const _syrup = StockItem(id: 'demo-item-syrup', name: 'Syrup', unit: 'l');
// A T-shirt with no stock yet: the item the Demo's variants are edited on.
const _shirt = StockItem(id: 'demo-item-shirt', name: 'T-shirt', unit: 'piece');
// #4362 -- a gift basket, each piece tagged one by one, and a crate of apples, one tag per crate.
const _basket = StockItem(id: 'demo-item-basket', name: 'Gift basket', unit: 'piece');
const _apples = StockItem(id: 'demo-item-apples', name: 'Apples, crate', unit: 'piece');

const _main = 'demo-place-main';
const _shelf = 'demo-place-shelf';
const _branch = 'demo-place-branch';
const _transit = 'demo-place-transit';
const _supplier = 'demo-place-supplier';
const _loss = 'demo-place-loss';
// #4433 -- the customer: goods sold on an invoice go there.
const _customer = 'demo-place-customer';

/// The server's own places that hold nothing: goods come from and go to them.
const _untracked = {_supplier, _loss, _customer};

/// One movement of the Demo's story: the item, what was stored and entered,
/// the reason, how long ago, where to, and from where (a supplier when none).
typedef _Story = ({
  int n,
  StockItem item,
  String stored,
  String enteredUnit,
  String entered,
  String reason,
  int daysAgo,
  String to,
  String? from,
});

const _stories = <_Story>[
  (n: 8, item: _mugs, stored: '6', enteredUnit: 'piece', entered: '6', reason: 'transfer', daysAgo: 0, to: _transit, from: _main),
  (n: 9, item: _mugs, stored: '2', enteredUnit: 'piece', entered: '2', reason: 'sale', daysAgo: 2, to: _customer, from: _shelf),
  (n: 7, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 3, to: _main, from: null),
  (n: 6, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 4, to: _main, from: null),
  (n: 5, item: _syrup, stored: '0.333333', enteredUnit: 'third', entered: '1', reason: 'receipt', daysAgo: 5, to: _main, from: null),
  (n: 4, item: _mugs, stored: '12', enteredUnit: 'piece', entered: '12', reason: 'transfer', daysAgo: 8, to: _shelf, from: _main),
  (n: 3, item: _mugs, stored: '54', enteredUnit: 'piece', entered: '54', reason: 'receipt', daysAgo: 12, to: _main, from: null),
  (n: 2, item: _milk, stored: '24', enteredUnit: 'l', entered: '24', reason: 'receipt', daysAgo: 16, to: _main, from: null),
  (n: 1, item: _beans, stored: '12.5', enteredUnit: 'kg', entered: '12.5', reason: 'receipt', daysAgo: 20, to: _main, from: null),
];

/// The Demo's "today": the story's own fixed day, so the figures never depend
/// on the machine's calendar.
final _anchor = DateTime.utc(2026, 11);

/// One movement to book on the ledger: [quantity] (inventory unit) of [item]
/// from [from] to [to], with what the person entered beside it.
class DemoStockPost {
  const DemoStockPost({
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

/// The in-memory goods ledger of the reference business.
class DemoStockLedger implements DemoInvoiceGoods {
  DemoStockLedger(this.workspaceId, this._config, [DateTime Function()? now, this.candidates]) : _now = now ?? (() => _anchor) {
    for (final s in _stories.reversed) {
      _book(
        DemoStockPost(
          id: 'demo-stock-movement-${s.n}',
          item: s.item,
          quantity: ExactQuantity.parse(s.stored),
          entered: ExactQuantity.parse(s.entered),
          enteredUnit: s.enteredUnit,
          from: s.from ?? _supplier,
          to: s.to,
          reason: s.reason,
          at: _anchor.subtract(Duration(days: s.daysAgo)),
        ),
      );
    }
    _transfers.add(
      StockTransfer(
        id: 'demo-transfer-1',
        fromLocationId: _main,
        fromCode: 'MAIN',
        toLocationId: _branch,
        toCode: 'BRANCH',
        status: 'loaded',
        loadedAt: _anchor,
        revision: 1,
        lines: [
          StockTransferLine(
            id: 'demo-transfer-line-1',
            itemId: _mugs.id,
            itemName: _mugs.name,
            unit: _mugs.unit,
            loaded: ExactQuantity.parse('6'),
            received: ExactQuantity.zero,
          ),
        ],
      ),
    );
  }

  /// The business that keeps the shop stock.
  final String workspaceId;
  final DemoStockConfigCommands _config;
  final DateTime Function() _now;

  /// What a retried request id answered.
  final Map<String, StockCommandResult> answers = {};

  static const items = [_beans, _milk, _mugs, _syrup, _shirt, _basket, _apples];

  /// #4350 -- the services turned into items in this session.
  final DemoStockCandidates? candidates;

  /// The shop's items and the ones its owner has started keeping since.
  List<StockItem> get itemList => [...items, ...?candidates?.added];

  final Map<String, ExactQuantity> _balances = {};
  final Map<String, ({StockItem item, String place, String? lotId, String? lotCode})> _keys = {};
  final List<StockMovementRow> _movements = [];
  final List<StockTransfer> _transfers = [];
  int _next = 100;

  bool mine(String id) => id == workspaceId;

  /// The Demo's day (its own clock, read once per use).
  DateTime get today => _now();

  /// A fresh movement number; the first ones belong to the story.
  int nextNumber() => _next++;

  /// The movements, newest first.
  List<StockMovementRow> get movements => List.unmodifiable(_movements);

  StockItem? itemOf(String id) => itemList.where((i) => i.id == id).firstOrNull;

  /// What an item holds at one place (and lot), exactly.
  ExactQuantity balance(String itemId, String place, {String? lotId}) =>
      _balances[_key(itemId, place, lotId)] ?? ExactQuantity.zero;

  String _key(String itemId, String place, String? lotId) => '$itemId|$place|${lotId ?? ''}';

  /// The places with their kind and whether they are virtual, by id.
  Future<Map<String, StockPlaceConfig>> placeConfigs() => _places();

  Future<Map<String, StockPlaceConfig>> _places() async =>
      {for (final p in await _config.places(workspaceId)) p.id: p};

  /// The rows the Stock screen reads: what is on hand where, items in the
  /// order of the catalogue, places in the order they were first used.
  Future<List<StockOnHandRow>> onHand({String? itemId, String? locationId}) async {
    final places = await _places();
    final rows = <StockOnHandRow>[];
    for (final e in _keys.entries) {
      final quantity = _balances[e.key] ?? ExactQuantity.zero;
      final k = e.value;
      if (quantity == ExactQuantity.zero) continue;
      if (itemId != null && k.item.id != itemId) continue;
      if (locationId != null && k.place != locationId) continue;
      final place = places[k.place];
      rows.add(
        StockOnHandRow(
          workspaceId: workspaceId,
          itemId: k.item.id,
          itemName: k.item.name,
          lotId: k.lotId,
          lotCode: k.lotCode,
          locationId: k.place,
          locationCode: place?.code ?? '',
          locationName: place?.name ?? '',
          quantity: quantity,
          unit: k.item.unit,
        ),
      );
    }
    final order = {for (var i = 0; i < items.length; i++) items[i].id: i};
    return [
      for (final (_, r) in ([for (var i = 0; i < rows.length; i++) (i, rows[i])]..sort((a, b) {
            final c = (order[a.$2.itemId] ?? 99).compareTo(order[b.$2.itemId] ?? 99);
            return c != 0 ? c : a.$1.compareTo(b.$1);
          })))
        r,
    ];
  }

  /// The places a filter can name: every active place, the road included.
  Future<List<StockPlace>> filterPlaces() async => [
    for (final p in (await _places()).values)
      if (p.active) StockPlace(id: p.id, code: p.code, name: p.name),
  ];

  /// Books [p] on the ledger. A real place or the road that holds less than
  /// asked refuses it, whole; a supplier or an opening place is the server's
  /// and holds whatever.
  Future<StockMovementRow> post(DemoStockPost p) async {
    final places = await _places();
    final source = places[p.from];
    if ((source != null && !source.virtual) || p.from == _transit) {
      final held = balance(p.item.id, p.from, lotId: p.lotId);
      if (held < p.quantity) {
        throw StockNotEnough('${held.text} of ${p.quantity.text} are there');
      }
    }
    return _book(p);
  }

  StockMovementRow _book(DemoStockPost p) {
    _add(p.item, p.from, p.lotId, p.lotCode, -p.quantity);
    _add(p.item, p.to, p.lotId, p.lotCode, p.quantity);
    final row = StockMovementRow(
      workspaceId: workspaceId,
      id: p.id ?? 'demo-stock-movement-${nextNumber()}',
      itemId: p.item.id,
      itemName: p.item.name,
      lotId: p.lotId,
      lotCode: p.lotCode,
      fromLocationId: p.from,
      fromLocationCode: _codeOf(p.from),
      toLocationId: p.to,
      toLocationCode: _codeOf(p.to),
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

  @override
  bool sells(String itemId) => itemOf(itemId) != null;

  /// #4433 -- the goods an issued invoice sells leave the main store for the customer, one sale per line, linked to the
  /// invoice. A line the main store cannot serve refuses them all and moves nothing, as the server does.
  @override
  Future<void> sellOnInvoice(String invoiceId, List<({String itemId, ExactQuantity quantity})> lines) async {
    final short = shortLine(lines);
    if (short != null) throw StockNotEnough('line ${short + 1}');
    for (final l in lines) {
      _book(DemoStockPost(item: itemOf(l.itemId)!, quantity: l.quantity, from: _main, to: _customer, reason: 'sale', causes: {'invoice': invoiceId}));
    }
  }

  /// The index of the first of [lines] the main store does not hold (an unknown item included), or null.
  @override
  int? shortLine(List<({String itemId, ExactQuantity quantity})> lines) {
    final wanted = <String, ExactQuantity>{};
    for (final (i, l) in lines.indexed) {
      final total = (wanted[l.itemId] ?? ExactQuantity.zero) + l.quantity;
      wanted[l.itemId] = total;
      if (itemOf(l.itemId) == null || balance(l.itemId, _main) < total) return i;
    }
    return null;
  }

  void _add(StockItem item, String place, String? lotId, String? lotCode, ExactQuantity delta) {
    final k = _key(item.id, place, lotId);
    if (_untracked.contains(place)) return;
    _keys.putIfAbsent(k, () => (item: item, place: place, lotId: lotId, lotCode: lotCode));
    _balances[k] = (_balances[k] ?? ExactQuantity.zero) + delta;
  }

  /// The code a place is read by; the seeded places are known by id.
  String _codeOf(String id) => switch (id) {
    _main => 'MAIN',
    _shelf => 'SHELF-A',
    _branch => 'BRANCH',
    _transit => 'TRANSIT',
    _supplier => 'SUPPLIER',
    _loss => 'LOSS',
    _customer => 'CUSTOMER',
    _ => _extra[id] ?? id,
  };

  final Map<String, String> _extra = {};

  /// Tells the ledger the code of a place the owner created.
  void learnPlace(String id, String code) => _extra[id] = code;

  /// The transfers not fully received, oldest first.
  List<StockTransfer> get openTransfers => [for (final t in _transfers) if (t.open) t];

  StockTransfer? transfer(String id) => _transfers.where((t) => t.id == id).firstOrNull;

  void addTransfer(StockTransfer t) => _transfers.add(t);

  void replaceTransfer(StockTransfer t) {
    final i = _transfers.indexWhere((x) => x.id == t.id);
    if (i >= 0) _transfers[i] = t;
  }

  String nextTransferId() => 'demo-transfer-${_next++}';
  String nextLineId() => 'demo-transfer-line-${_next++}';
}
