// SPDX-License-Identifier: 0BSD
//
// #1120 — a grant row may never be the thing that proves access.
//
// The rule comes from a security review of a sibling app (Sparkilo 6.0.5,
// F-Droid !42093). Its `trip_shares` table let a client INSERT a share
// when `owner_id = auth.uid()`. That predicate proves who WROTE the
// grant row and nothing about the resource the row points at, so anyone
// holding a trip id could write a formally valid grant naming themselves
// as both owner and recipient — and the shared-read policy, which
// matched on trip id and recipient and never compared the trip's real
// owner, then evaluated to true.
//
// What makes that possible is a client write policy on the grant table.
// Take it away and the shape cannot be built: the only way to create a
// grant is a `SECURITY DEFINER` function, and a definer function has to
// decide, in its first statement, who is allowed to call it.
//
// So this lint refuses an INSERT, UPDATE, DELETE or ALL policy on any
// table whose name says it hands out access. It is deliberately about
// the NAME: `_grants`, `_shares`, `_invitations`, `_permissions`. A
// table called that is a sharing surface whatever its columns say, and
// the next one will be added by somebody who greps for this one.
//
// It reads the migrations rather than the live database because it has
// to fail a BRANCH, before the migration is applied, which is the only
// moment the answer is still cheap.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A table whose name says it grants access to something else.
final _grantTable = RegExp(r'_(grants|shares|invitations|permissions)$');

/// `create policy <name> on <table> for <cmd>` — `for select` is the only
/// verb allowed on such a table, and a policy with no `for` clause is
/// `FOR ALL`, which is the dangerous default this rule exists to catch.
final _policy = RegExp(
  r'create\s+policy\s+[^\s]+\s+on\s+([a-z0-9_."]+)\s*'
  r'(?:\n\s*)?(?:for\s+(select|insert|update|delete|all))?',
  caseSensitive: false,
);

String _bare(String name) =>
    name.trim().toLowerCase().replaceAll('"', '').split('.').last;

/// Write policies [sql] creates on grant-shaped tables, as
/// `table:command` pairs.
List<String> writePoliciesOnGrantTables(String sql) {
  final found = <String>[];
  for (final m in _policy.allMatches(sql)) {
    final table = _bare(m.group(1)!);
    if (!_grantTable.hasMatch(table)) continue;
    final cmd = (m.group(2) ?? 'all').toLowerCase();
    if (cmd != 'select') found.add('$table:$cmd');
  }
  return found;
}

void main() {
  test('no grant-shaped table carries a client write policy', () {
    final offenders = <String>[];
    for (final file in Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))) {
      for (final hit in writePoliciesOnGrantTables(file.readAsStringSync())) {
        offenders.add('${file.uri.pathSegments.last}: $hit');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'A client write policy on a grant table can only ever prove '
          'who wrote the row, never what they own — the Sparkilo S01 '
          'shape. Create grants from a SECURITY DEFINER function that '
          'checks ownership of the RESOURCE first (#1120). Found:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the rule recognises the shape it is written against', () {
    // The sibling app's policy, transcribed. If this stops being caught,
    // the regex has drifted and the rule above is decorative.
    expect(
      writePoliciesOnGrantTables('''
        create policy trip_shares_write on public.trip_shares
          for insert to authenticated
          with check (owner_id = auth.uid());
      '''),
      ['trip_shares:insert'],
    );
    // A policy with no `for` clause is FOR ALL — the silent one.
    expect(
      writePoliciesOnGrantTables('''
        create policy anything on public.workspace_template_grants
          to authenticated using (true);
      '''),
      ['workspace_template_grants:all'],
    );
    // Reading is what these tables are for.
    expect(
      writePoliciesOnGrantTables('''
        create policy ok on public.workspace_template_grants
          for select to authenticated using (true);
      '''),
      isEmpty,
    );
    // A table that is not a sharing surface is none of this rule's
    // business.
    expect(
      writePoliciesOnGrantTables('''
        create policy profiles_update on public.profiles
          for update to authenticated using (id = auth.uid());
      '''),
      isEmpty,
    );
  });

  test('the template grants table has exactly one policy, and it reads', () {
    // The specific invariant, not just the general rule: 0198 must ship
    // a read policy and nothing else.
    final sql =
        File('supabase/migrations/0199_template_library.sql').readAsStringSync();
    final policies = RegExp(
      r'create\s+policy\s+([^\s]+)\s+on\s+public\.workspace_template_grants',
      caseSensitive: false,
    ).allMatches(sql).map((m) => m.group(1)!).toList();
    expect(policies, ['workspace_template_grants_read']);
    expect(writePoliciesOnGrantTables(sql), isEmpty);
  });
}
