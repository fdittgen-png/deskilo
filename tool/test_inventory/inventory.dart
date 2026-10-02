// SPDX-License-Identifier: AGPL-3.0-or-later
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

import '../layering/analysis.dart' show withoutComments;

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
    this.runner = 'root suite',
    this.execution = '',
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

  /// #1864 — which runner family holds the file, and who executes it
  /// (with the condition when it only runs on demand).
  final String runner;
  final String execution;
}

/// Actions the triage allows (#1334).
const actions = [
  // #1864 — what a file is until a person has reviewed it. KEEP is a
  // reviewed decision (reviewedDispositions), never a rule's default.
  'UNREVIEWED',
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

/// #1864 — every place a test runner looks, and who runs it.
///
/// A family is registered here with its execution owner: the workflow
/// that runs it and the command it must contain, or the honest note
/// that nothing runs it automatically. A test file found outside every
/// family, or a family whose workflow no longer runs it, fails
/// test_inventory_test.
class RunnerFamily {
  const RunnerFamily({
    required this.name,
    required this.root,
    required this.suffix,
    required this.owner,
    this.workflow,
    this.command,
    this.layer,
    this.recursive = true,
  });

  final String name;
  final String root;
  final String suffix;
  final String owner;

  /// `.github/workflows/<workflow>` must contain [command].
  final String? workflow;
  final String? command;

  /// Fixed layer for the family; null classifies by folder and content.
  final String? layer;
  final bool recursive;
}

const runnerFamilies = <RunnerFamily>[
  RunnerFamily(
    name: 'root suite',
    root: 'test',
    suffix: '_test.dart',
    owner: 'quality.yml: flutter test, once, with coverage and the report stream',
    workflow: 'quality.yml',
    command: 'flutter test --coverage',
  ),
  RunnerFamily(
    name: 'pgTAP',
    root: 'supabase/tests/database',
    suffix: '.sql',
    recursive: false,
    owner: 'quality.yml: quality · database (supabase test db)',
    workflow: 'quality.yml',
    command: 'supabase test db',
    layer: 'database',
  ),
  RunnerFamily(
    name: 'push package (Google)',
    root: 'packages/deskilo_push/test',
    suffix: '_test.dart',
    owner: 'quality.yml: flutter test in packages/deskilo_push',
    workflow: 'quality.yml',
    command: 'working-directory: packages/deskilo_push',
    layer: 'package',
  ),
  RunnerFamily(
    name: 'Edge functions',
    root: 'supabase/functions',
    suffix: '_test.ts',
    owner: 'edge-functions.yml: deno test',
    workflow: 'edge-functions.yml',
    command: 'deno test',
    layer: 'edge',
  ),
  RunnerFamily(
    name: 'benchmarks',
    root: 'tool/bench',
    suffix: '_test.dart',
    owner: 'perf-bench.yml: flutter test tool/bench',
    workflow: 'perf-bench.yml',
    command: 'flutter test tool/bench',
    layer: 'perf',
  ),
  RunnerFamily(
    name: 'device integration',
    root: 'integration_test',
    suffix: '_test.dart',
    owner: 'no CI runner: on a device, flutter test integration_test -d <device>',
    layer: 'integration',
  ),
  RunnerFamily(
    name: 'store assets',
    root: 'tool/store_assets',
    suffix: '_test.dart',
    owner: 'no CI runner: by hand when the store graphics change',
    layer: 'tool',
  ),
];

/// Directories a runner never reads.
final _ignored = RegExp(
    r'(^|/)(\.dart_tool|\.git|build|node_modules|Pods|\.gradle|\.agent-work|\.symlinks)(/|$)');

List<File> _filesOf(RunnerFamily f, String root) {
  final dir = Directory('$root/${f.root}');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: f.recursive)
      .whereType<File>()
      .where((x) => x.path.endsWith(f.suffix))
      .where((x) => !_ignored.hasMatch(_relative(x.path, root)))
      .toList();
}

/// The family that owns [path] (repository-relative).
RunnerFamily? familyOf(String path) {
  for (final f in runnerFamilies) {
    if (!path.startsWith('${f.root}/') || !path.endsWith(f.suffix)) continue;
    if (!f.recursive && path.substring(f.root.length + 1).contains('/')) {
      continue;
    }
    return f;
  }
  return null;
}

