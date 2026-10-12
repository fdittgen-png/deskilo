// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 C2 — which validation a change REQUIRES, decided conservatively.
//
// The classifier selects work, never whether a run may report green:
// every required context still reports on every pull request. It starts
// from a positive list of paths known not to touch the database, and
// anything it does not recognise selects full validation. A file
// extension is not a dependency model — `docs/wiki/**` regenerates the
// help assets, `assets/instance/**` IS the schema, and a `.dart` file
// under `data/` changes an RPC contract — so the rules name directories,
// not suffixes.
//
// Bump [classifierVersion] whenever a rule changes: the version travels
// with every verdict, so a report can say which rules made it.
//
// v3 — a diff it cannot read completely (a record cut short, a status
// letter it does not know, a change list git could not write) selects
// everything, with the defect as the reason; before, the parser dropped
// the broken tail and classified what was left.

const String classifierVersion = '3';

/// Where a pull request's change came from, as the classifier sees it.
class ChangeSet {
  const ChangeSet({
    required this.paths,
    required this.baseKnown,
    required this.event,
    this.problem,
  });

  /// Every changed path — a rename contributes both its names.
  final List<String> paths;

  /// The base commit was available, so [paths] is the complete diff.
  final bool baseKnown;

  /// Why [paths] cannot be trusted as the complete diff, or null when it
  /// can: a record cut short, a status the parser does not know, a
  /// change list git failed to write. Any problem selects everything.
  final String? problem;

  /// `pull_request`, `push`, `schedule`, `workflow_dispatch`.
  final String event;
}

class Verdict {
  // ignore: avoid_positional_boolean_parameters — #2389, an existing API; named when it next changes
  const Verdict(this.discipline, this.required, this.reason);
  final String discipline;
  final bool required;
  final String reason;
  String get psv =>
      '$discipline|${required ? 'required' : 'not_applicable'}|$reason|v$classifierVersion';
}

/// Paths whose change cannot affect the database job (replay, pgTAP,
/// policy manifest, the two-session scripts, the Edge payment check).
/// Everything else can, until proven otherwise.
bool _databaseIndependent(String path) {
  const prefixes = [
    'docs/',
    'assets/help/',
    'assets/images/',
    'assets/fonts/',
    'lib/l10n/',
    'test/features/',
    'test/a11y/',
    'test/i18n/',
    'test/core/',
    'test/ux/',
    'test/helpers/',
    'test/app/',
    'web/',
    'android/',
    'ios/',
    'macos/',
    'windows/',
    'linux/',
  ];
  const files = ['README.md', 'CONTRIBUTING.md', 'LICENSE', 'CHANGELOG.md'];
  if (files.contains(path)) return true;
  if (prefixes.any(path.startsWith)) return true;
  // Widgets and screens, in any feature — never the repository adapters
  // (`data/`), the domain contracts SQL fixtures share, or the instance
  // tooling.
  if (path.startsWith('lib/features/') && path.contains('/presentation/')) {
    return true;
  }
  if (path.startsWith('lib/features/') && path.contains('/providers/')) {
    return true;
  }
  if (path.startsWith('lib/app/')) return true;
  if (path.startsWith('lib/core/') &&
      !path.startsWith('lib/core/instance/') &&
      !path.startsWith('lib/core/backend/')) {
    return true;
  }
  return false;
}

/// Paths that matter to the browser build.
///
/// `packages/` is there because a path dependency in `pubspec.yaml` is
/// runtime code like any other: `packages/deskilo_push` is imported and
/// instantiated by `lib/core/push/push_providers.dart`, so a `dart:io`
/// import added inside it breaks `flutter build web` and nothing else.
/// It is not reachable from `lib/`'s prefix, so it needed naming (#1446
/// R3).
bool _webRelevant(String path) =>
    path.startsWith('web/') ||
    path.startsWith('lib/') ||
    path.startsWith('assets/') ||
    path.startsWith('packages/') ||
    path == 'pubspec.yaml' ||
    path == 'pubspec.lock' ||
    path == '.github/workflows/web.yml';

