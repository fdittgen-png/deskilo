// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3495 — four review findings that recurred on #3464–#3491, as checks:
//
//  (a) a held code-health function or file budget may not GROW against the
//      merge base unless `code_health_growth_markers.txt` names it with a reason;
//  (b) a path removed from the country-literals checklist must no longer exist;
//  (c) `test/parity/**` declares no country sets or country rules of its own;
//  (d) the lines of a checklist file that compare a country code are covered
//      by `test/parity` (needs a coverage report, so it reads
//      `coverage/lcov.info` when the run produced one).
//
// Each rule is a pure function with a fixture of the defect it guards.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

// ---------------------------------------------------------------- (a) growth

/// Held metrics that grew from [before] to [after]: `id: cog 3 -> 5`.
List<String> baselineGrowth(String before, String after) {
  final a = jsonDecode(before) as Map<String, Object?>;
  final b = jsonDecode(after) as Map<String, Object?>;
  final grew = <String>[];
  Map<String, Map<String, Object?>> fns(Map<String, Object?> j) => {
    for (final e
        in ((j['functions'] ?? const []) as List).cast<Map<String, Object?>>())
      e['id']! as String: e,
  };
  final old = fns(a);
  fns(b).forEach((id, now) {
    final was = old[id];
    if (was == null) return;
    for (final k in const ['cog', 'cyc', 'len', 'params']) {
      if ((now[k]! as int) > (was[k]! as int)) {
        grew.add('$id: $k ${was[k]} -> ${now[k]}');
      }
    }
  });
  Map<String, Object?> lengths(Map<String, Object?> j) =>
      (((j['budgets'] ?? const <String, Object?>{}) as Map)['fileLength'] ??
              const <String, Object?>{})
          as Map<String, Object?>;
  final oldLen = lengths(a);
  lengths(b).forEach((path, now) {
    final was = oldLen[path];
    if (was is int && (now! as int) > was) {
      grew.add('$path: file length $was -> $now');
    }
  });
  return grew;
}

/// The ids named in `code_health_growth_markers.txt` (`<id> :: <reason>`).
Map<String, String> growthMarkers(String text) => {
  for (final l in text.split('\n'))
    if (l.trim().isNotEmpty && !l.startsWith('#') && l.contains(' :: '))
      l.split(' :: ').first.trim(): l.split(' :: ').skip(1).join(' :: ').trim(),
};

// -------------------------------------------------------------- (b) checklist

final _quoted = RegExp(r"'((?:lib|packages)/[^']+\.dart)'");

Set<String> checklistPaths(String testSource) {
  final at = testSource.indexOf('const _checklistFiles');
  if (at < 0) return {};
  final end = testSource.indexOf('};', at);
  return {
    for (final m in _quoted.allMatches(testSource.substring(at, end))) m[1]!,
  };
}

/// Paths in [before] but not [after] that still exist per [exists].
List<String> removedButPresent(
  Set<String> before,
  Set<String> after,
  bool Function(String) exists,
) => [
  for (final p in before.difference(after))
    if (exists(p)) p,
];

// ------------------------------------------------------------------ (c) parity

final _countrySetLiteral = RegExp(
  r"[\{\[]\s*'[A-Z]{2}'\s*(,\s*'[A-Z]{2}'\s*)+,?\s*[\}\]]",
);
final _countryNamedArg = RegExp(r'\b\w*[Cc]ountries\s*:\s*(const\s*)?[\{\[]');

/// The line without its `//` comment.
String _code(String line) => line.split('//').first;

/// Country sets or country rules a parity test declares itself.
List<String> parityCountryDeclarations(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_countrySetLiteral.hasMatch(_code(lines[i])) ||
          _countryNamedArg.hasMatch(_code(lines[i])))
        '${i + 1}: ${lines[i].trim()}',
  ];
}

