// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4433 -- the items a Demo invoice line may sell: the business's own goods ledger. The Demo's ledger counts goods by
// quantity only, so no item asks for its pieces here.
import 'package:deskilo/features/money/domain/invoice_goods.dart';

import '../demo_stock_ledger.dart';

class DemoInvoiceGoodsCatalogue implements InvoiceGoodsCatalogue {
  DemoInvoiceGoodsCatalogue(this._ledger);

  final DemoStockLedger _ledger;

  @override
  Future<List<InvoiceGoodsItem>> items(String workspaceId) async => [
    if (_ledger.mine(workspaceId))
      for (final i in _ledger.itemList)
        if (i.active) InvoiceGoodsItem(id: i.id, name: i.name, unit: i.unit),
  ];
}
