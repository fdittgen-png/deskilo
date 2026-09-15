// SPDX-License-Identifier: 0BSD
//
// #1334 — every test, classified by rules a reviewer can read.
//
// The triage asks, for each test file: which layer, which invariant,
// deterministic or not, what it depends on, what its failure is worth,
// whether it duplicates another, and what to do with it. Asking that by
// hand of 450 files once produces a document that is wrong the week
// after. So the classification is a function of the file — the header
// that states its invariant, the assertions it makes, what it reads —
// and the rules live here, where changing one re-classifies every file
// at once and shows up in review.
//
// Pure dart:io: `dart run tool/test_inventory.dart` needs no Flutter.

import 'dart:io';

/// One classified test file.
class TestFileEntry {
  TestFileEntry({
    required this.path,
    required this.layer,
    required this.invariant,
    required this.tests,
    required this.deterministic,
    required this.dependency,
    required this.failureValue,
    required this.duplicate,
    required this.action,
    required this.replacement,
  });

  final String path;
  final String layer;
  final String invariant;
  final int tests;
  final String deterministic;
  final String dependency;
  final String failureValue;
  final String duplicate;
  final String action;
  final String replacement;
}

/// Actions the triage allows (#1334).
const actions = [
  'KEEP',
  'KEEP+REFACTOR',
  'REPLACE',
  'DELETE',
  'MOVE TO INTEGRATION/DB/HEALTH SUITE',
  'ADD',
];

/// Widget-structure assertions per file above which a file is flagged:
/// exact widget counts and reads of a widget's own fields. Below it they
/// are usually the invariant itself (a switch's value, a key's presence).
const structureCouplingThreshold = 8;

/// A file whose widget structure IS its invariant says so, with a reason,
/// in a comment containing this marker — and is not flagged for it.
const structureMarker = 'test-inventory: structure is the invariant';

final _testCall = RegExp(r'\b(?:testWidgets|test)\(');
final _testName = RegExp(r"""\b(?:testWidgets|test)\(\s*(['"])(.+?)\1""");
final _issueRef = RegExp(r'#(\d{3,4})\b');
final _plan = RegExp(r'plan\((\d+)\)');
final _repoRead = RegExp(
    r"""(?:File|Directory)\(\s*['"](?:lib|supabase|docs|web|assets|tool|test|\.github|android|ios|pubspec)""");

/// Every test file: Dart tests under `test/`, pgTAP files under
/// `supabase/tests/database/`, sorted by path.
List<File> testFiles({String root = '.'}) {
  final dart = Directory('$root/test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_test.dart'));
  final sqlDir = Directory('$root/supabase/tests/database');
  final sql = sqlDir.existsSync()
      ? sqlDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))
      : const <File>[];
  final all = [...dart, ...sql]
    ..sort((a, b) => _relative(a.path, root).compareTo(_relative(b.path, root)));
  return all;
}

String _relative(String path, String root) {
  final prefix = root.endsWith('/') ? root : '$root/';
  final p = path.startsWith(prefix) ? path.substring(prefix.length) : path;
  return p.startsWith('./') ? p.substring(2) : p;
}

/// The first paragraph of the file's header comment, after the licence
/// line: the invariant the file says it protects.
String statedInvariant(String source, {required bool sql}) {
  final marker = sql ? '--' : '//';
  final paragraph = <String>[];
  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (!line.startsWith(marker)) {
      if (paragraph.isNotEmpty || line.isNotEmpty) break;
      continue;
    }
    final text = line.substring(marker.length).trim();
    if (text.startsWith('SPDX-License-Identifier')) continue;
    if (text.isEmpty) {
      if (paragraph.isNotEmpty) break;
      continue;
    }
    paragraph.add(text);
  }
  final joined = paragraph.join(' ');
  if (joined.length <= 160) return joined;
  final cut = joined.substring(0, 160);
  final space = cut.lastIndexOf(' ');
  return '${space > 100 ? cut.substring(0, space) : cut}…';
}

String _layerOf(String path, String source) {
  if (path.startsWith('supabase/')) return 'database';
  final second = path.split('/')[1];
  const named = {
    'lint': 'lint',
    'a11y': 'a11y',
    'i18n': 'i18n',
    'perf': 'perf',
    'property': 'property',
    'ux': 'journey',
    'tool': 'tool',
  };
  if (named.containsKey(second)) return named[second]!;
  return source.contains('testWidgets(') ? 'widget' : 'unit';
}

