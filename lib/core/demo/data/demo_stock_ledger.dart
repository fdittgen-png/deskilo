// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 (B) -- the Demo's ONE goods ledger. The reference business keeps a
// small shop stock (beans by the kilogram, oat milk by the litre, mugs, a syrup
// received in thirds of a litre) at a main store with a shelf and at a branch
// shop, with the movements behind each figure and one transfer already on its
// way. The Stock screen's reads, a delivery put away from a purchase order and
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

import 'demo_stock_config_commands.dart';

const _beans = StockItem(id: 'demo-item-beans', name: 'Coffee beans', unit: 'kg');
const _milk = StockItem(id: 'demo-item-milk', name: 'Oat milk', unit: 'l');
const _mugs = StockItem(id: 'demo-item-mugs', name: 'Mugs', unit: 'piece');
const _syrup = StockItem(id: 'demo-item-syrup', name: 'Syrup', unit: 'l');
// A T-shirt with no stock yet: the item the Demo's variants are edited on.
const _shirt = StockItem(id: 'demo-item-shirt', name: 'T-shirt', unit: 'piece');

const _main = 'demo-place-main';
const _shelf = 'demo-place-shelf';
const _branch = 'demo-place-branch';
const _transit = 'demo-place-transit';
const _supplier = 'demo-place-supplier';
const _loss = 'demo-place-loss';

/// The server's own places that hold nothing: goods come from and go to them.
const _untracked = {_supplier, _loss};

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

/// The in-memory goods ledger of the reference business.
class DemoStockLedger {
  DemoStockLedger(this.workspaceId, this._config) {
    for (final s in _stories.reversed) {
      _book(
        id: 'demo-stock-movement-${s.n}',
        item: s.item,
        quantity: ExactQuantity.parse(s.stored),
        entered: ExactQuantity.parse(s.entered),
        enteredUnit: s.enteredUnit,
        from: s.from ?? _supplier,
        to: s.to,
        reason: s.reason,
        at: _anchor.subtract(Duration(days: s.daysAgo)),
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

  /// What a retried request id answered.
  final Map<String, StockCommandResult> answers = {};

  static const items = [_beans, _milk, _mugs, _syrup, _shirt];

  final Map<String, ExactQuantity> _balances = {};
  final Map<String, ({StockItem item, String place, String? lotId, String? lotCode})> _keys = {};
  final List<StockMovementRow> _movements = [];
  final List<StockTransfer> _transfers = [];
  int _next = 100;

  bool mine(String id) => id == workspaceId;

  /// A fresh movement number; the first ones belong to the story.
  int nextNumber() => _next++;

  /// The movements, newest first.
  List<StockMovementRow> get movements => List.unmodifiable(_movements);

  StockItem? itemOf(String id) => items.where((i) => i.id == id).firstOrNull;

  /// What an item holds at one place (and lot), exactly.
  ExactQuantity balance(String itemId, String place, {String? lotId}) =>
      _balances[_key(itemId, place, lotId)] ?? ExactQuantity.zero;

  String _key(String itemId, String place, String? lotId) => '$itemId|$place|${lotId ?? ''}';

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

  /// Books one movement of [quantity] (inventory unit) from [from] to [to].
  /// A real place or the road that holds less than asked refuses it, whole;
  /// a supplier or an opening place is the server's and holds whatever.
  Future<StockMovementRow> post({
    required StockItem item,
    required ExactQuantity quantity,
    required String from,
    required String to,
    required String reason,
    String? lotId,
    String? lotCode,
    String? variantId,
    ExactQuantity? entered,
    String? enteredUnit,
    DateTime? at,
    int? number,
  }) async {
    final places = await _places();
    final source = places[from];
    if ((source != null && !source.virtual) || from == _transit) {
      final held = balance(item.id, from, lotId: lotId);
      if (held < quantity) {
        throw StockNotEnough('${held.text} of ${quantity.text} are there');
      }
    }
    return _book(
      id: 'demo-stock-movement-${number ?? nextNumber()}',
      item: item,
      quantity: quantity,
      entered: entered ?? quantity,
      enteredUnit: enteredUnit ?? item.unit,
      from: from,
      to: to,
      reason: reason,
      at: at ?? _anchor,
      lotId: lotId,
      lotCode: lotCode,
      variantId: variantId,
    );
  }

  StockMovementRow _book({
    required String id,
    required StockItem item,
    required ExactQuantity quantity,
    required ExactQuantity entered,
    required String enteredUnit,
    required String from,
    required String to,
    required String reason,
    required DateTime at,
    String? lotId,
    String? lotCode,
    String? variantId,
  }) {
    _add(item, from, lotId, lotCode, -quantity);
    _add(item, to, lotId, lotCode, quantity);
    final row = StockMovementRow(
      workspaceId: workspaceId,
      id: id,
      itemId: item.id,
      itemName: item.name,
      lotId: lotId,
      lotCode: lotCode,
      fromLocationId: from,
      fromLocationCode: _codeOf(from),
      toLocationId: to,
      toLocationCode: _codeOf(to),
      quantity: quantity,
      unit: item.unit,
      enteredQuantity: entered,
      enteredUnit: enteredUnit,
      occurredAt: at,
      reason: reason,
      unitCost: null,
      causes: const {},
      variantId: variantId,
    );
    _movements.insert(0, row);
    return row;
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
