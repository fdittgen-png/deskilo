// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4511 (STK-09) -- the notes and coins are one reference: the money kernel's cashDenominations, which the drawer's count
// lists, and the server's public.cash_denominations (0997, or the latest migration that seeds it), which a session's
// count is checked against. Same currencies, values, forms and withdrawal days, in the same order.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _row = RegExp(
  r"^\s*\('([A-Z]{3})', (\d+), '(note|coin)', (null|date '(\d{4}-\d{2}-\d{2})')\),?;?\s*$",
  multiLine: true,
);

List<(String, int, String, String?)> _serverRows() {
  final files = sqlFiles('supabase/migrations')..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files.reversed) {
    final sql = file.readAsStringSync();
    final at = sql.indexOf('insert into public.cash_denominations');
    if (at < 0) continue;
    final block = sql.substring(at, sql.indexOf(';\n', at) + 2);
    return [for (final m in _row.allMatches(block)) (m[1]!, int.parse(m[2]!), m[3]!, m[5])];
  }
  return const [];
}

void main() {
  test('the server seeds the kernel\'s notes and coins, row for row', () {
    final server = _serverRows();
    expect(server, isNotEmpty, reason: 'no migration seeds public.cash_denominations');
    expect(server, [for (final d in cashDenominations) (d.currency, d.valueMinor, d.form.name, d.withdrawnOn)]);
  });

  test('every listed currency is one of the reference, and its values are whole minor units of it', () {
    for (final d in cashDenominations) {
      expect(Currencies.isKnown(d.currency), isTrue, reason: d.currency);
      expect(d.valueMinor, greaterThan(0));
    }
  });

  test('a till counts in its pick among the currency\'s values, largest first; a currency not listed by its total', () {
    expect(cashValuesOf('EUR').first, 50000);
    expect(cashValuesOf('EUR').last, 1);
    expect(cashValuesOf('USD').where((v) => v == 100).length, 1, reason: 'a dollar note and coin count once');
    expect(tillCashValues('EUR', [1000, 5, 99]), [1000, 5], reason: 'a value the currency has not is left out');
    expect(tillCashValues('EUR', [99]), cashValuesOf('EUR'), reason: 'a pick of nothing current is the whole list');
    expect(cashValuesOf('THB'), isEmpty);
  });
}
