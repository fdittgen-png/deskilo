// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- the services of the Demo's reference business that its owner may start keeping as stock
// items, and the ones kept so far in this session. An item IS a service whose stock setting is on: the
// Demo's shop keeps five from the start; turning the setting on for another one adds it to the one
// goods ledger, to the items page and to what the moves and the counts offer. Nothing leaves the
// process, and a reset of the Demo forgets them.
import 'package:deskilo/features/stock/domain/stock_page.dart';

/// The Demo's services that are not items yet, and the ones that became items.
class DemoStockCandidates {
  DemoStockCandidates(this._services);

  /// Every service of the business (id, name), as the Demo's catalogue holds them.
  final Future<List<({String id, String name})>> Function() _services;

  /// The ids of the five items the shop keeps from the start.
  static const _start = {'demo-item-beans', 'demo-item-milk', 'demo-item-mugs', 'demo-item-shirt', 'demo-item-syrup'};

  /// The services turned into items in this session, in the order they were.
  final List<StockItem> added = [];

  /// A service the owner may start keeping in stock, in the inventory unit a new item gets.
  Future<List<StockItem>> unstocked() async => [
    for (final s in await _services())
      if (!_start.contains(s.id) && !added.any((a) => a.id == s.id)) StockItem(id: s.id, name: s.name, unit: 'piece'),
  ];
}
