// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 (0693) — the provenance registry is the single source of what produces
// a durable result: every result_kind the envelope table accepts has a
// `provenance_modules()` entry, and every entry names a kind the table
// accepts. Both lists are read from the LAST migration that defines them, so
// a migration that adds a kind must change the two together, and the writer
// (`record_provenance`) cannot meet a kind the registry does not know.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

List<File> _migrations() =>
    sqlFiles('supabase/migrations')..sort((a, b) => a.path.compareTo(b.path));

String _lastDefining(Pattern marker) => _migrations()
    .map((f) => f.readAsStringSync())
    .lastWhere((text) => text.contains(marker));

void main() {
  test('the result kinds of the table and the registry are the same set', () {
    final table = RegExp(
      r"result_kind in \(([^)]*)\)",
      caseSensitive: false,
    ).firstMatch(_lastDefining('result_kind in ('))!.group(1)!;
    final kinds = {
      for (final m in RegExp(r"'([a-z_]+)'").allMatches(table)) m.group(1)!,
    };
    final registry = _lastDefining('function public.provenance_modules()');
    final body = registry.substring(
      registry.indexOf('function public.provenance_modules()'),
    );
    final end = body.indexOf(r'$fn$;', body.indexOf(r'$fn$') + 4);
    final entries = {
      for (final m in RegExp(
        r"'([a-z_]+)',\s+jsonb_build_object\('module_id'",
      ).allMatches(body.substring(0, end)))
        m.group(1)!,
    };
    expect(kinds, isNotEmpty);
    expect(
      entries,
      kinds,
      reason:
          'every result kind needs a provenance_modules() entry and '
          'every entry a kind: change the table check and the registry together',
    );
  });
}
