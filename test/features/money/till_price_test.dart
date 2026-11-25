// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4476 -- a till line's price at the till: the line sends its changed price, its reason and its discount, and keeps
// them through a new quantity; on the Demo till (the server's rules) a discount within the business's limit is taken off
// the item's price and one beyond it is refused in words naming the limit, a changed price without its reason or
// without the right is refused in words, and the line comes back to the item's price. A sale's receipt is printed again
// as copy 1, then 2, never numbered again; the same request answers the same copy; a receipt not finalized has none.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_parts.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/presentation/till_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Future<TillSession> _basket({bool mayChangePrice = true}) async {
  var n = 0;
  final s = TillSession(
    port: DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20, pricing: DemoTillPricing(mayChangePrice: mayChangePrice)),
    workspaceId: 'ws',
    requestIds: () => 'req-${++n}',
  );
  await s.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l');
  return s;
}

int _total(TillSession s) => s.state.value.draft!.totals.grossMinor;
String _said(TillSession s) => tillProblemText(_en, s.state.value.problem!);

void main() {
  test('the line sends its price, reason and discount, and keeps them through a new quantity', () {
    const line = TillLine(itemId: 'i', name: 'Oat milk', quantity: '1', unit: 'l');
    final priced = line.withPricing(price: '1.8', reason: 'dented');
    expect(priced.toJson(), {'item_id': 'i', 'quantity': '1', 'unit_price': '1.8', 'price_reason': 'dented'});
    expect(priced.withQuantity('2').toJson()['unit_price'], '1.8');
    expect(line.withPricing(discount: '10').toJson(), {'item_id': 'i', 'quantity': '1', 'discount_percent': '10'});
    expect(priced.withPricing().toJson(), {'item_id': 'i', 'quantity': '1'}, reason: 'back to the item\'s price');
  });

  test('a discount within the limit is taken off the item\'s price; beyond it, refused naming the limit', () async {
    final s = await _basket();
    expect(_total(s), 210);
    expect(await s.setPricing(0, discount: '10'), isTrue);
    expect(_total(s), 189);
    await s.setPricing(0, discount: '15');
    expect(_said(s), _en.tillDiscountBeyond(DemoTillPricing.demoMaxDiscountPercent));
  });

  test('a changed price needs its reason, and the right', () async {
    final s = await _basket();
    await s.setPricing(0, price: '1.5', reason: ' ');
    expect(_said(s), _en.tillPriceReasonMissing);
    await s.setPricing(0, price: '1.5', reason: 'end of day');
    expect(_total(s), 150);
    expect(s.state.value.lines.single.priceReason, 'end of day');
    await s.setPricing(0);
    expect(_total(s), 210, reason: 'back to the item\'s price');

    final cashier = await _basket(mayChangePrice: false);
    await cashier.setPricing(0, price: '1.5', reason: 'friend');
    expect(_said(cashier), _en.tillPriceNotAllowed);
    await cashier.setPricing(0, price: '2.1', reason: '');
    expect(_total(cashier), 210, reason: 'the item\'s own price needs no right');
  });

  test('a value that is not an exact decimal changes nothing', () async {
    final s = await _basket();
    expect(await s.setPricing(0, price: 'abc', reason: 'x'), isFalse);
    expect(await s.setPricing(0, discount: '0'), isFalse);
    expect(await s.setPricing(3, discount: '5'), isFalse);
    expect(_total(s), 210);
  });

  test('the last sale is printed again as copy 1, then 2; the same request answers the same copy', () async {
    final s = await _basket();
    await s.payCash(10000);
    final receipt = s.lastSold!;
    s.next();
    expect(s.lastSold, receipt, reason: 'kept past the next customer');
    final till = s.port as TillCopyPort;
    expect(await till.copy('ws', requestId: 'c1', receiptId: receipt), 1);
    expect(await till.copy('ws', requestId: 'c2', receiptId: receipt), 2);
    expect(await till.copy('ws', requestId: 'c1', receiptId: receipt), 1);
    await expectLater(till.copy('ws', requestId: 'c3', receiptId: 'no-such-receipt'), throwsA(isA<Object>()));
  });
}
