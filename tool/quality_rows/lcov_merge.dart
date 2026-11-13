// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2600 C2 — the coverage of several test runs as one LCOV report.
//
// Coverage over the same tree is a union: a line is covered when ANY run
// hit it, and its hit count is the sum. This merges per source file and
// per line, recomputes LF/LH from the lines, normalises the path
// spelling (`./lib/a.dart`, `lib\a.dart` and an absolute path under the
// checkout are one file), and writes records sorted by path so the same
// inputs always give the same bytes. A record that is not closed, a line
// that is not `number,hits`, or a report with no record at all is not
// evidence: it throws, and the caller fails the gate.
//
// Only SF, DA, LF, LH and end_of_record are carried: they are everything
// scripts/coverage_gate.sh reads. (flutter test --coverage writes no
// function or branch records.)
class LcovFormatException implements Exception {
  LcovFormatException(this.message);
  final String message;
  @override
  String toString() => 'LcovFormatException: $message';
}

/// `./lib/a.dart`, `lib\a.dart` or `<root>/lib/a.dart` as `lib/a.dart`.
String normalizeSourcePath(String path, {String? root}) {
  var p = path.trim().replaceAll('\\', '/');
  if (root != null) {
    final r = root.replaceAll('\\', '/').replaceFirst(RegExp(r'/+$'), '');
    if (r.isNotEmpty && p.startsWith('$r/')) p = p.substring(r.length + 1);
  }
  while (p.startsWith('./')) {
    p = p.substring(2);
  }
  return p;
}

/// The hit count of every line of every source file of ONE report ([number]
/// names it in an error), by normalised path. The merge below and the checks
/// that read a merged report (tool/country_coverage.dart) share this parse, so
/// there is one reading of the format. A record that is not closed, a line
/// that is not `number,hits` or a report with no record at all throws.
Map<String, Map<int, int>> lcovHits(
  String report, {
  String? root,
  int number = 1,
}) {
  final lines = <String, Map<int, int>>{};
  String? sf;
  Map<int, int>? hits;
  var seen = 0;
  var row = 0;
  for (final raw in report.split('\n')) {
    row++;
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith('SF:')) {
      if (sf != null) {
        throw LcovFormatException(
          'report $number line $row: SF: inside the open record of $sf',
        );
      }
      sf = normalizeSourcePath(line.substring(3), root: root);
      hits = lines.putIfAbsent(sf, () => {});
    } else if (line.startsWith('DA:')) {
      if (sf == null) {
        throw LcovFormatException('report $number line $row: DA outside a record');
      }
      final parts = line.substring(3).split(',');
      final no = parts.isEmpty ? null : int.tryParse(parts[0]);
      final count = parts.length < 2 ? null : int.tryParse(parts[1]);
      if (no == null || count == null || no < 0 || count < 0) {
        throw LcovFormatException(
          'report $number line $row: bad DA record "$line"',
        );
      }
      hits![no] = (hits[no] ?? 0) + count;
    } else if (line == 'end_of_record') {
      if (sf == null) {
        throw LcovFormatException(
          'report $number line $row: end_of_record without SF',
        );
      }
      sf = null;
      hits = null;
      seen++;
    }
    // LF, LH and any other tag are recomputed or irrelevant.
  }
  if (sf != null) {
    throw LcovFormatException('report $number ends inside the record of $sf');
  }
  if (seen == 0) throw LcovFormatException('report $number holds no record');
  return lines;
}

/// Merges [reports] (LCOV text, one per run) into one report.
String mergeLcov(List<String> reports, {String? root}) {
  if (reports.isEmpty) throw LcovFormatException('nothing to merge');
  final lines = <String, Map<int, int>>{};
  for (var n = 0; n < reports.length; n++) {
    lcovHits(reports[n], root: root, number: n + 1).forEach((path, hits) {
      final into = lines.putIfAbsent(path, () => {});
      hits.forEach((no, count) => into[no] = (into[no] ?? 0) + count);
    });
  }
  final b = StringBuffer();
  for (final path in lines.keys.toList()..sort()) {
    final hits = lines[path]!;
    final numbers = hits.keys.toList()..sort();
    b.writeln('SF:$path');
    for (final no in numbers) {
      b.writeln('DA:$no,${hits[no]}');
    }
    b
      ..writeln('LF:${numbers.length}')
      ..writeln('LH:${numbers.where((no) => hits[no]! > 0).length}')
      ..writeln('end_of_record');
  }
  return b.toString();
}
