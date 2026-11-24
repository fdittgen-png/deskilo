// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4435 (G20) -- the Demo's handling units, answering as the server does from the goods ledger the Demo keeps: a pallet of 30 mugs
// and a carton of 10 kg of coffee beans stand at the main store. A unit claims only what is loose there (the balance minus what
// open units hold), a move goes through the ledger and moves the whole content, a second move with the revision someone else
// already moved is refused with the unit's new place, an unpack leaves the content loose, a repack makes the store's own units
// of what it took (the totals never change, and it happens at one place).
import '../../../features/stock/domain/handling_unit_book.dart';
import '../../../features/stock/domain/handling_units.dart';
import 'demo_stock_ledger.dart';

/// The Demo's handling units: the rules are the domain's book (#4403), on the Demo's ledger.
class DemoStockHandlingUnits implements StockHandlingUnits {
  DemoStockHandlingUnits(DemoStockLedger ledger) : _book = HandlingUnitBook(ledger.core, prefix: 'demo') {
    _book
      ..seed('demo-unit-1', 'PAL-001', HandlingUnitKind.pallet, _main, {'demo-item-mugs': '30'}, labelCode: '003760001234567895')
      ..seed('demo-unit-2', 'CT-001', HandlingUnitKind.carton, _main, {'demo-item-beans': '10'});
  }

  static const _main = 'demo-place-main';

  final HandlingUnitBook _book;
  final Map<String, Object> _answers = {};

  /// A request made twice answers what it answered the first time.
  T _once<T extends Object>(String requestId, T Function() run) => (_answers[requestId] ??= run()) as T;

  @override
  Future<HandlingUnitPage> page(String workspaceId, {String? locationId, HandlingUnitState state = HandlingUnitState.open, Map<String, Object?>? after}) async =>
      HandlingUnitPage(rows: _book.page(locationId: locationId, state: state));

  @override
  Future<HandlingUnitDetail?> unit(String workspaceId, String unitId) async => _book.unit(unitId);

  @override
  Future<HandlingUnit> make(String workspaceId, String requestId, UnitDraft draft) async => _once(requestId, () => _book.make(draft));

  @override
  Future<HandlingUnit> move(String workspaceId, String requestId, {required String unitId, required String toLocationId, required int revision}) async =>
      _once(requestId, () => _book.move(unitId: unitId, toLocationId: toLocationId, revision: revision));

  @override
  Future<HandlingUnit> unpack(String workspaceId, String requestId, {required String unitId, required int revision}) async =>
      _once(requestId, () => _book.unpack(unitId: unitId, revision: revision));

  @override
  Future<List<HandlingUnit>> repack(String workspaceId, String requestId, {required List<RepackSource> sources, required List<UnitDraft> targets}) async =>
      _once(requestId, () => _book.repack(sources: sources, targets: targets));

  @override
  Future<LotUnitTrace> lotTrace(String workspaceId, {required String itemId, required String lotId}) async =>
      const LotUnitTrace(held: [], repacks: []);
}
