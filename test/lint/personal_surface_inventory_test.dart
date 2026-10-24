// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C1c — every personal surface carries the restrictive
// `personal_native_session` policy, so a token issued to an identity-only
// client (or a delegated one, or a banned account's) reads none of it.
//
// A personal surface is a row-level-secured table of `public` without a
// `workspace_id` column, plus Storage objects. The inventory is DERIVED:
// the tables come from the migrations' own `create table` statements (and
// any later `add column workspace_id` or `drop table`), the RLS set from
// the replay-generated policy manifest. Nothing is listed by hand, so a
// new personal table fails here until its migration adds the policy and
// the manifest lists it. pgTAP 268 proves the same against the replay.
import 'dart:io';

import 'package:deskilo/core/instance/instance_policy_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

const _policy = 'personal_native_session';

final _createTable = RegExp(
  r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?"?([a-z0-9_]+)"?\s*\(',
  caseSensitive: false,
);
final _addWorkspaceId = RegExp(
  r'alter\s+table\s+(?:if\s+exists\s+)?(?:only\s+)?(?:public\.)?([a-z0-9_]+)\s+'
  r'add\s+column\s+(?:if\s+not\s+exists\s+)?workspace_id\b',
  caseSensitive: false,
);
final _dropTable = RegExp(
  r'drop\s+table\s+(?:if\s+exists\s+)?(?:public\.)?([a-z0-9_]+)',
  caseSensitive: false,
);
final _workspaceColumn = RegExp(r'(^|[,(])\s*workspace_id\s', multiLine: true);
final _comment = RegExp(r'--[^\n]*');

/// Whether each table the migrations leave behind has a `workspace_id`.
Map<String, bool> _tablesWithWorkspace(Iterable<String> sql) {
  final tables = <String, bool>{};
  for (final raw in sql) {
    final text = raw.replaceAll(_comment, '');
    final events = <({int at, String table, bool? workspace})>[];
    for (final m in _createTable.allMatches(text)) {
      var depth = 1;
      var i = m.end;
      while (depth > 0 && i < text.length) {
        final c = text[i];
        if (c == '(') depth++;
        if (c == ')') depth--;
        i++;
      }
      final body = text.substring(m.end, i - 1);
      events.add((
        at: m.start,
        table: m.group(1)!.toLowerCase(),
        workspace: _workspaceColumn.hasMatch(body),
      ));
    }
    for (final m in _addWorkspaceId.allMatches(text)) {
      events.add((
        at: m.start,
        table: m.group(1)!.toLowerCase(),
        workspace: true,
      ));
    }
    for (final m in _dropTable.allMatches(text)) {
      events.add((
        at: m.start,
        table: m.group(1)!.toLowerCase(),
        workspace: null,
      ));
    }
    events.sort((a, b) => a.at.compareTo(b.at));
    for (final e in events) {
      if (e.workspace == null) {
        tables.remove(e.table);
      } else if (e.workspace!) {
        tables[e.table] = true;
      } else {
        tables.putIfAbsent(e.table, () => false);
      }
    }
  }
  return tables;
}

void main() {
  final manifest = parseInstancePolicies(
    File(instancePoliciesAssetPath).readAsStringSync(),
  );
  final tables = _tablesWithWorkspace(
    sqlFiles('supabase/migrations').map((f) => f.readAsStringSync()),
  );
  final secured = {
    for (final p in manifest)
      if (p.startsWith('public.')) p.split('.')[1],
  };
  final personal = {
    for (final e in tables.entries)
      if (!e.value && secured.contains(e.key)) e.key,
  };

  test('the inventory finds personal surfaces at all', () {
    // A parser that matched nothing would make the next test vacuous.
    expect(
      personal,
      containsAll(['profiles', 'account_messages', 'identity_bindings']),
    );
    expect(personal, isNot(contains('reservations')));
  });

  test(
    'every personal table carries the restrictive native-session policy',
    () {
      final unclassified = [
        for (final t in personal)
          if (!manifest.contains('public.$t.$_policy')) t,
      ]..sort();
      expect(
        unclassified,
        isEmpty,
        reason:
            'personal tables (row-level security, no workspace_id) '
            'without $_policy — a migration must create it and '
            'assets/instance/policies.txt must list it:\n'
            '${unclassified.join('\n')}',
      );
    },
  );

  test('Storage objects carry it too', () {
    expect(manifest, contains('storage.objects.$_policy'));
  });

  test('the policy is listed on personal surfaces only', () {
    final stray = [
      for (final p in manifest)
        if (p.startsWith('public.') &&
            p.endsWith('.$_policy') &&
            !personal.contains(p.split('.')[1]))
          p,
    ]..sort();
    expect(
      stray,
      isEmpty,
      reason:
          'listed on a table the inventory does not see as personal:\n'
          '${stray.join('\n')}',
    );
  });
}