/// Every test file of every registered runner family, sorted by path.
List<File> testFiles({String root = '.'}) {
  final all = [for (final f in runnerFamilies) ..._filesOf(f, root)]
    ..sort((a, b) => _relative(a.path, root).compareTo(_relative(b.path, root)));
  return all;
}

/// Test-shaped files no registered family covers: a runner nobody
/// listed, or a file put where no runner looks.
List<String> unregisteredTestFiles({String root = '.'}) {
  final out = <String>[];
  for (final e in Directory(root).listSync(recursive: true, followLinks: false)) {
    if (e is! File) continue;
    final path = _relative(e.path, root);
    if (_ignored.hasMatch(path)) continue;
    final shaped = path.endsWith('_test.dart') ||
        path.endsWith('_test.ts') ||
        (path.startsWith('supabase/tests/') && path.endsWith('.sql'));
    if (shaped && familyOf(path) == null) out.add(path);
  }
  return out..sort();
}

/// Registered families that hold no file, or whose workflow no longer
/// contains the command that runs them.
List<String> deadRunnerEntries({String root = '.'}) {
  final out = <String>[];
  for (final f in runnerFamilies) {
    if (_filesOf(f, root).isEmpty) out.add('${f.name}: no files under ${f.root}');
    if (f.workflow == null) continue;
    final wf = File('$root/.github/workflows/${f.workflow}');
    if (!wf.existsSync()) {
      out.add('${f.name}: ${f.workflow} does not exist');
    } else if (!wf.readAsStringSync().contains(f.command!)) {
      out.add('${f.name}: ${f.workflow} no longer runs "${f.command}"');
    }
  }
  return out;
}

/// A reviewed decision about one file (#1864): what to do with it, why,
/// and — for a removal or replacement — the surviving test.
typedef Disposition = ({String action, String reason, String? survivor});

/// Decisions a person made. Everything else is UNREVIEWED.
const Map<String, Disposition> reviewedDispositions = {
  'test/core/instance/local_recovery_test.dart': (
    action: 'KEEP',
    reason: 'the only real disposable Auth/HTTP/Storage recovery proof; '
        'skipped by a plain run on purpose, executed by '
        'scripts/restore_check.sh --application',
    survivor: null,
  ),
};

/// What is wrong with [dispositions] against the files that exist: an
/// unknown file, a survivor that does not exist, a replacement chain
/// that returns to where it started.
List<String> dispositionProblems(
  Map<String, Disposition> dispositions,
  Set<String> files,
) {
  final out = <String>[];
  for (final MapEntry(key: path, value: d) in dispositions.entries) {
    if (!files.contains(path)) out.add('$path: no such test file');
    if (!actions.contains(d.action)) out.add('$path: unknown action ${d.action}');
    if (d.reason.trim().isEmpty) out.add('$path: no reason');
    final needsSurvivor = d.action == 'DELETE' || d.action == 'REPLACE';
    if (needsSurvivor && d.survivor == null) {
      out.add('$path: ${d.action} names no survivor');
    }
    if (d.survivor != null && !files.contains(d.survivor)) {
      out.add('$path: survivor ${d.survivor} does not exist');
    }
    final seen = {path};
    var next = d.survivor;
    while (next != null) {
      if (!seen.add(next)) {
        out.add('$path: replacement cycle through $next');
        break;
      }
      next = dispositions[next]?.survivor;
    }
  }
  return out;
}

