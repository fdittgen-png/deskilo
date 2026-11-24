// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- the services of the business behind the stock's `StockServiceCreator` port: a new item is
// made as a service by the money feature's own command, and the stock never imports it (this is the
// composition root, as for the purchase orders' stock actions).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/money/providers/money_providers.dart';
import '../features/stock/domain/stock_service_creator.dart';

/// Creates services through the business's money repository.
class MoneyStockServiceCreator implements StockServiceCreator {
  const MoneyStockServiceCreator(this._ref);

  final Ref _ref;

  @override
  Future<List<StockVatChoice>> vatChoices(String workspaceId) async {
    final rates = await _ref.read(vatRatesProvider.future);
    final active = [for (final r in rates) if (r.active && r.id.isNotEmpty) r]..sort((a, b) => a.isDefault == b.isDefault ? 0 : (a.isDefault ? -1 : 1));
    return [for (final r in active) (id: r.id, label: r.label)];
  }
}
