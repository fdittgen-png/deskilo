// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4146 -- member_permission_raw is has_permission_raw's body keyed by a
// member (0804): who may decide an event is counted with it, so it answers as
// has_permission does (pgTAP 457 compares the two for every right and every
// state of a member). A migration that rewrites one of the two bodies --
// whole or at an anchor -- rewrites the other in the same file.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _caller = 'has_permission_raw';
const _member = 'member_permission_raw';

/// Whether [sql] rewrites function [name]: a whole definition, or a patch of
/// its live definition.
bool rewrites(String sql, String name) {
  final text = sql.replaceAll(RegExp(r'--[^\n]*'), '');
  return RegExp(
        'create\\s+(?:or\\s+replace\\s+)?function\\s+public\\.$name\\s*\\(',
        caseSensitive: false,
      ).hasMatch(text) ||
      RegExp(
        "pg_get_functiondef\\s*\\(\\s*'public\\.$name\\s*\\(",
        caseSensitive: false,
      ).hasMatch(text);
}

/// The files after the one that first defines the member twin that rewrite
/// one of the two bodies without the other.
List<String> twinProblems(List<({String name, String sql})> migrations) {
  final out = <String>[];
  var since = false;
  for (final m in migrations) {
    final caller = rewrites(m.sql, _caller);
    final member = rewrites(m.sql, _member);
    final first = !since && member;
    since = since || member;
    if (since && !first && caller != member) {
      out.add(
        '${m.name} rewrites ${caller ? _caller : _member} '
        'without ${caller ? _member : _caller}',
      );
    }
  }
  return out;
}

void main() {
  const twin =
      'create or replace function public.member_permission_raw(p uuid, perm text) '
      r'returns boolean language sql as $f$ select true $f$;';
  const caller =
      'create or replace function public.has_permission_raw(ws uuid, perm text) '
      r'returns boolean language sql as $f$ select true $f$;';
  const patch =
      "do \$p\$ begin execute replace(pg_get_functiondef('public.has_permission_raw(uuid, text)'::regprocedure), 'a', 'b'); end \$p\$;";

  test('a rewrite of one body without the other fails, from the twin on', () {
    expect(
      twinProblems([(name: 'a', sql: caller), (name: 'b', sql: twin)]),
      isEmpty,
      reason: 'before the twin exists, the caller body changes alone',
    );
    expect(
      twinProblems([(name: 'b', sql: twin), (name: 'c', sql: caller)]),
      hasLength(1),
    );
    expect(
      twinProblems([(name: 'b', sql: twin), (name: 'c', sql: patch)]),
      hasLength(1),
    );
    expect(
      twinProblems([(name: 'b', sql: twin), (name: 'c', sql: '$patch\n$twin')]),
      isEmpty,
    );
    expect(
      twinProblems([(name: 'b', sql: twin), (name: 'c', sql: twin)]),
      hasLength(1),
    );
  });

  test('the two bodies change together in the migrations', () {
    final files = [
      for (final f in sqlFiles('supabase/migrations'))
        (name: f.uri.pathSegments.last, sql: f.readAsStringSync()),
    ];
    expect(files.any((f) => rewrites(f.sql, _member)), isTrue);
    expect(twinProblems(files), isEmpty);
  });
}
