// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3516 -- a country-dependent line that changed in this candidate must have
// been run by some test of the merged coverage.
//
//   dart tool/country_coverage.dart --lcov coverage/lcov.info \
//       --base <sha> --candidate <sha> [--line-out report/country-coverage-line.txt]
//
// THE MEASURE (decision of 11 and 13 Nov on the issue): the changed executable
// lines of a `lib/` file that hold a country-code literal (tool/country_literals.dart),
// hit by any test of the merged lcov. Not parity between countries and not both
// outcomes of a branch: line coverage proves a line ran, nothing more.
//
//  * Changed = added or modified lines of `git diff --no-ext-diff -M -U0
//    <base> <candidate> -- lib` (a rename carries only its edited lines).
//  * A literal is judged on its own lines when any carries a `DA:` record: hit
//    when one of them has a count above zero. A literal on a continuation line
//    has no record of its own; its executable span is the FIRST line of the
//    statement, switch case or switch-expression arm that holds it.
//  * A literal with no record on either is not executable (a `const` set, an
//    enum argument): it carries no coverage and is not reported.
//  * A changed file with no `SF:` record at all was never loaded by a test:
//    every country literal on its changed lines is reported.
//  * Fail closed: a missing, empty or malformed lcov, an unreadable base, or a
//    working tree that is not the candidate ends in a nonzero exit. The
//    check never says "nothing to check" about evidence it could not read.
//
// Exit 0 clean, 1 an uncovered line or unusable evidence, 2 a usage or
// provenance error.
import 'dart:io';
import 'dart:io' as io show stdout;

import 'country_literals.dart';
import 'quality_rows/lcov_merge.dart';

/// `path -> changed new-side line numbers` of a `-U0` unified diff.
Map<String, Set<int>> changedLines(String diff) {
  final out = <String, Set<int>>{};
  String? path;
  for (final line in diff.split('\n')) {
    if (line.startsWith('+++ ')) {
      final name = line.substring(4).trim();
      path = name == '/dev/null' ? null : name.replaceFirst(RegExp(r'^b/'), '');
    } else if (line.startsWith('@@') && path != null) {
      final m = RegExp(r'\+(\d+)(?:,(\d+))?').firstMatch(line);
      if (m == null) continue;
      final start = int.parse(m.group(1)!);
      final count = m.group(2) == null ? 1 : int.parse(m.group(2)!);
      out.putIfAbsent(path, () => {}).addAll(
        [for (var i = 0; i < count; i++) start + i],
      );
    }
  }
  return out;
}

/// A reported literal: where, and why.
class Uncovered {
  const Uncovered(this.path, this.line, this.reason);
  final String path;
  final int line;
  final String reason;
  @override
  String toString() => '$path:$line $reason';
}

/// The changed country literals of [source] that no hit covers. [hits] is the
/// file's lcov record (`null`: no record at all), [changed] its new-side lines.
List<Uncovered> uncoveredCountryLines(
  String path,
  String source,
  Set<int> changed,
  Map<int, int>? hits,
) {
  final out = <Uncovered>[];
  for (final lit in countryLiterals(source)) {
    final own = [for (var l = lit.line; l <= lit.endLine; l++) l];
    if (!own.any(changed.contains)) continue;
    if (hits == null) {
      out.add(Uncovered(path, lit.line, 'no test loaded this file'));
      continue;
    }
    var span = own.where(hits.containsKey).toList();
    if (span.isEmpty && lit.anchorLine != null && hits.containsKey(lit.anchorLine)) {
      span = [lit.anchorLine!];
    }
    if (span.isEmpty) continue; // not executable: no coverage to ask for
    if (!span.any((l) => hits[l]! > 0)) {
      out.add(Uncovered(path, lit.line, 'no test ran this line'));
    }
  }
  return out;
}

bool _eligible(String path) =>
    path.startsWith('lib/') &&
    path.endsWith('.dart') &&
    !path.endsWith('.g.dart') &&
    !path.endsWith('.freezed.dart') &&
    !path.startsWith('lib/l10n/');

void main(List<String> args) => exitCode = run(args);

int run(List<String> args, {String? workingDirectory, StringSink? out}) {
  final o = out ?? io.stdout;
  String? option(String name) {
    final i = args.indexOf('--$name');
    return i < 0 || i + 1 >= args.length ? null : args[i + 1];
  }

  final lcovPath = option('lcov');
  final base = option('base');
  final candidate = option('candidate');
  final lineOut = option('line-out');
  if (lcovPath == null || base == null || candidate == null) {
    stderr.writeln('country_coverage: needs --lcov, --base and --candidate');
    return 2;
  }
  final dir = workingDirectory ?? Directory.current.path;
  String line(String text) {
    if (lineOut != null) {
      File(lineOut)
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('$text\n');
    }
    return text;
  }

  ProcessResult git(List<String> a) =>
      Process.runSync('git', a, workingDirectory: dir);

  // Provenance: the tree read here is the candidate the coverage was made of.
  final head = git(['rev-parse', 'HEAD']);
  if (head.exitCode != 0 || '${head.stdout}'.trim() != candidate) {
    o.writeln('::error::the working tree is not the candidate $candidate: '
        'the coverage cannot be tied to the lines read');
    line('not measured: tree is not the candidate');
    return 2;
  }
  final lcovFile = File(lcovPath);
  if (!lcovFile.existsSync() || lcovFile.lengthSync() == 0) {
    o.writeln('::error::$lcovPath is missing or empty: no coverage evidence');
    line('not measured: no coverage');
    return 1;
  }
  final Map<String, Map<int, int>> hits;
  try {
    hits = lcovHits(lcovFile.readAsStringSync(), root: dir);
  } on LcovFormatException catch (e) {
    o.writeln('::error::$lcovPath is not usable evidence: ${e.message}');
    line('not measured: unusable coverage');
    return 1;
  }
  final diff = git(['diff', '--no-ext-diff', '-M', '-U0', base, candidate, '--', 'lib']);
  if (diff.exitCode != 0) {
    o.writeln('::error::the diff $base..$candidate cannot be read: ${diff.stderr}');
    line('not measured: no diff');
    return 1;
  }
  final changed = changedLines('${diff.stdout}');
  final bad = <Uncovered>[];
  var checked = 0;
  for (final entry in changed.entries) {
    if (!_eligible(entry.key)) continue;
    final file = File('$dir/${entry.key}');
    if (!file.existsSync()) continue;
    final source = file.readAsStringSync();
    final literals = countryLiterals(source)
        .where((l) => [for (var n = l.line; n <= l.endLine; n++) n].any(entry.value.contains));
    checked += literals.length;
    bad.addAll(uncoveredCountryLines(entry.key, source, entry.value, hits[entry.key]));
  }
  for (final u in bad) {
    final file = u.path;
    o.writeln('::error file=$file,line=${u.line}::country line not covered: ${u.reason}');
  }
  if (bad.isNotEmpty) {
    o.writeln(line('${bad.length} of $checked changed country lines not run by any test'));
    return 1;
  }
  o.writeln(line(checked == 0
      ? 'no changed country line'
      : '$checked changed country lines, none unrun'));
  return 0;
}
