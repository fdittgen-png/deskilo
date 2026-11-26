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
import 'package:deskilo/features/stock/domain/stock_ledger.dart';
import 'package:deskilo/features/stock/domain/stock_operations.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/unit_conversions.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart' show LineTrack, LineTrackKind;
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'demo_stock_candidates.dart';
import 'demo_stock_config_commands.dart';
import 'demo_unit_conversions.dart';
import 'money/demo_standalone_invoice_commands.dart' show DemoInvoiceGoods;

// #4366 -- the beans are weighed at the counter and sit under their own key colour; the till categories are the shop's shelves.
const _beans = StockItem(id: 'demo-item-beans', name: 'Coffee beans', unit: 'kg', tillCategory: 'Coffee', quickKeyColour: '#6d4c41', soldByWeight: true);
const _milk = StockItem(id: 'demo-item-milk', name: 'Oat milk', unit: 'l', tillCategory: 'Fresh');
const _mugs = StockItem(id: 'demo-item-mugs', name: 'Mugs', unit: 'piece', tillCategory: 'Gifts');
// #4487 -- the syrup comes in a glass bottle: its deposit goes with it at the till, and is taken back there (#4478).
const _syrup = StockItem(id: 'demo-item-syrup', name: 'Syrup', unit: 'l', tillCategory: 'Coffee', depositItemId: demoBottleDeposit);
const _bottle = StockItem(id: demoBottleDeposit, name: 'Bottle deposit', unit: 'piece', tillCategory: 'Coffee');
// A T-shirt with no stock yet: the item the Demo's variants are edited on.
const _shirt = StockItem(id: 'demo-item-shirt', name: 'T-shirt', unit: 'piece');
// #4362 -- a gift basket, each piece tagged one by one, and a crate of apples, one tag per crate.
const _basket = StockItem(id: 'demo-item-basket', name: 'Gift basket', unit: 'piece');
const _apples = StockItem(id: 'demo-item-apples', name: 'Apples, crate', unit: 'piece');

/// #4487 -- the Demo's one deposit item: the glass bottle of its syrup.
const demoBottleDeposit = 'demo-item-bottle';

const _main = 'demo-place-main';
const _shelf = 'demo-place-shelf';
const _branch = 'demo-place-branch';
const _transit = 'demo-place-transit';
const _supplier = 'demo-place-supplier';
// #4433 -- the customer: goods sold on an invoice go there.
const _customer = 'demo-place-customer';

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

/// #4403 -- one movement to book on the ledger: the domain's own.
typedef DemoStockPost = StockPost;

/// The in-memory goods ledger of the reference business: the domain's [StockLedger], seeded with the story and
/// reading the places and units of the Demo's configuration.
class DemoStockLedger implements DemoInvoiceGoods {
  DemoStockLedger(this.workspaceId, this._config, [DateTime Function()? now, this.candidates, UnitConversions? conversions]) {
    core = StockLedger(
      workspaceId,
      items: () => itemList,
      places: () => _config.placeMap,
      units: _config.unitsOf,
      conversions: conversions is DemoUnitConversions ? () => conversions.rows(workspaceId) : null,
      clock: now ?? (() => _anchor),
      prefix: 'demo',
    );
    for (final s in _stories.reversed) {
      core.book(
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
    core.addTransfer(
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

  /// The ledger every Demo stock fake reads and writes.
  late final StockLedger core;

  static const items = [_beans, _milk, _mugs, _syrup, _shirt, _basket, _apples, _bottle];

  /// #4350 -- the services turned into items in this session.
  final DemoStockCandidates? candidates;

  /// The shop's items and the ones its owner has started keeping since.
  List<StockItem> get itemList => [...items, ...?candidates?.added];

  bool mine(String id) => id == workspaceId;
  DateTime get today => core.today;
  List<StockMovementRow> get movements => core.movements;
  List<StockTransfer> get openTransfers => core.openTransfers;
  StockItem? itemOf(String id) => core.itemOf(id);
  ExactQuantity balance(String itemId, String place, {String? lotId}) => core.balance(itemId, place, lotId: lotId);

  /// The places with their kind and whether they are virtual, by id.
  Future<Map<String, StockPlaceConfig>> placeConfigs() async => {for (final p in await _config.places(workspaceId)) p.id: p};

  /// The rows the Stock screen reads: what is on hand where, items in the
  /// order of the catalogue, places in the order they were first used.
  Future<List<StockOnHandRow>> onHand({String? itemId, String? locationId}) async =>
      core.onHand(itemId: itemId, locationId: locationId, order: [for (final i in items) i.id]);

  /// The places a filter can name: every active place, the road included.
  Future<List<StockPlace>> filterPlaces() async => [
    for (final p in (await placeConfigs()).values)
      if (p.active) StockPlace(id: p.id, code: p.code, name: p.name),
  ];

  /// Books [p] on the ledger. A real place or the road that holds less than
  /// asked refuses it, whole; a supplier or an opening place is the server's
  /// and holds whatever.
  Future<StockMovementRow> post(DemoStockPost p) async => core.post(p);

  @override
  bool sells(String itemId) => itemOf(itemId) != null;

  /// #4433 -- the goods an issued invoice sells leave the main store for the customer, one sale per line, linked to the
  /// invoice. A line the main store cannot serve refuses them all and moves nothing, as the server does.
  @override
  Future<Map<int, List<LineTrack>>> sellOnInvoice(String invoiceId, List<({int n, String itemId, ExactQuantity quantity})> lines) async {
    final short = shortLine([for (final l in lines) (itemId: l.itemId, quantity: l.quantity)]);
    if (short != null) throw StockNotEnough('line ${short + 1}');
    final took = <int, List<LineTrack>>{};
    for (final l in lines) {
      final item = itemOf(l.itemId)!;
      var left = l.quantity;
      // the lots the main store holds, in the order they were received; what they do not hold leaves the loose stock
      for (final lot in core.lotsAt(item.id, _main)) {
        if (!(ExactQuantity.zero < left)) break;
        final part = lot.quantity < left ? lot.quantity : left;
        core.book(DemoStockPost(item: item, quantity: part, from: _main, to: _customer, reason: 'sale', lotId: lot.id, lotCode: lot.code, causes: {'invoice': invoiceId}));
        (took[l.n] ??= []).add(LineTrack(kind: LineTrackKind.lot, code: lot.code, quantity: part.text));
        left = left - part;
      }
      if (ExactQuantity.zero < left) {
        core.book(DemoStockPost(item: item, quantity: left, from: _main, to: _customer, reason: 'sale', causes: {'invoice': invoiceId}));
      }
    }
    return took;
  }

  /// The index of the first of [lines] the main store does not hold (an unknown item included), or null.
  @override
  int? shortLine(List<({String itemId, ExactQuantity quantity})> lines) {
    final wanted = <String, ExactQuantity>{};
    for (final (i, l) in lines.indexed) {
      final total = (wanted[l.itemId] ?? ExactQuantity.zero) + l.quantity;
      wanted[l.itemId] = total;
      if (itemOf(l.itemId) == null || core.held(l.itemId, _main) < total) return i;
    }
    return null;
  }
}
