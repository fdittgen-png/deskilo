// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4401 -- no stock read is unbounded: a table read in lib/features/stock/data goes through
// `StockRpc.rows` (a configuration list, at most `StockRpc.listCap` rows, a longer list refused) or
// `StockRpc.pages` (a list that grows with the business, read page by page) or carries its own
// `.limit(` / `.range(`. A `.from(` of a table outside them is counted, and the count is 0.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The table reads of [source] that are neither handed to `rows(` nor limited, as their line numbers.
List<int> unboundedReads(String source) {
  final out = <int>[];
  for (final m in RegExp(
    r'\.from\((?:ServerTable\.\w+|'
    "'"
    r'\w+'
    "'"
    r')\)',
  ).allMatches(source)) {
    // the statement the read is part of: back to the previous ';' or '{', forward to the next ';'
    final start = source.lastIndexOf(RegExp(r'[;{]'), m.start);
    final end = source.indexOf(';', m.end);
    final statement = source.substring(
      start + 1,
      end < 0 ? source.length : end,
    );
    if (statement.contains('.rows(') ||
        statement.contains('.pages(') ||
        statement.contains('.limit(') ||
        statement.contains('.range(')) {
      continue;
    }
    out.add('\n'.allMatches(source.substring(0, m.start)).length + 1);
  }
  return out;
}

void main() {
  test('every table read of the stock data layer is bounded', () {
    final hits = <String>[];
    for (final f in Directory(
      'lib/features/stock/data',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final line in unboundedReads(f.readAsStringSync())) {
        hits.add('${f.path}:$line');
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'read through StockRpc.rows, or limit the read:\n${hits.join('\n')}',
    );
  });

  test('the check sees an unbounded read and not a bounded one', () {
    expect(
      unboundedReads(
        "final rows = await _client.from('stock_transfers').select('id').eq('a', b);",
      ),
      [1],
    );
    expect(
      unboundedReads(
        "final rows = await StockRpc(_client).rows('x', _client.from('stock_transfers').select('id'));",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "final rows = await _client.from(ServerTable.services).select('id').limit(1);",
      ),
      isEmpty,
    );
    expect(
      unboundedReads('final m = Map<String, Object?>.from(decoded);'),
      isEmpty,
    );
  });
}
