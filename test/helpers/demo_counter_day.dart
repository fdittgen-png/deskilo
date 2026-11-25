// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4185 -- a day at the Demo's counter, through the Demo's own till: a service sold for cash, goods whose card was declined
// and that were paid in cash instead, the seeded sale whose card answer was lost recovered from the terminal and
// completed once, and a correction of the morning's cash sale with its money given back and its goods taken back.
// Receipts, money and stock are then each added up on their own and must agree. Shared by the scenario checklist and the
// receipts screen's phone, tablet and desk tests.
import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/demo/data/demo_stock_registry.dart';
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/features/money/domain/counter_book.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const _ws = 'ws-demo-day';

/// What the day left: the book, the receipts of each step, the declined card's refusal, and the three sums.
typedef CounterDay = ({
  CounterBook book,
  String serviceSale,
  String declinedSale,
  String recoveredSale,
  String correction,
  String? declinedRefusal,
  int receiptsMinor,
  int moneyMinor,
  Map<String, int> stockOut,
});

Future<CounterDay> runCounterDay(DemoTill till) async {
  till.seed();
  // a service: a day desk, paid in cash
  final desk = await till.draft(_ws, requestId: 'day-1', lines: const [TillLine(itemId: demoDayDeskItem, name: 'Day desk', quantity: '1', unit: 'day')]);
  await till.finalize(_ws, requestId: 'day-2', receiptId: desk.receiptId, expectedRevision: desk.revision,
      tenders: [TillTender(kind: 'cash', amountMinor: desk.totals.grossMinor)]);

  // goods: the card is declined, the sale is not taken by it, the customer pays in cash
  final goods = await till.draft(_ws, requestId: 'day-3', lines: const [
    TillLine(itemId: 'demo-item-milk', name: 'Oat milk', quantity: '1', unit: 'l'),
    TillLine(itemId: 'demo-item-beans', name: 'Coffee beans', quantity: '1', unit: 'kg'),
  ]);
  final asked = await till.requestCard(_ws, requestId: 'day-4', receiptId: goods.receiptId, amountMinor: goods.totals.grossMinor);
  await till.resolveCard(_ws, requestId: 'day-5', tenderId: asked.tenderId, outcome: 'refused');
  String? declined;
  try {
    await till.finalize(_ws, requestId: 'day-6', receiptId: goods.receiptId, expectedRevision: goods.revision,
        tenders: [TillTender(kind: 'card', amountMinor: 0, tenderId: asked.tenderId)]);
  } on PostgrestException catch (e) {
    declined = e.code;
  }
  await till.finalize(_ws, requestId: 'day-7', receiptId: goods.receiptId, expectedRevision: goods.revision,
      tenders: [TillTender(kind: 'cash', amountMinor: goods.totals.grossMinor)]);

  // the seeded sale whose card answer was lost: the terminal's journal says accepted, the sale is completed once
  var book = await till.book(_ws);
  final waiting = book.waiting.single;
  await till.resolveTender(_ws, requestId: 'day-8', tenderId: waiting.openAuthorizations.single.id, outcome: 'accepted', providerRef: 'T-881');
  book = await till.book(_ws);
  await till.complete(_ws, requestId: 'day-9', receiptId: waiting.id, expectedRevision: waiting.revision,
      tenderIds: book.byId(waiting.id)!.settlingCardTenders);

  // the morning's cash sale: one oat milk was spilt -- credited, its money given back, the carton taken back
  book = await till.book(_ws);
  final morning = book.issued.firstWhere((r) => r.number == 'R-00001');
  final milk = morning.lines.firstWhere((l) => l.label == 'Oat milk');
  final number = await till.correct(_ws, requestId: 'day-10', originalId: morning.id, lines: [CounterBookQuantity(lineId: milk.id, quantity: '1')], reason: 'spilt');
  book = await till.book(_ws);
  final credit = book.issued.firstWhere((r) => r.number == number);
  await till.refund(_ws, requestId: 'day-11', correctionId: credit.id, parts: [CounterRefundPart(kind: 'cash', amountMinor: credit.totalMinor)]);
  await till.returnGoods(_ws, requestId: 'day-12', correctionId: credit.id, lines: [CounterBookQuantity(lineId: credit.lines.single.id, quantity: '1')]);
  book = await till.book(_ws);

  // the three sums, each from its own facts
  final sales = [for (final r in book.issued) if (r.kind == 'sale') r];
  final credits = [for (final r in book.issued) if (r.kind != 'sale') r];
  final receipts = sales.fold<int>(0, (a, r) => a + r.totalMinor) - credits.fold<int>(0, (a, r) => a + r.totalMinor);
  final taken = [for (final r in sales) for (final t in r.tenders) if (t.state == 'accepted') t.amountMinor].fold<int>(0, (a, b) => a + b);
  final money = taken - credits.fold<int>(0, (a, r) => a + r.refundedMinor);
  final stock = <String, int>{};
  for (final r in sales) {
    for (final l in r.lines) {
      if (l.goods) stock[l.label] = (stock[l.label] ?? 0) + counterQuantityUnits(l.quantity);
    }
  }
  for (final r in credits) {
    for (final l in r.lines) {
      final back = r.returned[l.id];
      if (back != null) stock[l.label] = (stock[l.label] ?? 0) - counterQuantityUnits(back);
    }
  }
  return (
    book: book,
    serviceSale: desk.receiptId,
    declinedSale: goods.receiptId,
    recoveredSale: waiting.id,
    correction: credit.id,
    declinedRefusal: declined,
    receiptsMinor: receipts,
    moneyMinor: money,
    stockOut: stock,
  );
}

/// The units one quantity of the day stands for (`counterQuantityUnits` of one whole piece).
int counterDayUnits(int pieces) => pieces * counterQuantityUnits('1');

/// The day's prices, from the Demo's own catalogue.
int counterDayPrice(String itemId) => DemoStockRegistry.catalogue[itemId]!.$2;

/// The refusal a declined card's tender gets when it is named to settle the sale.
const counterDayDeclinedCode = DkCode.dkl06;