/// Parity files that iterate or classify a few fixture countries; each is
/// reviewed, and the list only shrinks (rules come from the add-ons).
const _parityAllowed = <String, String>{
  'test/parity/export_registry_parity_test.dart':
      'iterates the two countries whose export it compares',
  'test/parity/retention_extension_parity_test.dart':
      'iterates the four countries whose retention it pins',
  'test/parity/records_location_parity_test.dart':
      'EU membership of the two fixture countries, not an installed rule',
};

// ------------------------------------------------------------------ (d) coverage

/// Lines of [source] comparing a country code (a string literal that is two
/// capitals), 1-based.
List<int> countryCompareLines(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (!lines[i].trimLeft().startsWith('//') &&
          RegExp(
            r"""[=!]=\s*'[A-Z]{2}'|'[A-Z]{2}'\s*[=!]=|case\s+'[A-Z]{2}'|contains\(\s*'[A-Z]{2}'""",
          ).hasMatch(lines[i]))
        i + 1,
  ];
}

/// Instrumented-and-hit lines per file of an lcov report.
Map<String, Set<int>> lcovHits(String lcov) {
  final out = <String, Set<int>>{};
  String? file;
  for (final l in lcov.split('\n')) {
    if (l.startsWith('SF:')) {
      file = l.substring(3);
    } else if (l.startsWith('DA:') && file != null) {
      final p = l.substring(3).split(',');
      if (int.parse(p[1]) > 0) {
        out.putIfAbsent(file, () => {}).add(int.parse(p[0]));
      }
    }
  }
  return out;
}

/// Country-comparing lines of [source] that [hit] does not cover.
List<int> uncoveredCountryLines(String source, Set<int> hit) => [
  for (final n in countryCompareLines(source))
    if (!hit.contains(n)) n,
];

String? _git(List<String> args) {
  try {
    final r = Process.runSync('git', args);
    return r.exitCode == 0 ? r.stdout as String : null;
  } on ProcessException {
    return null;
  }
}

String? _mergeBase() {
  for (final ref in const ['origin/master', 'master']) {
    final mb = _git(['merge-base', 'HEAD', ref]);
    if (mb != null && mb.trim().isNotEmpty) return mb.trim();
  }
  return null;
}