/// Classifies every test file under [root].
List<TestFileEntry> classify({String root = '.'}) {
  final files = testFiles(root: root);
  final sources = {
    for (final f in files) _relative(f.path, root): f.readAsStringSync(),
  };

  // Test names shared between files: a duplicate candidate, never an
  // automatic deletion — two screens with the same empty state are two
  // regressions, and the triage forbids deleting on similarity alone.
  final owners = <String, Set<String>>{};
  sources.forEach((path, source) {
    if (path.endsWith('.sql')) return;
    for (final m in _testName.allMatches(source)) {
      final name = m.group(2)!;
      if (name.contains(r'$')) continue;
      (owners[name] ??= <String>{}).add(path);
    }
  });

  final entries = <TestFileEntry>[];
  for (final MapEntry(key: path, value: source) in sources.entries) {
    final sql = path.endsWith('.sql');
    final layer = _layerOf(path, source);
    final invariant = statedInvariant(source, sql: sql);
    final tests = sql
        ? int.tryParse(_plan.firstMatch(source)?.group(1) ?? '') ?? 0
        : _testCall.allMatches(source).length;

    final deps = <String>[];
    if (sql) deps.add('local Supabase (pgTAP)');
    if (source.contains('mock_providers.dart') || source.contains('/fake_')) {
      deps.add('fakes');
    }
    if (source.contains('setMockMethodCallHandler')) {
      deps.add('platform channel (mocked)');
    }
    if (_repoRead.hasMatch(source)) deps.add('repository sources');
    if (source.contains('Directory.systemTemp')) deps.add('temp filesystem');
    if (source.contains('runAsync')) deps.add('real async I/O');

    final nondeterminism = <String>[
      if (source.contains('DateTime.now()') && layer != 'lint')
        'real clock (exempt-listed)',
      if (RegExp(r'\bRandom\(\)').hasMatch(source)) 'unseeded Random',
      if (RegExp(r'Future(?:<\w+>)?\.delayed\(\s*(?:const\s+)?Duration\((?!\))')
          .hasMatch(source))
        'real delay',
    ];

    final refs = {
      for (final m in _issueRef.allMatches(source)) '#${m.group(1)}',
    }.take(3).toList();
    final guards = switch (layer) {
      'database' => 'a data-layer regression (RLS, invariant, idempotency)',
      'lint' => 'an architecture, security or process rule',
      'a11y' => 'an accessibility contract',
      'i18n' => 'a localisation contract',
      'journey' => 'a user journey budget',
      'perf' || 'property' => 'a performance or property contract',
      'tool' => 'a repository tool',
      'widget' => 'user-visible behaviour',
      _ => 'a domain rule',
    };
    final failureValue =
        refs.isEmpty ? guards : '$guards — ${refs.join(', ')}';

    final shared = <String>{};
    if (!sql) {
      for (final m in _testName.allMatches(source)) {
        final others = owners[m.group(2)!];
        if (others != null && others.length > 1) {
          shared.addAll(others.where((o) => o != path));
        }
      }
    }

    final coupling = RegExp(r'findsNWidgets\(').allMatches(source).length +
        RegExp(r'tester\.widget(?:List)?<').allMatches(source).length;
    final semantics = RegExp(
            r'bySemanticsLabel|getSemantics|ensureSemantics|SemanticsHandle')
        .hasMatch(source);

    var action = 'KEEP';
    var replacement = '';
    if (invariant.isEmpty) {
      action = 'KEEP+REFACTOR';
      replacement = 'state the invariant in the header comment';
    } else if ((layer == 'widget' || layer == 'unit') &&
        coupling >= structureCouplingThreshold &&
        !semantics &&
        !source.contains(structureMarker)) {
      action = 'KEEP+REFACTOR';
      replacement =
          'assert observable state or semantics where the $coupling structure reads are not the invariant';
    }
    if (nondeterminism.contains('unseeded Random') ||
        nondeterminism.contains('real delay')) {
      action = 'KEEP+REFACTOR';
      replacement = 'drive time and randomness through a seam';
    }

    entries.add(TestFileEntry(
      path: path,
      layer: layer,
      invariant: invariant.isEmpty ? '(not stated)' : invariant,
      tests: tests,
      deterministic:
          nondeterminism.isEmpty ? 'yes' : 'no — ${nondeterminism.join(', ')}',
      dependency: deps.isEmpty ? 'none' : deps.join(', '),
      failureValue: failureValue,
      duplicate: shared.isEmpty
          ? 'no'
          : 'shares a test name with ${(shared.toList()..sort()).join(', ')}',
      action: action,
      replacement: replacement,
    ));
  }
  return entries;
}

/// Coverage #1334 found missing, and the issue that owns each gap. Kept
/// here so the inventory states what is NOT yet a test next to what is.
const missingCoverage = <(String, String, String)>[
  ('Database executes as a CI gate', '#1335', 'pgTAP gate, write isolation (PR for #1335)'),
  ('Role matrix on row policies', '#1321', '13_matrix_policies.sql (PR for #1321)'),
  ('Server feature gates follow requires', '#1332', '14_feature_gates.sql TODO proofs; green with the #1332 fix'),
  ('Process registry, resolver, preview == apply', '#1336', 'blocked on #1325, #1326, #1329'),
  ('Template merge, idempotency, allow-list, provenance', '#1338', 'blocked on #1276'),
  ('Number sequences: invalid pairs, no reuse', '#1338 / #1320', 'lands with the #1320 fix'),
  ('Export completeness and restore drill', '#1338 / #1310', 'lands with #1310'),
  ('Instance install, resume, doctor isolation', '#1337 / #1314', 'lands with #1314; schema marker with #1312'),
  ('Journeys: decision without the bell, onboarding retry', '#1339', 'with #1306 and #1303'),
  ('State model: stale, offline, empty, error', '#1339 / #1305', 'with #1305'),
];

