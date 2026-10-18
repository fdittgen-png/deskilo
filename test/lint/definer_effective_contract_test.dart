// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2588 C2 -- the text scan and the effective contract agree on which
// elevated functions a signed-in person can call.
//
// `definer_scan.dart` reads migration text: it follows grants and revokes it
// can see, and a heuristic never sees everything (a revoke written another way,
// a function created by `execute`, a grant to a role through a default). The
// effective contract (`assets/instance/contract.txt`) is written from the
// replayed database, with each routine's kind, its security (`definer`) and who
// may execute it. So the property is checked against the database's own answer:
//
//  - every SECURITY DEFINER, non-trigger routine the contract shows executable
//    by `authenticated` is one the scan SEES as exposed -- otherwise it checks
//    nothing about that routine, and the lint is silent about the very function
//    that is callable;
//  - and therefore either guarded, or listed in definer_unreviewed.txt;
//  - the few the scan cannot see (functions rebuilt by a patch from their live
//    definition) are read and listed in definer_effective_gap.txt, which only
//    shrinks.
//
// The reverse (the scan thinks a function is exposed and the database says it
// is not) is harmless -- it only means a revoke the text scan cannot follow --
// and is not asserted.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'definer_scan.dart';
import 'lint_sources.dart';

/// `name/parameter count` of the definer routines [contract] shows executable
/// by authenticated, triggers excluded.
List<String> effectiveExposedDefiners(String contract) {
  final line = RegExp(
    r'^routine public\.(\w+)\((.*?)\) -> (.*?) \| function \| definer \| \w+ \| exec:([\w,]*) \|',
  );
  final out = <String>[];
  for (final raw in contract.split('\n')) {
    final m = line.firstMatch(raw);
    if (m == null) continue;
    if (!m.group(4)!.split(',').contains('authenticated')) continue;
    if (m.group(3)!.trim() == 'trigger') continue;
    final params = m.group(2)!.trim();
    out.add('${m.group(1)}/${params.isEmpty ? 0 : _topLevelCommas(params) + 1}');
  }
  return out..sort();
}

int _topLevelCommas(String params) {
  var depth = 0;
  var commas = 0;
  for (final c in params.split('')) {
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == ',' && depth == 0) commas++;
  }
  return commas;
}

void main() {
  final contract = File('assets/instance/contract.txt').readAsStringSync();
  final effective = effectiveExposedDefiners(contract);
  final scanned = scannedExposedDefiners(
    repositoryMigrations(sqlFiles('supabase/migrations')),
  ).toSet();

  test('the contract has definer routines to compare (the parser sees them)', () {
    expect(effective.length, greaterThan(300));
    expect(scanned.length, greaterThan(300));
  });

  final reviewed = {
    for (final line in File('test/lint/definer_effective_gap.txt').readAsLinesSync())
      if (line.trim().isNotEmpty && !line.startsWith('#'))
        line.split('|').first.trim(): line.split('|').last.trim(),
  };

  test('every definer routine the database exposes is one the scan sees, or is read and listed', () {
    final blind = [
      for (final key in effective)
        if (!scanned.contains(key) && !reviewed.containsKey(key)) key,
    ];
    expect(
      blind,
      isEmpty,
      reason:
          'the contract shows these SECURITY DEFINER routines executable by '
          'authenticated, and the text scan does not see them as exposed, so '
          'definer_caller_guard_test says nothing about them: read each, then '
          'revoke it or make the scan follow how it is granted:\n'
          '${blind.join('\n')}',
    );
  });

  test('the gap list only shrinks: every entry is still exposed and still unseen', () {
    final stale = [
      for (final key in reviewed.keys)
        if (!effective.contains(key) || scanned.contains(key)) key,
    ];
    expect(stale, isEmpty, reason: 'delete the line: ${stale.join(', ')}');
    expect(reviewed.values.every((v) => v.startsWith('reviewed:')), isTrue);
  });

  test('the parser reads one line, with its parameters counted at top level', () {
    const sample = '''
routine public.f(p_a uuid, p_b numeric(10,2)) -> jsonb | function | definer | volatile | exec:authenticated,service_role | body:abc
routine public.g() -> void | function | definer | volatile | exec:authenticated | body:abc
routine public.h(p_a uuid) -> trigger | function | definer | volatile | exec:authenticated | body:abc
routine public.i(p_a uuid) -> int | function | invoker | volatile | exec:authenticated | body:abc
routine public.j(p_a uuid) -> int | function | definer | volatile | exec:service_role | body:abc
''';
    expect(effectiveExposedDefiners(sample), ['f/2', 'g/0']);
  });
}
