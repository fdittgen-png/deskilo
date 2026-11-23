// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4360 (G11) -- what a scanned GS1 label sets on a put-away line follows what the item tracks: an item that is not
// tracked takes no lot, a lot-tracked item takes the lot and no expiry, an expiry-tracked item takes both.
import 'package:deskilo/features/money/domain/purchase_order.dart';
import 'package:deskilo/features/stock/domain/put_away_progress.dart';
import 'package:deskilo/features/stock/domain/stock_config.dart';
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_receiving.dart';
import 'package:deskilo/features/stock/domain/stock_scan_session.dart';
import 'package:deskilo/features/stock/presentation/purchase_order_putaway.dart';
import 'package:flutter_test/flutter_test.dart';

PutAwayDraft _draft(String tracking) => PutAwayDraft(
  PutAwayContext(
    places: const [StockPlace(id: 'place-main', code: 'MAIN', name: 'Main store')],
    items: {
      1: StockItemConfig(
        itemId: 'item-milk',
        revision: 1,
        stockable: true,
        purchasable: true,
        sellable: true,
        inventoryUnit: 'l',
        tracking: tracking,
        shelfLifeDays: null,
        units: const [],
        codes: const [],
      ),
    },
    variants: const {},
    currency: 'EUR',
  ),
  const PurchaseOrder(
    id: 'po-1',
    reference: 'PO-1',
    supplierId: 'sup-1',
    supplierName: 'Dairy',
    state: PurchaseOrderState.sent,
    currency: 'EUR',
    revision: 1,
    lines: [],
  ),
  const [DeliveredLineProgress(lineNo: 1, description: 'Oat milk', unit: 'l', serviceId: null, received: 6, putAway: 0)],
);

PutAwayAllocation _scanned(String tracking) {
  final draft = _draft(tracking);
  final line = ScanLine(itemId: 'item-milk', itemName: 'Oat milk', unit: 'l', lotCode: 'L-42', expiresOn: '2026-11-30')..add(1, 1);
  draft.scanned(ScanResult(ScanOutcome.line, line: line));
  return draft.toAllocations().single;
}

void main() {
  test('an item that is not tracked takes neither the lot nor the expiry of a label', () {
    final a = _scanned('none');
    expect(a.lotCode, isNull);
    expect(a.expiresOn, isNull);
  });

  test('a lot-tracked item takes the lot and no expiry', () {
    final a = _scanned('lot');
    expect(a.lotCode, 'L-42');
    expect(a.expiresOn, isNull);
  });

  test('an expiry-tracked item takes the lot and the expiry', () {
    final a = _scanned('expiry');
    expect(a.lotCode, 'L-42');
    expect(a.expiresOn, '2026-11-30');
  });
}
