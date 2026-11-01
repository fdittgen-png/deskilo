// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the performance proof's invoice allocation, checked without a
// database. The declared profile is 400 members x 36 months, one `full`
// invoice per member-month; invoices_member_period_kind_uniq (0142:
// member_id, period, kind) refuses a second one. The first mapping,
// month = (n-1) mod 36, repeated (member, month) from n = 3601 on and the
// split run failed with 23505. This replays the allocation of the committed
// fixture for every invoice and pins the files to it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _dir = 'docs/testing/evidence/2578-perf';

int _knob(String sql, String name) => int.parse(
  RegExp("set_config\\('perf\\.$name', '(\\d+)'").firstMatch(sql)!.group(1)!,
);

void main() {
  final original = File('$_dir/2578-explain.sql').readAsStringSync();
  final members = _knob(original, 'members');
  final months = _knob(original, 'months');
  final invoices = _knob(original, 'invoices');

  test('the declared profile is one full invoice per member-month', () {
    expect((members, months, invoices), (400, 36, 14400));
    expect(invoices, members * months);
  });

  test('the allocation never gives two invoices one (member, month)', () {
    final seen = <int>{};
    final perMonth = List<int>.filled(months, 0);
    for (var n = 1; n <= invoices; n++) {
      final member = (n - 1) % members;
      final month = ((n - 1) ~/ members) % months;
      expect(seen.add(month * members + member), isTrue, reason: 'n=$n');
      perMonth[month]++;
    }
    expect(seen.length, members * months);
    expect(perMonth.toSet(), {members});
  });

  test('the old mapping is the red control: it collides at n = 3601', () {
    final seen = <int>{};
    int? first;
    for (var n = 1; n <= invoices; n++) {
      if (!seen.add(((n - 1) % months) * members + (n - 1) % members)) {
        first = n;
        break;
      }
    }
    expect(first, 3601);
  });

  test('the one-transaction file uses that allocation', () {
    expect(
      original,
      contains('(n - 1) % current_setting(\'perf.members\')::int'),
    );
    expect(
      original,
      contains(
        "((n - 1) / current_setting('perf.members')::int) % "
        "current_setting('perf.months')::int",
      ),
    );
  });

  test('the split money seeds cover 1..14400 once, with that allocation', () {
    var next = 1;
    for (final part in ['a', 'b', 'c']) {
      final sql = File('$_dir/19$part-seed-money.sql').readAsStringSync();
      final range = RegExp(r'generate_series\((\d+), (\d+)\) n')
          .firstMatch(sql)!;
      final lo = int.parse(range.group(1)!);
      final hi = int.parse(range.group(2)!);
      expect(lo, next, reason: '19$part starts where the last one ended');
      expect(hi - lo + 1, lessThanOrEqualTo(5000), reason: 'one request each');
      expect(sql, contains('((n - 1) / 400) % 36'));
      expect(sql, contains('mem.idx = (n - 1) % 400'));
      next = hi + 1;
    }
    expect(next - 1, invoices);
  });
}
