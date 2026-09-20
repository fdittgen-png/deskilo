// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1228 — a SECURITY DEFINER function a client can call checks who is
// calling.
//
// Three did not. Each took a member id as a parameter and answered for
// any member of any workspace: their fee band, their negotiated prices,
// their site. Definer means the function runs with the owner's rights
// and RLS does not apply, so the guard has to be written by hand — and
// three times out of fifty-seven it was forgotten.
//
// This reads the migration source, which is all a Dart suite can do
// until #1226 puts a database in CI. It catches the omission that
// actually happened: a definer function that names a member or a
// workspace and never mentions a caller check.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The helpers that constitute "the caller was checked".
const _guards = [
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

/// Definer functions that legitimately take an id and need no caller
/// check, with the reason.
const Map<String, String> _exempt = {
  'default_site': 'a workspace-level lookup used only from inside other '
      'guarded functions; not granted to authenticated',
};

void main() {
  test('every definer function granted to authenticated checks its caller',
      () {
    final dir = Directory('supabase/migrations');
    final files = dir.listSync().whereType<File>().toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

    // Latest definition wins: an anchored patch may add the guard.
    final latest = <String, String>{};
    final granted = <String>{};
    final definer = RegExp(
      r'create or replace function public\.(\w+)\s*\(',
      caseSensitive: false,
    );
    for (final f in files) {
      if (!f.path.endsWith('.sql')) continue;
      final sql = f.readAsStringSync();
      for (final m in definer.allMatches(sql)) {
        final end = sql.indexOf(r'$$;', m.start);
        final body =
            end < 0 ? sql.substring(m.start) : sql.substring(m.start, end);
        if (!body.toLowerCase().contains('security definer')) continue;
        latest[m.group(1)!] = body;
      }
      for (final m in RegExp(
        r'grant execute on function public\.(\w+)',
        caseSensitive: false,
      ).allMatches(sql)) {
        granted.add(m.group(1)!);
      }
    }

    final offenders = <String>[];
    for (final name in granted) {
      if (_exempt.containsKey(name)) continue;
      final body = latest[name];
      if (body == null) continue; // granted but not a definer function
      // Only the ones that take an id — a function with no parameters
      // can only answer for the caller.
      if (!RegExp(r'p_\w*(member|workspace|site|invoice|level|desk|seat)_id')
          .hasMatch(body)) {
        continue;
      }
      if (!_guards.any(body.contains)) offenders.add(name);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these run with the owner\'s rights, take an id from the '
          'client, and never check who is asking — so they answer for any '
          'workspace. Add the guard the other fifty-four use, or list the '
          'function in _exempt with the reason:\n${offenders.join('\n')}',
    );
  });
}
