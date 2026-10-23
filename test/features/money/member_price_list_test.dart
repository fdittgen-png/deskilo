// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — what a member pays per offered level. Bands are inclusive-upper,
// so a level on a boundary takes the lower band; a level no band covers
// has no price instead of a wrong one; an extra day is two extra
// half-days; levels come out once each, in ascending order.
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/member_price_list.dart';
import 'package:flutter_test/flutter_test.dart';

FeeBand _band(int from, int to, int fee, int overage) => FeeBand(
  id: 'b$to',
  workspaceId: 'ws-1',
  fromPct: from,
  toPct: to,
  feeCents: fee,
  overageFeeCents: overage,
);

void main() {
  final bands = [_band(0, 50, 9000, 1200), _band(50, 100, 16000, 700)];

  test('a level on a boundary takes the band below it', () {
    expect(feeBandFor(bands, 50)?.toPct, 50);
    expect(feeBandFor(bands, 51)?.toPct, 100);
    expect(feeBandFor(bands, 1)?.toPct, 50);
    expect(feeBandFor(bands, 0), isNull, reason: '(0, 50] excludes 0');
  });

  test('each offered level once, ascending, with its monthly fee and its '
      'extra half-day and day', () {
    final list = memberPriceList(bands, [100, 25, 100, 50]);
    expect([for (final p in list) p.pct], [25, 50, 100]);
    final full = list.last;
    expect(full.monthlyCents, 16000);
    expect(full.extraHalfDayCents, 700);
    expect(full.extraDayCents, 1400, reason: 'a day is two half-days');
    expect(list.first.monthlyCents, 9000);
  });

  test('a level no band covers has no price', () {
    final list = memberPriceList([_band(0, 50, 9000, 1200)], [75]);
    expect(list.single.band, isNull);
    expect(list.single.monthlyCents, isNull);
    expect(list.single.extraDayCents, isNull);
  });
}
