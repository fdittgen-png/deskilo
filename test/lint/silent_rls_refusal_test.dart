// SPDX-License-Identifier: 0BSD
//
// #1269 — a write RLS refuses does not raise. It matches no rows.
//
// `workspaces_update` is owner-only (0002, widened to active co-owners
// by 0982's `is_owner_of`), and `workspaceSettings` is a configurable
// permission: an owner can grant it to the admin row of the matrix.
// That admin then opens the form, edits, saves, is told "Workspace
// saved." — and every field goes nowhere. Reopening shows the old
// values, which is exactly the shape the language report arrived in.
//
// PostgREST returns 204 with no body for an update it matched nothing
// with, so the client cannot tell it apart from a success. Asking for
// the row back (`.select('id')`) is what makes the difference visible,
// and `_updateWorkspaceRow` is the one place that does it.
//
// This is a source lint rather than a behaviour test because the
// behaviour only exists against a real Postgres with RLS on: the fake
// repository writes to a list, where every write succeeds. The pgTAP
// suite proves the policy; this proves the client asks.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The repository that owns the `workspaces` row.
const _repository =
    'lib/features/workspace/data/supabase_workspace_repository.dart';

/// The helper every row write must go through.
const _helper = '_updateWorkspaceRow';

void main() {
  test('every workspaces-row write goes through the verifying helper', () {
    final lines = File(_repository).readAsLinesSync();
    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimLeft().startsWith('//')) continue;
      if (!line.contains("from('workspaces')")) continue;
      // The statement may wrap; read to its semicolon.
      final buffer = StringBuffer(line);
      for (var j = i + 1; j < lines.length && !buffer.toString().contains(';');
          j++) {
        buffer.write(lines[j]);
      }
      final statement = buffer.toString();
      if (!statement.contains('.update(')) continue;
      // The helper itself is the one place allowed to say it.
      if (statement.contains(".select('id')")) continue;
      offenders.add('$_repository:${i + 1}: ${line.trim()}');
    }
    expect(
      offenders,
      isEmpty,
      reason: 'a bare update on `workspaces` reports success when RLS '
          'refused it — the owner-only policy then makes a delegated '
          'admin\'s Save a lie. Write it through $_helper, which reads '
          'the id back and raises on an empty result.\n'
          '${offenders.join('\n')}',
    );
  });

  test('the helper actually checks what came back', () {
    final source = File(_repository).readAsStringSync();
    final at = source.indexOf('Future<void> $_helper(');
    expect(at, greaterThan(0), reason: '$_helper is gone — so is the guard');
    final body = source.substring(at, source.indexOf('\n  }', at));
    expect(body, contains(".select('id')"));
    expect(body, contains('rows.isEmpty'));
    expect(body, contains('throw'),
        reason: 'reading the row back and ignoring it guards nothing');
  });
}
