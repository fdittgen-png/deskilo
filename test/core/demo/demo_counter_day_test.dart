// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 Demo day -- a day at the Demo's counter (test/helpers/demo_counter_day.dart): a service, goods whose card was
// declined and paid in cash, a lost card answer recovered, a corrected sale with its money and goods given back. The
// receipts, the money and the stock are each added up on their own, and they agree.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_counter_day.dart';

void main() {
  test('the service, the declined card, the recovered answer and the correction leave one consistent day', () async {
    final day = await runCounterDay(DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20));
    final book = day.book;

    // the service is sold, with no stock behind it
    final desk = book.byId(day.serviceSale)!;
    expect(desk.finalized, isTrue);
    expect(desk.lines.single.goods, isFalse);

    // the declined card took nothing: named to settle the sale it is refused, and the sale is paid in cash
    expect(day.declinedRefusal, counterDayDeclinedCode);
    final declined = book.byId(day.declinedSale)!;
    expect(declined.finalized, isTrue);
    expect([for (final t in declined.tenders) '${t.kind} ${t.state}'], ['card refused', 'cash accepted']);

    // the lost answer is recovered: nothing waits any more, the sale was completed once
    expect(book.waiting, isEmpty);
    expect(book.byId(day.recoveredSale)!.finalized, isTrue);

    // the correction is fully paid back and its carton is back
    final credit = book.byId(day.correction)!;
    expect(credit.refundLeftMinor, 0);
    expect(credit.returned.values.single, '1');

    // three sums from three sets of facts: the receipts, the money that moved, the stock that left
    expect(day.receiptsMinor, day.moneyMinor);
    final milk = counterDayPrice('demo-item-milk');
    final beans = counterDayPrice('demo-item-beans');
    // morning 2 milk + 1 beans, lost-answer 1 beans, afternoon 1 milk + 1 beans, day desk 25.00; one milk credited
    expect(day.receiptsMinor, (2 * milk + beans) + beans + (milk + beans) + 2500 - milk);
    expect(day.stockOut, {'Oat milk': counterDayUnits(2), 'Coffee beans': counterDayUnits(3)});
  });

  test('a sale sent again under its request id answers the same receipt, nothing is sold twice', () async {
    final till = DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20);
    final day = await runCounterDay(till);
    final sale = day.book.byId(day.declinedSale)!;
    final again = await till.finalize('ws-demo-day', requestId: 'day-7', receiptId: sale.id, expectedRevision: sale.revision,
        tenders: [TillTender(kind: 'cash', amountMinor: sale.totalMinor)]);
    expect(again.number, sale.number);
    final book = await till.book('ws-demo-day');
    expect(book.issued.length, day.book.issued.length);
    expect(book.issued.map((r) => r.number).toSet().length, book.issued.length);
  });
}
