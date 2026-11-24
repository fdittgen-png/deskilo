// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The stock screens share one page shell, one read answer and one refusal
// path. Each count below only falls, and a count that fell lowers its line in
// the same change (a ceiling above the count fails too):
//  - a page built by hand (`Scaffold(` outside the shell);
//  - the connect wording reused as a retry label (`identityConnectRetry`);
//  - a plain Material `Chip(` drawn as a status (`StatusChip` says it in words
//    and in a tone);
//  - `on Object catch` anywhere in the stock feature (one guarded path takes
//    them over).
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _presentation = 'lib/features/stock/presentation';
const _feature = 'lib/features/stock';
const _shell = 'stock_page_shell.dart';

/// Code lines of [source]: line comments dropped.
String _code(String source) =>
    source.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

int _count(String root, RegExp pattern, {String? skipFile}) {
  var total = 0;
  for (final f in handWrittenDartFiles(root)) {
    if (skipFile != null &&
        f.path.replaceAll(r'\', '/').endsWith('/$skipFile')) {
      continue;
    }
    total += pattern.allMatches(_code(f.readAsStringSync())).length;
  }
  return total;
}

/// Measured on 24 Nov 2026 before the sweep: 15 pages, 9 retry labels,
/// 2 chips, 52 catches. Only falls.
const _ceilings = <String, int>{
  'hand-built pages': 0,
  'connect wording as retry': 0,
  'plain chips as status': 0,
  'on Object catch': 47,
};

Map<String, int> _measure() => {
  'hand-built pages': _count(
    _presentation,
    RegExp(r'\bScaffold\('),
    skipFile: _shell,
  ),
  'connect wording as retry': _count(
    _presentation,
    RegExp(r'\bidentityConnectRetry\b'),
  ),
  'plain chips as status': _count(
    _presentation,
    RegExp(r'(?<![A-Za-z])Chip\('),
  ),
  'on Object catch': _count(_feature, RegExp(r'\bon Object catch\b')),
};

void main() {
  test('the detectors, on planted text', () {
    expect(
      RegExp(r'\bScaffold\(')
          .allMatches(_code('// Scaffold(\nreturn Scaffold('))
          .length,
      1,
    );
    expect(
      RegExp(r'(?<![A-Za-z])Chip\(')
          .allMatches('Chip( StatusChip( FilterChip( ChoiceChip(')
          .length,
      1,
    );
  });

  test('the stock screens only move onto the shared shell, read and refusal', () {
    final actual = _measure();
    expect(
      [
        for (final k in _ceilings.keys)
          if (actual[k] != _ceilings[k])
            '$k: ${actual[k]} (ceiling ${_ceilings[k]})',
      ],
      isEmpty,
      reason:
          'build a stock page with StockPageShell, a read with StockRead, a '
          'status with StatusChip; when a count fell, lower its line.\n$actual',
    );
  });
}
