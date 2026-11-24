// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4446, #4401 -- no list read is cut short without a word. PostgREST stops every answer at the project's
// `max_rows` and says nothing, so a `.from(…).select(…)` with no paging returns a list that looks whole and is not.
// A table read in a data layer goes through `fetchAllPages` / `fetchAllIn` (page by page to an empty page),
// `fetchConfigurationList` (the same, refused past the configuration cap), the
// stock helpers `StockRpc.rows` / `StockRpc.pages`, or carries its own `.limit(` / `.range(` / `.single(` /
// `.maybeSingle(`. What cannot be fixed yet is docs/design/BOUNDED_READS_BASELINE.txt (`path table`, one line per
// read), which only shrinks.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _baselinePath = 'docs/design/BOUNDED_READS_BASELINE.txt';

final _bounded = RegExp(
  r'\.(limit|range|single|maybeSingle|rows|pages)\(|fetchAllPages|fetchAllIn|fetchPages|fetchConfigurationList|CountOption',
);

/// [source] with its `//` comments blanked, the line breaks kept: a `;` in a comment ends no statement.
String _withoutComments(String source) =>
    source.replaceAllMapped(RegExp(r'//[^\n]*'), (m) => ' ' * m[0]!.length);

/// The table reads of [source] that nothing bounds, as the table each one reads.
List<String> unboundedReads(String source) {
  final code = _withoutComments(source);
  final out = <String>[];
  for (final m in RegExp(r'\.from\(([^)]*)\)').allMatches(code)) {
    final start = code.lastIndexOf(RegExp(r'[;{]'), m.start);
    final end = code.indexOf(';', m.end);
    final statement = code.substring(start + 1, end < 0 ? code.length : end);
    // a write (one that answers its rows with `.select` too), a storage bucket or a map copy is not a list read
    final chain = statement.substring(statement.indexOf('.from('));
    if (!chain.contains('.select(') ||
        RegExp(r'\.(update|insert|upsert|delete)\(').hasMatch(chain)) {
      continue;
    }
    // a read built in a block-bodied page builder: `fetchAllPages(…, build: () { var query = …; })`
    final before = code.substring(
      (start - 160).clamp(0, code.length),
      start + 1,
    );
    if (_bounded.hasMatch(statement) ||
        RegExp(
          r'fetch(AllPages|AllIn|ConfigurationList)\([^;]*build: \([^)]*\) \{$',
        ).hasMatch(before)) {
      continue;
    }
    // a query built in a variable and bounded where it is read: `var query = …; … await query.limit(n)`
    final built = RegExp(r'^\s*var (\w+) =').firstMatch(statement)?.group(1);
    if (built != null &&
        RegExp('\\b$built\\b[^;]*\\.(limit|range)\\(').hasMatch(
          code.substring(
            end < 0 ? code.length : end,
            ((end < 0 ? code.length : end) + 1500).clamp(0, code.length),
          ),
        )) {
      continue;
    }
    out.add(m[1]!.trim());
  }
  return out;
}

List<String> _found() => [
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart') &&
        f.path.contains('/data/') &&
        !f.path.endsWith('.g.dart'))
      for (final table in unboundedReads(f.readAsStringSync()))
        '${f.path} $table',
]..sort();

List<String> _baseline() => [
  for (final l in File(_baselinePath).readAsLinesSync())
    if (l.trim().isNotEmpty && !l.startsWith('#')) l.trim(),
]..sort();

/// The lines of [a] not matched one for one in [b].
List<String> _minus(List<String> a, List<String> b) {
  final left = [...b];
  return [
    for (final x in a)
      if (!left.remove(x)) x,
  ];
}

void main() {
  test('no new list read is left to the server\'s row cap', () {
    final added = _minus(_found(), _baseline());
    expect(
      added,
      isEmpty,
      reason:
          'read it page by page with fetchAllPages (a list that grows with the business), fetchConfigurationList (a configuration list), or limit it:\n${added.join('\n')}',
    );
  });

  test('the baseline only shrinks: a read made bounded leaves it', () {
    final stale = _minus(_baseline(), _found());
    expect(
      stale,
      isEmpty,
      reason: 'remove these lines from $_baselinePath:\n${stale.join('\n')}',
    );
  });

  test('the check sees an unbounded read and not a bounded one', () {
    expect(
      unboundedReads(
        "var query = client.from('notes').select();\nif (a) query = query.eq('a', a);\nfinal rows = await query.order('id').limit(50);",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "var query = client.from('notes').select();\nif (a) query = query.eq('a', a);\nfinal rows = await query.order('id');",
      ),
      ["'notes'"],
    );
    expect(
      unboundedReads(
        "final changed = await client.from('members').update({'a': 1}).eq('id', x).select('id');",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "final rows = await fetchConfigurationList(table: 'sites', build: () => client.from('sites').select().order('id'));",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "final rows = await client.from('members').select().eq('a', b);",
      ),
      ["'members'"],
    );
    expect(
      unboundedReads(
        "final rows = await fetchAllPages(table: 'm', build: () => client.from('members').select().order('id'));",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "final rows = await client.from('notes').select()\n  // a; in a comment\n  .limit(100);",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "await client.from('members').update({'a': 1}).eq('id', x);",
      ),
      isEmpty,
    );
    expect(
      unboundedReads(
        "final row = await client.from('members').select().eq('id', x).maybeSingle();",
      ),
      isEmpty,
    );
  });
}
