// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (MD-06) -- the currencies are one reference: the money kernel's currencyReference, which the app converts and
// offers with, and the server's public.currency_reference (0993, or the latest migration that seeds it), which
// currency_minor_digits reads. Same codes, same minor digits, same business subset, same withdrawal days, same order.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _row = RegExp(
  r"^\s*\('([A-Z]{3})', (\d), (true|false), (null|date '(\d{4}-\d{2}-\d{2})')\),?;?\s*$",
  multiLine: true,
);

/// The rows of the latest migration that seeds the reference.
List<(String, int, bool, String?)> _serverRows() {
  final files = sqlFiles('supabase/migrations')..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files.reversed) {
    final sql = file.readAsStringSync();
    final at = sql.indexOf('insert into public.currency_reference');
    if (at < 0) continue;
    final block = sql.substring(at, sql.indexOf(';\n', at) + 2);
    return [for (final m in _row.allMatches(block)) (m[1]!, int.parse(m[2]!), m[3] == 'true', m[5])];
  }
  return const [];
}

void main() {
  test('the server seeds the kernel\'s currencies, row for row', () {
    final server = _serverRows();
    expect(server, isNotEmpty, reason: 'no migration seeds public.currency_reference');
    expect(server, [for (final c in currencyReference) (c.code, c.minorDigits, c.business, c.withdrawnOn)]);
  });

  test('the derived subsets are the reference\'s', () {
    expect(Currencies.zeroDecimal, {
      for (final c in currencyReference)
        if (c.minorDigits == 0) c.code,
    });
    expect(Currencies.selectable, [
      for (final c in currencyReference)
        if (c.business) c.code,
    ]);
    expect(supportedCurrencies, {for (final c in currencyReference) c.code});
  });

  test('a code the reference does not hold has no digits', () {
    expect(Currencies.minorDigits('jpy'), 0);
    expect(Currencies.minorDigits('KWD'), 3);
    expect(Currencies.isKnown('XYZ'), isFalse);
    expect(() => Currencies.minorDigits('XYZ'), throwsArgumentError);
  });
}