void main() {
  group('(a) held code-health growth', () {
    const base =
        '{"functions":[{"id":"f","cog":10,"cyc":5,"len":50,"params":3}],'
        '"budgets":{"fileLength":{"lib/a.dart":600}}}';
    test('fixture: a grown metric or budget is reported, a fall is not', () {
      expect(
        baselineGrowth(
          base,
          '{"functions":[{"id":"f","cog":11,"cyc":4,"len":50,"params":3}],'
          '"budgets":{"fileLength":{"lib/a.dart":650}}}',
        ),
        ['f: cog 10 -> 11', 'lib/a.dart: file length 600 -> 650'],
      );
      expect(
        baselineGrowth(
          base,
          '{"functions":[{"id":"f","cog":9,"cyc":5,"len":40,"params":3}],'
          '"budgets":{"fileLength":{"lib/a.dart":590}}}',
        ),
        isEmpty,
      );
    });
    test('the tree grows nothing against the merge base without a marker', () {
      final mb = _mergeBase();
      final old = mb == null
          ? null
          : _git(['show', '$mb:docs/design/CODE_HEALTH_BASELINE.json']);
      if (old == null) return; // no merge base here (shallow clone): CI's full-history job runs it
      final grew = baselineGrowth(
        old,
        File('docs/design/CODE_HEALTH_BASELINE.json').readAsStringSync(),
      );
      final markers = growthMarkers(
        File('test/lint/code_health_growth_markers.txt').readAsStringSync(),
      );
      expect(
        [
          for (final g in grew)
            if (!markers.containsKey(g.split(': ').first) ||
                markers[g.split(': ').first]!.length < 15)
              g,
        ],
        isEmpty,
        reason:
            'a held function or file may only fall; a deliberate growth is named '
            'in test/lint/code_health_growth_markers.txt as `<id> :: <reason>`',
      );
    });
  });

  group('(b) a removed checklist path is gone', () {
    test('fixture: a removed path that still exists is reported', () {
      expect(
        removedButPresent(
          {'lib/a.dart', 'lib/b.dart'},
          {'lib/a.dart'},
          (p) => p == 'lib/b.dart',
        ),
        ['lib/b.dart'],
      );
      expect(
        removedButPresent({'lib/a.dart'}, {'lib/a.dart'}, (_) => true),
        isEmpty,
      );
      expect(
        checklistPaths(
          "const _checklistFiles = <String>{\n  'lib/a.dart',\n  'packages/p/lib/b.dart',\n};",
        ),
        {'lib/a.dart', 'packages/p/lib/b.dart'},
      );
    });
    test('the tree: no path left the checklist while its file lives on', () {
      final mb = _mergeBase();
      final old = mb == null
          ? null
          : _git(['show', '$mb:test/lint/country_literals_test.dart']);
      if (old == null) return;
      final now = checklistPaths(
        File('test/lint/country_literals_test.dart').readAsStringSync(),
      );
      expect(
        removedButPresent(
          checklistPaths(old),
          now,
          (p) => File(p).existsSync(),
        ),
        isEmpty,
        reason:
            'a file that leaves the checklist because it is rewritten stays on it; '
            'only a deleted file leaves',
      );
    });
  });

  group('(c) parity tests declare no country sets or rules', () {
    test(
      'fixture: a country set literal and a named country rule are found',
      () {
        expect(
          parityCountryDeclarations(
            "final r = PaymentReferenceRules(accountCountries: {'DE', 'FR'});",
          ),
          isNotEmpty,
        );
        expect(
          parityCountryDeclarations(
            "bool _eu(String c) => const {'DE', 'FR'}.contains(c);",
          ),
          isNotEmpty,
        );
        expect(
          parityCountryDeclarations(
            "final c = installed.countries.first; // {'DE', 'FR'}",
          ),
          isEmpty,
        );
      },
    );
    test('the parity tests: only the reviewed ones, and each still needs its entry', () {
      final found = <String, int>{};
      for (final f in handWrittenDartFiles('test/parity')) {
        final n = parityCountryDeclarations(f.readAsStringSync()).length;
        if (n > 0) {
          found[f.path.replaceFirst(RegExp(r'^.*?(?=test/parity/)'), '')] = n;
        }
      }
      expect(
        [
          for (final p in found.keys)
            if (!_parityAllowed.containsKey(p)) p,
        ],
        isEmpty,
        reason: 'take the rule from the installed add-ons instead of declaring a country set',
      );
      expect(
        [
          for (final p in _parityAllowed.keys)
            if (!found.containsKey(p)) p,
        ],
        isEmpty,
        reason:
            'the declaration is gone: drop the entry so the list only shrinks',
      );
    });
  });

  group('(d) country comparisons of checklist files are covered by the parity tests', () {
    test('fixture: an uncovered comparison line is reported', () {
      const src =
          "bool f(String c) {\n  if (c == 'DE') return true;\n  return c != 'FR';\n}\n";
      expect(countryCompareLines(src), [2, 3]);
      expect(uncoveredCountryLines(src, {2}), [3]);
      expect(lcovHits('SF:lib/a.dart\nDA:2,1\nDA:3,0\nend_of_record\n'), {
        'lib/a.dart': {2},
      });
    });
    test('the report, when the run produced one', () {
      final report = File('coverage/lcov.info');
      if (!report.existsSync()) {
        return; // produced by CI's coverage shard, not a plain lint run
      }
      final hits = lcovHits(report.readAsStringSync());
      final paths = checklistPaths(
        File('test/lint/country_literals_test.dart').readAsStringSync(),
      );
      final gaps = <String>[];
      for (final p in paths) {
        final f = File(p);
        if (!f.existsSync() || !hits.containsKey(p)) continue;
        final miss = uncoveredCountryLines(f.readAsStringSync(), hits[p]!);
        if (miss.isNotEmpty) gaps.add('$p: ${miss.join(', ')}');
      }
      expect(
        gaps,
        isEmpty,
        reason: 'a checklist file\'s country comparison needs a parity case',
      );
    });
  });
}