String _cell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// The inventory as markdown.
String render(List<TestFileEntry> entries) {
  final b = StringBuffer()
    ..writeln('<!-- GENERATED by `dart run tool/test_inventory.dart` — do not edit by hand. -->')
    ..writeln()
    ..writeln('# Test inventory')
    ..writeln()
    ..writeln('Every test file, classified for reliability and regression value (#1334). '
        'The classification is a function of each file — its header, its assertions, '
        'what it reads — so the rules below are the review surface, not the rows.')
    ..writeln();

  final files = entries.length;
  final tests = entries.fold<int>(0, (n, e) => n + e.tests);
  b
    ..writeln('**$files files, $tests tests.**')
    ..writeln()
    ..writeln('| layer | files | tests |')
    ..writeln('|---|---:|---:|');
  final layers = <String, (int, int)>{};
  for (final e in entries) {
    final (f, t) = layers[e.layer] ?? (0, 0);
    layers[e.layer] = (f + 1, t + e.tests);
  }
  for (final l in (layers.keys.toList()..sort())) {
    b.writeln('| $l | ${layers[l]!.$1} | ${layers[l]!.$2} |');
  }
  b
    ..writeln()
    ..writeln('| action | files |')
    ..writeln('|---|---:|');
  for (final a in actions) {
    final n = entries.where((e) => e.action == a).length;
    if (n > 0) b.writeln('| $a | $n |');
  }

  b
    ..writeln()
    ..writeln('## Rules')
    ..writeln()
    ..writeln('- **Layer** — `supabase/tests/database` is `database`; `test/lint`, `a11y`, `i18n`, `perf`, `property`, `ux` (journey) and `tool` are named by folder; otherwise `widget` when the file pumps widgets, `unit` when it does not.')
    ..writeln('- **Invariant** — the first paragraph of the header comment. A file that states none is `KEEP+REFACTOR`: a test whose purpose must be reverse-engineered cannot be judged, kept or safely deleted.')
    ..writeln('- **Deterministic** — no unless the file reads the real clock (only the files `test/lint/no_wall_clock_test.dart` exempts, each for a stated reason), uses an unseeded `Random()`, or waits a real non-zero delay. The last two are `KEEP+REFACTOR`.')
    ..writeln('- **Dependency** — fakes (`mock_providers`, `fake_*`), mocked platform channels, repository sources read from disk, a temporary filesystem, real async I/O (`runAsync`), or the local Supabase stack.')
    ..writeln('- **Failure value** — what a failure blocks, by layer, with the issues the file cites.')
    ..writeln('- **Duplicate** — a test name shared with another file. A candidate for review, never a deletion by itself: the triage forbids deleting a test unless a demonstrably stronger one covers it.')
    ..writeln('- **Structure coupling** — `findsNWidgets` and `tester.widget<…>` reads. A `widget`/`unit` file with $structureCouplingThreshold or more and no semantics assertion is `KEEP+REFACTOR`: assert what the user can observe unless the structure is itself the invariant — which the file then states with a `// $structureMarker — <reason>` comment.')
    ..writeln('- **DELETE / REPLACE / MOVE** are never assigned by rule. They need a named stronger test, recorded in the replacement column by the pull request that makes the change.')
    ..writeln()
    ..writeln('## Coverage still to add')
    ..writeln()
    ..writeln('| gap | issue | status |')
    ..writeln('|---|---|---|');
  for (final (gap, issue, status) in missingCoverage) {
    b.writeln('| ${_cell(gap)} | $issue | ${_cell(status)} |');
  }

  b
    ..writeln()
    ..writeln('## Files')
    ..writeln()
    ..writeln('| test/file | layer | invariant | tests | deterministic? | integration dependency | failure value | duplicate? | action | replacement |')
    ..writeln('|---|---|---|---:|---|---|---|---|---|---|');
  for (final e in entries) {
    b.writeln('| `${e.path}` | ${e.layer} | ${_cell(e.invariant)} | ${e.tests} | '
        '${_cell(e.deterministic)} | ${_cell(e.dependency)} | ${_cell(e.failureValue)} | '
        '${_cell(e.duplicate)} | ${e.action} | ${_cell(e.replacement)} |');
  }
  return b.toString();
}

/// Where the inventory is written.
const inventoryPath = 'docs/testing/TEST_INVENTORY.md';
