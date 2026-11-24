// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4447 -- every server read names the direction of its order. postgrest's `order(column, {ascending = false})`
// sorts descending by default, so `.order('name')` listed Z to A and `.order('sort_order')` put the place ranked
// first last, while the code read as ascending. An `.order(` without `ascending:` is counted, and the count is 0.
import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

/// The lines of [source] holding an `.order(` call whose arguments do not name `ascending:`.
List<int> undirectedOrders(String source) {
  final out = <int>[];
  for (final m in RegExp(r'\.order\(').allMatches(source)) {
    var depth = 0;
    var j = m.end;
    for (; j < source.length; j++) {
      final c = source[j];
      if (c == '(') depth++;
      if (c == ')') {
        if (depth == 0) break;
        depth--;
      }
    }
    if (!source.substring(m.end, j).contains('ascending:')) {
      out.add('\n'.allMatches(source.substring(0, m.start)).length + 1);
    }
  }
  return out;
}

void main() {
  test('every order of a server read names its direction', () {
    final hits = [
      for (final f in handWrittenDartFiles('lib'))
        for (final line in undirectedOrders(f.readAsStringSync()))
          '${f.path}:$line',
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'say ascending: true (a name, a rank, a list of things) or false (a log, newest first):\n${hits.join('\n')}',
    );
  });

  test('the check sees an order without a direction and not one with it', () {
    expect(undirectedOrders("client.from('sites').select().order('name');"), [
      1,
    ]);
    expect(
      undirectedOrders(
        "client.from('sites').select().order('name', ascending: true);",
      ),
      isEmpty,
    );
    expect(
      undirectedOrders(
        "q\n  .order(\n    'created_at',\n    ascending: false,\n  );",
      ),
      isEmpty,
    );
    expect(undirectedOrders("q.order(_column(kind)).limit(5);"), [1]);
  });
}
