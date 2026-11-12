// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3658 — no currency is ever a default. From migration 0735 on, no
// migration gives a currency column a literal default, and no function falls
// back to a literal currency (`coalesce(<currency>, 'EUR')`). The schema as a
// whole is stated by pgTAP 401; this lint stops a new default before it is
// applied. It looks for currency defaults, not for every three-letter code:
// reference data (a table of currencies, a fixture) is not a default.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The first migration the rule holds for.
const _from = 735;

final _fileName = RegExp(r'^(\d{4})_[a-z0-9_]+\.sql$');

/// A currency column given a literal currency as its default.
final _columnDefault = RegExp(
  r"\b\w*currenc\w*\b[^,;]*?\bdefault\s+'[A-Z]{3}'",
  caseSensitive: false,
);

/// A currency value falling back to a literal currency.
final _fallback = RegExp(
  r"coalesce\(\s*[\w.]*currenc\w*\s*,\s*'[A-Z]{3}'\s*\)",
  caseSensitive: false,
);

/// The currency defaults in [sql], as `line: text`.
List<String> currencyDefaults(String sql) {
  final lines = sql.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (!lines[i].trimLeft().startsWith('--') &&
          (_columnDefault.hasMatch(lines[i]) || _fallback.hasMatch(lines[i])))
        '${i + 1}: ${lines[i].trim()}',
  ];
}

void main() {
  test('a planted default and fallback are seen; a plain code is not', () {
    expect(
      currencyDefaults("  currency text not null default 'EUR',"),
      hasLength(1),
    );
    expect(
      currencyDefaults(
        "alter table t alter column currency set default 'USD';",
      ),
      hasLength(1),
    );
    expect(
      currencyDefaults("'currency', coalesce(v_currency, 'EUR'),"),
      hasLength(1),
    );
    expect(
      currencyDefaults("insert into currencies (code) values ('EUR');"),
      isEmpty,
    );
    expect(currencyDefaults("coalesce(nullif(p_tz, ''), 'UTC')"), isEmpty);
    expect(currencyDefaults("-- the old default 'EUR' is dropped"), isEmpty);
  });

  test('no migration from 0735 on gives a currency a default', () {
    final found = <String>[];
    for (final file in Directory('supabase/migrations').listSync()) {
      final name = file.uri.pathSegments.last;
      final m = _fileName.firstMatch(name);
      if (m == null || int.parse(m.group(1)!) < _from) continue;
      for (final hit in currencyDefaults(File(file.path).readAsStringSync())) {
        found.add('$name:$hit');
      }
    }
    expect(
      found,
      isEmpty,
      reason:
          'an amount is in the currency of its business or its parent; '
          'name it, never default it (#3658)',
    );
  });
}
