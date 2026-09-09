// SPDX-License-Identifier: 0BSD
//
// #1054 — a migration that creates a function revokes anon in the same file.
//
// Why the same file: `CREATE OR REPLACE FUNCTION` **preserves the existing
// ACL**. A function first created WITH a revoke keeps it through every
// later version; one first created WITHOUT never acquires it. The grant is
// therefore decided by the migration that introduces the function and never
// corrects itself — which is exactly how 99 of 260 public functions came to
// be executable by `anon`, 74 of them SECURITY DEFINER, until 0191 swept
// them (#1047).
//
// A revoke promised in a later migration is a promise. This rule wants it
// where the reviewer is already looking.
//
// The rule is deliberately FORWARD-looking. Everything introduced up to and
// including the sweep is covered by the sweep, so there is no baseline list
// to maintain and no historical file to relitigate: 0191 set the live ACLs,
// and a `create or replace` after it cannot undo them. What the rule guards
// is the next function nobody has written yet.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The sweep that closed the historical grants. Files up to and including
/// it are covered by it; files after it answer for themselves.
const String _sweep = '0191_revoke_anon_execute.sql';

final _create = RegExp(
  r'create\s+(?:or\s+replace\s+)?function\s+([^\s(]+)',
  caseSensitive: false,
);
final _revoke = RegExp(
  r'revoke\s+execute\s+on\s+function\s+([^\s;(]+)',
  caseSensitive: false,
);

/// `public.assert_member_quota` and `"Foo"` both reduce to a bare name, so
/// a revoke that qualifies the schema still answers a create that does not.
String _bare(String name) =>
    name.trim().toLowerCase().replaceAll('"', '').split('.').last;

/// Functions [sql] creates without revoking execute on them in the same text.
Set<String> missingRevokes(String sql) {
  final created = _create.allMatches(sql).map((m) => _bare(m.group(1)!));
  final revoked = _revoke.allMatches(sql).map((m) => _bare(m.group(1)!)).toSet();
  return created.where((c) => !revoked.contains(c)).toSet();
}

void main() {
  test('every migration after the sweep revokes what it creates', () {
    final dir = Directory('supabase/migrations');
    expect(dir.existsSync(), isTrue);

    final after = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .where((f) => f.uri.pathSegments.last.compareTo(_sweep) > 0)
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final offenders = <String>[];
    for (final file in after) {
      final missing = missingRevokes(file.readAsStringSync());
      for (final name in missing) {
        offenders.add('${file.uri.pathSegments.last}: $name');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These migrations create a function and never revoke execute '
          'on it from anon:\n${offenders.join('\n')}\n\n'
          'Add, in the SAME migration:\n'
          '  revoke execute on function <name>(<args>) from public, anon;\n\n'
          'CREATE OR REPLACE keeps the ACL a function was born with, so a '
          'revoke added later never reaches the ones already created — the '
          'omission is permanent from here.',
    );
  });

  test('the sweep this rule stands on is still in the tree', () {
    expect(
      File('supabase/migrations/$_sweep').existsSync(),
      isTrue,
      reason: 'The rule only checks migrations AFTER $_sweep because that '
          'sweep closed everything before it. If the sweep is renamed or '
          'removed, the cutoff is meaningless and the historical grants are '
          'unguarded again.',
    );
  });

  test('a create without a revoke is caught', () {
    const sql = '''
create or replace function public.tempting(p uuid)
returns void language sql as \$\$ select 1 \$\$;
''';
    expect(missingRevokes(sql), {'tempting'});
  });

  test('a revoke in the same file answers the create, schema or not', () {
    const sql = '''
create or replace function public.guarded(p uuid)
returns void language sql as \$\$ select 1 \$\$;
revoke execute on function guarded(uuid) from public, anon;
''';
    expect(missingRevokes(sql), isEmpty);
  });

  test('one file may create several, and each needs its own revoke', () {
    const sql = '''
create function alpha() returns void language sql as \$\$ select 1 \$\$;
create function beta() returns void language sql as \$\$ select 1 \$\$;
revoke execute on function alpha() from public, anon;
''';
    expect(missingRevokes(sql), {'beta'});
  });
}