/// The classifier's own inputs: a change to them selects everything.
bool _selectsEverything(String path) =>
    path.startsWith('.github/') ||
    path.startsWith('tool/ci_classify') ||
    path.startsWith('tool/quality_rows') ||
    path.startsWith('scripts/') ||
    path == 'pubspec.yaml' ||
    path == 'pubspec.lock' ||
    path.startsWith('tool/');

List<Verdict> classify(ChangeSet change) {
  if (change.event != 'pull_request') {
    return [
      Verdict('database', true, 'not a pull request: ${change.event} runs everything'),
      Verdict('web', true, 'not a pull request: ${change.event} runs everything'),
    ];
  }
  if (!change.baseKnown) {
    return const [
      Verdict('database', true, 'the base commit is unknown: the diff cannot be trusted'),
      Verdict('web', true, 'the base commit is unknown: the diff cannot be trusted'),
    ];
  }
  if (change.problem != null) {
    final why = 'the diff is incomplete: ${change.problem}';
    return [Verdict('database', true, why), Verdict('web', true, why)];
  }
  if (change.paths.isEmpty) {
    return const [
      Verdict('database', true, 'no changed path was reported: nothing proves independence'),
      Verdict('web', true, 'no changed path was reported: nothing proves independence'),
    ];
  }
  final everything = change.paths.where(_selectsEverything).toList();
  if (everything.isNotEmpty) {
    final why = 'a workflow, script, generator or dependency changed: ${everything.first}';
    return [Verdict('database', true, why), Verdict('web', true, why)];
  }
  final dbTouching = change.paths.where((p) => !_databaseIndependent(p)).toList();
  final webTouching = change.paths.where(_webRelevant).toList();
  return [
    if (dbTouching.isEmpty) Verdict('database', false,
            'every changed path is independent of the database (${change.paths.length} files, e.g. ${change.paths.first})') else Verdict('database', true, 'database-relevant: ${dbTouching.first}'),
    if (webTouching.isEmpty) Verdict('web', false,
            'no changed path reaches the browser build (e.g. ${change.paths.first})') else Verdict('web', true, 'browser-relevant: ${webTouching.first}'),
  ];
}

/// What [pathsFromNameStatus] read: the paths, and the first defect that
/// makes the list untrustworthy, or null when every record was whole.
class ParsedDiff {
  const ParsedDiff(this.paths, this.problem);
  final List<String> paths;
  final String? problem;
}

/// Parses `git diff --name-status -z <base> <head>`: NUL-separated
/// records of status, path, and a second path for renames and copies.
/// Every path of a rename counts; a space in a name is not a separator.
///
/// A record cut short (a status with no path, a rename with one name) or
/// a status letter git does not emit is reported as a [ParsedDiff.problem]
/// instead of being dropped: a truncated change list must select
/// everything, not the part that survived.
ParsedDiff pathsFromNameStatus(String nulSeparated) {
  final fields = nulSeparated.split('\u0000').where((f) => f.isNotEmpty).toList();
  final paths = <String>[];
  var i = 0;
  while (i < fields.length) {
    final status = fields[i];
    if (!RegExp(r'^[ACDMRTUXB][0-9]*$').hasMatch(status)) {
      return ParsedDiff(paths, 'record $i has status "$status", which git does not emit');
    }
    final twoPaths = status.startsWith('R') || status.startsWith('C');
    final want = twoPaths ? 2 : 1;
    if (i + want >= fields.length) {
      return ParsedDiff(paths, 'record $i ($status) ends before its path');
    }
    paths.add(fields[i + 1]);
    if (twoPaths) paths.add(fields[i + 2]);
    i += 1 + want;
  }
  return ParsedDiff(paths, null);
}
