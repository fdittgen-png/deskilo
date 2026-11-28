// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4501 (FIN-09) -- the e-invoicing address schemes are one list: the invoice model's easSchemes, which the app
// offers, and the server's `public.einvoice_scheme_pattern` (0989, or the latest migration that defines it), which
// refuses what the list does not hold. Same codes, same patterns, same order.

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

final _row = RegExp(r"^\s*\('([A-Z0-9]+)', '((?:[^']|'')*)'\),?\s*$", multiLine: true);

/// The body of the latest migration's `einvoice_scheme_pattern`.
String _latestDefinition() {
  final files = sqlFiles('supabase/migrations')..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files.reversed) {
    final sql = file.readAsStringSync();
    final at = sql.indexOf('create or replace function public.einvoice_scheme_pattern(');
    if (at < 0) continue;
    return sql.substring(at, sql.indexOf(r'$fn$;', at));
  }
  return '';
}

void main() {
  final body = _latestDefinition();

  test('the server\'s definition is found', () => expect(body, isNotEmpty));

  test('the server holds the invoice model\'s schemes, with the same patterns, in the same order', () {
    final server = [for (final m in _row.allMatches(body)) (m[1]!, m[2]!.replaceAll("''", "'"))];
    expect(server, [for (final s in easSchemes) (s.code, s.pattern)]);
  });

  test('every pattern accepts its own example and refuses an empty identifier', () {
    const examples = {
      '0002': '732829320',
      '0007': '5560125790',
      '0009': '73282932000074',
      '0060': '123456789',
      '0088': '4000001000005',
      '0106': '12345678',
      '0151': '51824753556',
      '0183': 'CHE123456789',
      '0190': '00000001234567890000',
      '0192': '974760673',
      '0201': 'UFY9MH',
      '0204': '991-33333TEST-33',
      '0208': '0123456749',
      '0210': 'RSSMRA80A01H501U',
      '0211': '01234567890',
      '0225': '732829320_ACCOUNTING',
      '9915': 'ATU12345678',
      '9920': 'ESB12345678',
      '9925': 'BE0123456749',
      '9930': 'DE123456789',
      '9944': 'NL123456789B01',
      '9957': 'FR40303265045',
      'EM': 'billing@example.org',
    };
    expect(examples.keys.toSet(), {for (final s in easSchemes) s.code}, reason: 'one example per scheme');
    for (final s in easSchemes) {
      expect(s.accepts(examples[s.code]!), isTrue, reason: s.code);
      expect(s.accepts(''), isFalse, reason: s.code);
    }
  });

  test('an address is refused for its scheme or its form, and kept as it was stored', () {
    expect(easAddressRefusal('', ''), isNull);
    expect(easAddressRefusal('', '73282932000074'), EasRefusal.scheme);
    expect(easAddressRefusal('XX99', '73282932000074'), EasRefusal.scheme);
    expect(easAddressRefusal('0009', '7328'), EasRefusal.identifier);
    expect(easAddressRefusal(' 0009 ', ' 73282932000074 '), isNull);
    expect(easAddressRefusal('zz01', 'legacy', storedScheme: 'ZZ01', storedIdentifier: 'legacy'), isNull);
    expect(easAddressRefusal('ZZ01', 'legacy-2', storedScheme: 'ZZ01', storedIdentifier: 'legacy'), EasRefusal.scheme);
  });
}
