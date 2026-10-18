// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2588 C1 — which SECURITY DEFINER functions a signed-in person can call
// without anything in their body that looks at who is calling.
//
// This is a HEURISTIC over migration text, not a security proof (the proof is
// the real-role database and HTTP checks in CI). It exists to keep a new
// unguarded definer function from slipping in unseen. What it models, and
// what the first version got wrong:
//
//  * A function body is the text between its own dollar-quote tags, whatever
//    the tag is. (The first version looked for `$$;`, so a `$fn$` function
//    ran on into the NEXT function and borrowed its `auth.uid()`.)
//  * Comments and string literals are removed before a guard is looked for:
//    a guard NAMED in a comment or a message is not a guard.
//  * Overloads are different functions: a function is keyed by its name and
//    its number of parameters, so a guarded `f(a)` does not cover `f(a, b)`.
//  * Exposure follows the privileges: Supabase gives `authenticated` execute
//    on every new function, so a function is exposed from its creation until
//    a later `revoke execute ... from ... authenticated`, and again after a
//    later grant. Trigger functions cannot be called as a function and are
//    out of scope; so are invoker functions (RLS applies to them).
//  * A function that only calls a guarded function (one level) counts as
//    guarded: a thin wrapper such as `select financial_subject_command_v1(...)`.
//    Two levels, or a guard token that is merely nearby, do not count.
import 'dart:io';

/// The helpers that constitute "the caller was checked".
const callerGuards = [
  'is_member_of',
  'is_admin_of',
  'is_owner_of',
  'my_active_member',
  'issuing_member',
  'has_permission',
  'shares_workspace_with',
  'is_platform_admin',
  'auth.uid()',
];

typedef MigrationText = ({String path, String sql});

class _Routine {
  _Routine({
    required this.name,
    required this.arity,
    required this.definer,
    required this.returnsTrigger,
    required this.body,
  });

  final String name;
  final int arity;
  final bool definer;
  final bool returnsTrigger;
  final String body;

  String get key => '$name/$arity';
}

String _strip(String sql) => sql
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'--[^\n]*'), '')
    .replaceAll(RegExp(r"'(?:[^']|'')*'"), "''");

int _closingParen(String s, int from) {
  var depth = 1;
  var i = from;
  while (i < s.length && depth > 0) {
    final c = s[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  return i;
}

int _arity(String params) {
  final p = params.trim();
  if (p.isEmpty) return 0;
  var depth = 0;
  var n = 1;
  for (final c in p.split('')) {
    if (c == '(' || c == '[') depth++;
    if (c == ')' || c == ']') depth--;
    if (c == ',' && depth == 0) n++;
  }
  return n;
}

final _definition = RegExp(
  r'create\s+(?:or\s+replace\s+)?function\s+public\.(\w+)\s*\(',
  caseSensitive: false,
);
final _privilege = RegExp(
  r'\b(grant|revoke)\s+execute\s+on\s+function\s+public\.(\w+)\s*\(([^)]*)\)'
  r'\s+(?:to|from)\s+([^;]*);',
  caseSensitive: false,
);

bool _guarded(String body) => callerGuards.any(body.contains);

typedef _Scan = ({
  Map<String, _Routine> latest,
  Map<String, List<_Routine>> byName,
  Map<String, bool> exposed,
});

/// Reads the migrations in order: the latest definition of every function,
/// the definitions by name, and whether authenticated may execute each one
/// after the grants and revokes the text states.
_Scan _scan(Iterable<MigrationText> migrations) {
  final latest = <String, _Routine>{};
  final byName = <String, List<_Routine>>{};
  final exposed = <String, bool>{};

  for (final migration in migrations) {
    final raw = migration.sql;
    final events = <({int at, String kind, String key, Object? routine})>[];
    for (final m in _definition.allMatches(raw)) {
      final close = _closingParen(raw, m.end);
      final params = raw.substring(m.end, close - 1);
      final window = raw.substring(
        close,
        close + 4000 > raw.length ? raw.length : close + 4000,
      );
      final tag = RegExp(
        r'\bas\s+(\$[A-Za-z_0-9]*\$)',
        caseSensitive: false,
      ).firstMatch(window);
      if (tag == null) continue;
      final header = window.substring(0, tag.start).toLowerCase();
      final start = close + tag.end;
      final end = raw.indexOf(tag.group(1)!, start);
      final body = _strip(raw.substring(start, end < 0 ? raw.length : end));
      final routine = _Routine(
        name: m.group(1)!,
        arity: _arity(params),
        definer: header.contains('security definer'),
        returnsTrigger: header.contains('returns trigger'),
        body: body,
      );
      events.add((
        at: m.start,
        kind: 'def',
        key: routine.key,
        routine: routine,
      ));
    }
    for (final g in _privilege.allMatches(raw)) {
      events.add((
        at: g.start,
        kind: '${g.group(1)!.toLowerCase()}:${g.group(4)!.toLowerCase()}',
        key: '${g.group(2)}/${_arity(g.group(3)!)}',
        routine: null,
      ));
    }
    events.sort((a, b) => a.at.compareTo(b.at));
    for (final e in events) {
      if (e.kind == 'def') {
        final r = e.routine! as _Routine;
        latest[e.key] = r;
        byName.putIfAbsent(r.name, () => []).add(r);
        exposed.putIfAbsent(e.key, () => true);
      } else if (e.kind.startsWith('grant:') &&
          e.kind.contains('authenticated')) {
        exposed[e.key] = true;
      } else if (e.kind.startsWith('revoke:') &&
          e.kind.contains('authenticated')) {
        exposed[e.key] = false;
      }
    }
  }

  return (latest: latest, byName: byName, exposed: exposed);
}

/// #2588 C2 -- the `name/parameter count` of every elevated, non-trigger
/// function the TEXT leaves executable by authenticated. The effective
/// contract (assets/instance/contract.txt, written from the replayed
/// database) is checked against it: a function the database exposes that
/// this does not list is one the scan cannot see.
List<String> scannedExposedDefiners(Iterable<MigrationText> migrations) {
  final scan = _scan(migrations);
  return [
    for (final entry in scan.latest.entries)
      if (entry.value.definer &&
          !entry.value.returnsTrigger &&
          scan.exposed[entry.key] == true)
        entry.key,
  ]..sort();
}

/// The `name/parameter count` of every exposed, elevated, non-trigger
/// function whose body neither checks the caller nor hands over to a function
/// that does, sorted. [migrations] are read in the order given.
List<String> unguardedExposedDefiners(Iterable<MigrationText> migrations) {
  final scan = _scan(migrations);
  final latest = scan.latest;
  final byName = scan.byName;
  final exposed = scan.exposed;
  final call = RegExp(r'\b(\w+)\s*\(');
  final out = <String>[];
  for (final entry in latest.entries) {
    final r = entry.value;
    if (!r.definer || r.returnsTrigger || exposed[entry.key] != true) continue;
    if (_guarded(r.body)) continue;
    final delegates = call
        .allMatches(r.body)
        .map((m) => m.group(1)!)
        .where((n) => n != r.name)
        .any((n) => (byName[n] ?? const []).any((h) => _guarded(h.body)));
    if (!delegates) out.add(entry.key);
  }
  return out..sort();
}

/// The migrations of this repository, in numbered order.
List<MigrationText> repositoryMigrations(List<File> files) => [
  for (final f in files) (path: f.path, sql: f.readAsStringSync()),
];
