// SPDX-License-Identifier: 0BSD
//
// #1321 — a row policy asks the role matrix, never "admin or owner".
//
// `is_admin_of` answers "active member, and admin or owner". The matrix
// (#513, #982) lets an owner take permissions away from the admin row,
// so a policy built on `is_admin_of` keeps serving rows the owner hid —
// ten of them did, until 0216. They also make custom roles (#1287)
// impossible: a permission granted through the matrix never passes them.
//
// Reads the migrations rather than the live database, so a branch fails
// before its migration is applied. Migrations up to 0215 are history —
// 0216 replaced every policy they created with `is_admin_of`, which the
// pgTAP file `13_matrix_policies.sql` checks against the replayed
// catalogue.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// First migration under the rule.
const _firstGoverned = 216;

final _policy = RegExp(r'create\s+policy[\s\S]*?;', caseSensitive: false);

/// Policy statements in [sql] that gate on `is_admin_of`.
List<String> adminGatedPolicies(String sql) => [
      for (final m in _policy.allMatches(sql))
        if (m.group(0)!.toLowerCase().contains('is_admin_of'))
          m.group(0)!.split('\n').first.trim(),
    ];

void main() {
  test('the detector sees an is_admin_of policy and ignores a matrix one',
      () {
    expect(
      adminGatedPolicies('create policy p on public.t\n'
          '  for select using (public.is_admin_of(workspace_id));'),
      hasLength(1),
    );
    expect(
      adminGatedPolicies('create policy p on public.t for select using ('
          "workspace_id in (select public.workspaces_permitting(array['viewFinances'])));"),
      isEmpty,
    );
  });

  test('no migration from 0216 on creates a policy on is_admin_of', () {
    final offenders = <String>[];
    for (final file in Directory('supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))) {
      final name = file.uri.pathSegments.last;
      final number = int.tryParse(name.split('_').first) ?? 0;
      if (number < _firstGoverned) continue;
      for (final hit in adminGatedPolicies(file.readAsStringSync())) {
        offenders.add('$name: $hit');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'gate the policy on the role matrix — '
          "`workspace_id in (select public.workspaces_permitting(array['<permission>']))` "
          '— so an owner who narrows the admin row narrows the rows too (#1321)',
    );
  });
}
