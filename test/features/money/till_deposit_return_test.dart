// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4478 -- a deposit brought back at the till: the line says it is returned and keeps it through a new quantity; on the
// Demo till (the server's rules) it is taken off the sale, kept apart from a sale of the same item, refused in words when
// it is no deposit, when it carries a price or when the cashier may not change a price; the book offers no returned
// deposit for a goods return; a day report reads its returned deposits, and none when it was frozen before them.
import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_parts.dart';
import 'package:deskilo/features/money/domain/counter_book.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/features/money/presentation/till_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _en = AppLocalizationsEn();

Future<TillSession> _basket({bool mayChangePrice = true}) async {
  var n = 0;
  final s = TillSession(
    port: DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20, pricing: DemoTillPricing(mayChangePrice: mayChangePrice, deposits: const {'demo-item-milk'})),
    workspaceId: 'ws',
    requestIds: () => 'req-${++n}',
  );
  await s.add(itemId: 'demo-item-beans', name: 'Coffee beans', unit: 'kg');
  return s;
}

int _total(TillSession s) => s.state.value.draft!.totals.grossMinor;
String _said(TillSession s) => tillProblemText(_en, s.state.value.problem!);

void main() {
  test('a returned line says so and keeps it through a new quantity', () {
    const line = TillLine(itemId: 'd', name: 'Bottle', quantity: '2', unit: 'piece', returned: true);
    expect(line.toJson(), {'item_id': 'd', 'quantity': '2', 'returned': true});
    expect(line.withQuantity('3').toJson()['returned'], isTrue);
    expect(const TillLine(itemId: 'd', name: 'Bottle', quantity: '1', unit: 'piece').toJson().containsKey('returned'), isFalse);
  });

  test('a deposit brought back is taken off the sale, apart from a sale of the same item', () async {
    final s = await _basket();
    expect(_total(s), 2400);
    await s.addReturn(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l', quantity: '2');
    expect(_total(s), 2400 - 420);
    await s.add(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l');
    expect(s.state.value.lines.where((l) => l.itemId == 'demo-item-milk'), hasLength(2), reason: 'a sale and a return stay two lines');
    expect(_total(s), 2400 - 420 + 210);
  });

  test('a return is refused in words: no deposit, or no right', () async {
    final s = await _basket();
    await s.addReturn(itemId: 'demo-item-beans', name: 'Coffee beans', unit: 'kg');
    expect(_said(s), _en.tillReturnNotDeposit, reason: 'coffee beans are no deposit');
    final cashier = await _basket(mayChangePrice: false);
    await cashier.addReturn(itemId: 'demo-item-milk', name: 'Oat milk', unit: 'l');
    expect(_said(cashier), _en.tillReturnNotAllowed);
  });

  test('the book offers no returned deposit for a goods return', () {
    CounterBookLine line({required bool returned}) => CounterBookLine.fromJson({
      'id': 'l1',
      'line_no': 1,
      'gross_minor': returned ? -50 : 50,
      'frozen': {'label': 'Bottle', 'supply': 'goods', if (returned) 'returned': true, 'commercial': {'quantity': '2', 'unit': {'code': 'piece'}}},
    });
    expect(line(returned: false).goods, isTrue);
    expect(line(returned: true).goods, isFalse);
  });

  test('a day report reads its returned deposits, and none when it was frozen before them', () {
    Map<String, Object?> report([Object? deposits]) => {
      'day_close_id': 'd1',
      'number': 'Z-1',
      'report': {
        'business_date': '2026-11-25',
        'sessions': <Object?>[],
        'differences_minor': '0',
        'sales_by_rate': <Object?>[],
        'sales_by_tender': <String, Object?>{},
        'sales_total_minor': '0',
        'receipts': {'count': 0},
        'corrections': {'count': 0, 'total_minor': '0'},
        'refunds': <String, Object?>{},
        'paid_in_minor': '0',
        'paid_out_minor': '0',
        'deposits_returned_minor': ?deposits,
      },
    };
    expect(DayReport.fromJson(report('75')).depositsReturnedMinor, 75);
    expect(DayReport.fromJson(report()).depositsReturnedMinor, 0);
  });
}
