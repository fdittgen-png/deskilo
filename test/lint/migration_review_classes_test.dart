// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Three classes of defect that reviews found again and again in migrations,
// caught here without a review. Every rule looks forward: a migration up to
// [_firstChecked - 1] is applied and never rewritten, so it is grandfathered
// by its number, as in migration_grants_test.
//
//  (a) TIME   a business date is the workspace's day (`workspace_today`), never
//             the server's: no `current_date` and no `now()::date`.
//  (b) RESTATE a full `create or replace function` of a function an earlier
//             migration defines says `-- restates NNNN` directly above it, and
//             NNNN is the LATEST earlier migration that defines it, so the
//             author diffed against the live body and not an old copy.
//  (c) AUDIENCE a column added to a table adds its audience in the same file:
//             a column grant or revoke naming it, or the comment
//             `-- audience: all row readers`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The first migration the rules apply to; earlier ones are grandfathered.
const String _firstChecked = '0859';

final _lineComment = RegExp(r'--[^\n]*');

String _code(String sql) => sql.replaceAll(_lineComment, '');

final _today = RegExp(r'\bcurrent_date\b|now\(\)\s*::\s*date', caseSensitive: false);

/// The server-clock dates [sql] reads, comments left out.
List<String> serverDates(String sql) =>
    [for (final m in _today.allMatches(_code(sql))) m.group(0)!];

final _create = RegExp(
  r'create\s+or\s+replace\s+function\s+public\.([a-z0-9_]+)',
  caseSensitive: false,
);

final _restates = RegExp(r'--\s*restates\s+(\d{4})\b');

/// The public functions [sql] creates, in order.
List<String> definedFunctions(String sql) =>
    [for (final m in _create.allMatches(_code(sql))) m.group(1)!.toLowerCase()];

/// For each `create or replace function public.f` in [sql] that [latest] says an
/// earlier migration defines: the number its comment must name, or a message
/// when the comment is missing or names another one.
List<String> restateFaults(String sql, Map<String, String> latest) {
  final faults = <String>[];
  for (final m in _create.allMatches(sql)) {
    final fn = m.group(1)!.toLowerCase();
    final want = latest[fn];
    if (want == null) continue;
    final above = sql.substring(0, m.start).split('\n');
    final near = above.reversed.take(4).join('\n');
    final said = _restates.allMatches(near).map((x) => x.group(1)).toList();
    if (said.isEmpty) {
      faults.add('$fn: add `-- restates $want` above it');
    } else if (!said.contains(want)) {
      faults.add('$fn: says restates ${said.last}, the latest definition is $want');
    }
  }
  return faults;
}

final _addColumn = RegExp(
  r'alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?([a-z0-9_.]+)\s+add\s+column\s+(?:if\s+not\s+exists\s+)?([a-z0-9_]+)',
  caseSensitive: false,
);

/// The columns [sql] adds with no stated audience.
List<String> unstatedAudiences(String sql) {
  final code = _code(sql);
  if (RegExp(r'--\s*audience:\s*all row readers').hasMatch(sql)) return const [];
  return [
    for (final m in _addColumn.allMatches(code))
      if (!RegExp(
        '(grant|revoke)\\s+select\\s*\\([^)]*\\b${m.group(2)}\\b[^)]*\\)',
        caseSensitive: false,
      ).hasMatch(code))
        '${m.group(1)}.${m.group(2)}',
  ];
}

void main() {
  final files = sqlFiles('supabase/migrations')
    ..sort((a, b) => a.path.compareTo(b.path));
  String nameOf(File f) => f.uri.pathSegments.last;

  test('a new migration reads no server date (TIME)', () {
    final offenders = [
      for (final f in files)
        if (nameOf(f).compareTo(_firstChecked) >= 0)
          for (final d in serverDates(f.readAsStringSync())) '${nameOf(f)}: $d',
    ];
    expect(offenders, isEmpty,
        reason: 'A business date is the workspace day: use public.workspace_today(ws), '
            'never current_date or now()::date.');
  });

  test('a restated function names the latest migration that defines it (RESTATE)', () {
    final latest = <String, String>{};
    final offenders = <String>[];
    for (final f in files) {
      final sql = f.readAsStringSync();
      final number = nameOf(f).substring(0, 4);
      if (nameOf(f).compareTo(_firstChecked) >= 0) {
        for (final fault in restateFaults(sql, latest)) {
          offenders.add('${nameOf(f)}: $fault');
        }
      }
      for (final fn in definedFunctions(sql)) {
        latest[fn] = number;
      }
    }
    expect(offenders, isEmpty,
        reason: 'Diff the restatement against the latest definition and say so.');
  });

  test('a column a migration adds states its audience (AUDIENCE)', () {
    final offenders = [
      for (final f in files)
        if (nameOf(f).compareTo(_firstChecked) >= 0)
          for (final c in unstatedAudiences(f.readAsStringSync())) '${nameOf(f)}: $c',
    ];
    expect(offenders, isEmpty,
        reason: 'Add a column grant or revoke naming the column, or the comment '
            '`-- audience: all row readers`, in the same migration.');
  });

  group('the guards can fail', () {
    test('TIME', () {
      expect(serverDates('select current_date;'), isNotEmpty);
      expect(serverDates('select now()::date;'), isNotEmpty);
      expect(serverDates('-- current_date is wrong\nselect 1;'), isEmpty);
    });
    test('RESTATE', () {
      const sql = 'create or replace function public.f() returns int as \$\$ select 1 \$\$;';
      expect(restateFaults(sql, {'f': '0100'}), isNotEmpty);
      expect(restateFaults('-- restates 0100\n$sql', {'f': '0100'}), isEmpty);
      expect(restateFaults('-- restates 0090\n$sql', {'f': '0100'}), isNotEmpty);
      expect(restateFaults(sql, {}), isEmpty);
    });
    test('AUDIENCE', () {
      const add = 'alter table public.t add column c int;';
      expect(unstatedAudiences(add), ['public.t.c']);
      expect(unstatedAudiences('$add\n-- audience: all row readers'), isEmpty);
      expect(unstatedAudiences('$add\nrevoke select (c) on public.t from authenticated;'), isEmpty);
    });
  });
}