/// Who executes [path] and under which condition (#1864): a test that
/// skips unless an environment variable is set is integration evidence
/// only where something sets it.
String _execution(String path, String source, RunnerFamily family, String root) {
  final env = {
    for (final m in RegExp(r"""Platform\.environment\[\s*'(\w+)'""").allMatches(source))
      m.group(1)!,
  };
  final constEnv = RegExp(r"""const\s+\w+\s*=\s*'(DESKILO_\w+)'""").firstMatch(source);
  if (constEnv != null) env.add(constEnv.group(1)!);
  final gated = source.contains('skip:') && env.any((e) => e.startsWith('DESKILO_'));
  if (!gated) return family.owner;
  final vars = env.where((e) => e.startsWith('DESKILO_')).toList()..sort();
  final owners = <String>[];
  for (final dir in ['scripts', '.github/workflows']) {
    final d = Directory('$root/$dir');
    if (!d.existsSync()) continue;
    for (final f in d.listSync(recursive: true).whereType<File>()) {
      final text = f.readAsStringSync();
      if (text.contains(path) || vars.any(text.contains)) {
        owners.add(_relative(f.path, root));
      }
    }
  }
  owners.sort();
  return 'conditional: skipped unless ${vars.join(', ')} is set; '
      '${owners.isEmpty ? 'no automated owner sets it' : 'set by ${owners.join(', ')}'}';
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

String _layerOf(String path, String source, RunnerFamily family) {
  if (family.layer != null) return family.layer!;
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
    final family = familyOf(path)!;
    final execution = _execution(path, source, family, root);
    final conditional = execution.startsWith('conditional:');
    final layer = conditional ? 'integration' : _layerOf(path, source, family);
    final invariant = statedInvariant(source, sql: sql);
    final tests = sql
        ? int.tryParse(_plan.firstMatch(source)?.group(1) ?? '') ?? 0
        : path.endsWith('.ts')
            ? RegExp(r'Deno\.test\(').allMatches(source).length
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

    // Comments stripped first: a rule that scans raw text reports the
    // paragraph EXPLAINING it as a violation of it, which is how this
    // file came to classify itself as needing refactoring.
    final code = withoutComments(source);
    final nondeterminism = <String>[
      if (code.contains('DateTime.now()') && layer != 'lint')
        'real clock (exempt-listed)',
      if (RegExp(r'\bRandom\(\)').hasMatch(code)) 'unseeded Random',
      if (RegExp(r'Future(?:<\w+>)?\.delayed\(\s*(?:const\s+)?Duration\((?!\))')
          .hasMatch(code))
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

    var action = 'UNREVIEWED';
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

    final reviewed = reviewedDispositions[path];
    if (reviewed != null && action == 'UNREVIEWED') {
      action = reviewed.action;
      replacement = reviewed.survivor == null
          ? reviewed.reason
          : '${reviewed.reason} — survivor ${reviewed.survivor}';
    }
    entries.add(TestFileEntry(
      runner: family.name,
      execution: execution,
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
/// Gaps somebody has NAMED and not yet covered.
///
/// Empty is the correct state, not a missing section. It held eleven
/// rows — the database as a CI gate, the role matrix on row policies,
/// server feature gates, preview == apply, template merge and
/// provenance, number-sequence reuse, the restore drill, export
/// completeness, instance install/resume, the bell-less decision
/// journey, the state model — and every issue behind them is closed and
/// every artefact verified present: `13_matrix_policies.sql`,
/// `14_feature_gates.sql`, the `Restore drill` and `Install, resume and
/// upgrade a real schema` steps in `quality · database`, and
/// `test/ux/`. Checked 2026-09-19 (#1334).
///
/// A row goes back in when somebody names a gap, with the issue that
/// owns it. A table that lists gaps which are no longer gaps is worse
/// than an empty one: it teaches the reader to skim it.
const missingCoverage = <(String, String, String)>[];

String _cell(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// The totals the tool prints: files and tests, by layer and by action.
String summary(List<TestFileEntry> entries) {
  final b = StringBuffer()
    ..writeln('${entries.length} files, '
        '${entries.fold<int>(0, (n, e) => n + e.tests)} tests');
  final layers = <String, (int, int)>{};
  for (final e in entries) {
    final (f, t) = layers[e.layer] ?? (0, 0);
    layers[e.layer] = (f + 1, t + e.tests);
  }
  for (final l in (layers.keys.toList()..sort())) {
    b.writeln('  $l: ${layers[l]!.$1} files, ${layers[l]!.$2} tests');
  }
  for (final a in actions) {
    final n = entries.where((e) => e.action == a).length;
    if (n > 0) b.writeln('  $a: $n');
  }
  return b.toString();
}

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

  // Totals are printed by the tool, never committed: a count here changed
  // in every pull request that added a test, so any two such pull requests
  // conflicted on this one line and each merge forced a rebase of the rest.
  b.writeln('Totals by layer and by action: run the tool — they are printed, '
      'not committed, so two pull requests that each add a test do not '
      'conflict here.');

  b
    ..writeln()
    ..writeln('## Rules')
    ..writeln()
    ..writeln('- **Runner** — every registered runner family (#1864): ${runnerFamilies.map((f) => '`${f.root}` (${f.name})').join(', ')}. A test-shaped file outside them, or a family whose workflow no longer runs it, fails `test/lint/test_inventory_test.dart`.')
    ..writeln('- **Execution** — who runs the file. A file that skips unless a `DESKILO_*` variable is set is `integration`, and names what sets it — or says that nothing does.')
    ..writeln('- **Tests** — declarations counted in the source (a pgTAP `plan`, `Deno.test`), not executed cases: a loop or a skip changes what runs.')
    ..writeln('- **Action** — `UNREVIEWED` unless a person recorded a decision in `reviewedDispositions` (with its reason, and a survivor for a removal). No rule assigns KEEP: a generated row is not an audit.')
    ..writeln('- **Layer** — the family\'s own layer where it has one (`database`, `package`, `edge`, `perf`, `integration`, `tool`); in the root suite `test/lint`, `a11y`, `i18n`, `perf`, `property`, `ux` (journey) and `tool` are named by folder; otherwise `widget` when the file pumps widgets, `unit` when it does not.')
    ..writeln('- **Invariant** — the first paragraph of the header comment. A file that states none is `KEEP+REFACTOR`: a test whose purpose must be reverse-engineered cannot be judged, kept or safely deleted.')
    ..writeln('- **Deterministic** — no unless the file reads the real clock (only the files `test/lint/no_wall_clock_test.dart` exempts, each for a stated reason), uses an unseeded `Random()`, or waits a real non-zero delay. The last two are `KEEP+REFACTOR`.')
    ..writeln('- **Dependency** — fakes (`mock_providers`, `fake_*`), mocked platform channels, repository sources read from disk, a temporary filesystem, real async I/O (`runAsync`), or the local Supabase stack.')
    ..writeln('- **Failure value** — what a failure blocks, by layer, with the issues the file cites.')
    ..writeln('- **Duplicate** — a test name shared with another file. A candidate for review, never a deletion by itself: the triage forbids deleting a test unless a demonstrably stronger one covers it.')
    ..writeln('- **Structure coupling** — `findsNWidgets` and `tester.widget<…>` reads. A `widget`/`unit` file with $structureCouplingThreshold or more and no semantics assertion is `KEEP+REFACTOR`: assert what the user can observe unless the structure is itself the invariant — which the file then states with a `// $structureMarker — <reason>` comment.')
    ..writeln('- **DELETE / REPLACE / MOVE** are never assigned by rule. They need a named stronger test, recorded in the replacement column by the pull request that makes the change.')
    ..writeln()
    ..writeln('## Coverage still to add')
    ..writeln();
  if (missingCoverage.isEmpty) {
    b.writeln('No gap is recorded. This lists gaps somebody named; it is '
        'not the result of an audit, and an empty list does not mean '
        'nothing is uncovered (#1864).');
  } else {
    b
      ..writeln('| gap | issue | status |')
      ..writeln('|---|---|---|');
    for (final (gap, issue, status) in missingCoverage) {
      b.writeln('| ${_cell(gap)} | $issue | ${_cell(status)} |');
    }
  }

  b
    ..writeln()
    ..writeln('## Files')
    ..writeln()
    ..writeln('| test/file | runner | execution | layer | invariant | declared tests | deterministic? | integration dependency | failure value | shared test name (candidate) | action | decision / replacement |')
    ..writeln('|---|---|---|---|---|---:|---|---|---|---|---|---|');
  for (final e in entries) {
    b.writeln('| `${e.path}` | ${e.runner} | ${_cell(e.execution)} | ${e.layer} | ${_cell(e.invariant)} | ${e.tests} | '
        '${_cell(e.deterministic)} | ${_cell(e.dependency)} | ${_cell(e.failureValue)} | '
        '${_cell(e.duplicate)} | ${e.action} | ${_cell(e.replacement)} |');
  }
  return b.toString();
}

/// Where the inventory is written.
const inventoryPath = 'docs/testing/TEST_INVENTORY.md';
