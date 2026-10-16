// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2598 (C7 of #2490) — every per-file budget the lint suite holds is one
// generated block, `budgets`, in docs/design/CODE_HEALTH_BASELINE.json.
//
//   dart run tool/code_health.dart --baseline      writes it
//   flutter test test/lint                         reads it
//
// A budget only falls. `--baseline` measures the tree, keeps the lower of
// the held number and the measured one, and REFUSES (exit 1, nothing
// written) when the tree is above a held number or above a default with no
// held number. An entry that is new on purpose (a file that has to be over
// the default, a new feature pair) is written once with
// `--allow-new=<category>:<key>`.
//
// Categories and what they count:
//   partOfFiles          one number: the `part of` files under lib/
//   fileLength           lines of a file over 500; the budget is the length
//                        plus a 20-line headroom, never above the held one
//   setState             `setState(` / `_update(` calls of a library over 5
//   repositoryInWidgets  presentation libraries per feature that resolve a
//                        repository directly (#1234)
//   pairBudget           imports behind a feature -> feature pair that has a
//                        budget (a pair without one is only named by
//                        _knownPairs in test/lint/layering_test.dart)
//
// The reason an entry is exempt lives in
// docs/design/CODE_HEALTH_BUDGET_REASONS.txt, `<category> <key> // <reason>`;
// the number is never written there.

import 'dart:convert';
import 'dart:io';

import 'layering/analysis.dart' as layering;

/// The command every failure message prints.
const String budgetCommand = 'dart run tool/code_health.dart --baseline';

const String reasonsPath = 'docs/design/CODE_HEALTH_BUDGET_REASONS.txt';

/// Lines a file may have without an entry.
const int defaultFileLength = 500;

/// How far above its file's length a file-length entry may sit.
const int fileLengthHeadroom = 20;

/// `setState` calls a library may have without an entry.
const int defaultSetState = 5;

/// The budgeted maps, in the order the JSON writes them.
const List<String> budgetCategories = [
  'fileLength',
  'setState',
  'repositoryInWidgets',
  'pairBudget',
];

/// What a category allows without an entry, and how much headroom an entry
/// may carry above the measured value.
const Map<String, ({int floor, int headroom})> _rules = {
  'fileLength': (floor: defaultFileLength, headroom: fileLengthHeadroom),
  'setState': (floor: defaultSetState, headroom: 0),
  'repositoryInWidgets': (floor: 0, headroom: 0),
  'pairBudget': (floor: 0, headroom: 0),
};

/// The budgets as held in the JSON.
class Budgets {
  Budgets({required this.partOfFiles, required this.maps});

  final int? partOfFiles;
  final Map<String, Map<String, int>> maps;

  static Budgets empty() => Budgets(
        partOfFiles: null,
        maps: {for (final c in budgetCategories) c: <String, int>{}},
      );

  /// The `budgets` block of a baseline document; empty when it has none.
  static Budgets fromBaseline(String json) {
    final block = (jsonDecode(json) as Map<String, Object?>)['budgets'];
    if (block == null) return empty();
    final map = (block as Map).cast<String, Object?>();
    return Budgets(
      partOfFiles: map['partOfFiles'] as int?,
      maps: {
        for (final c in budgetCategories)
          c: {
            for (final e in ((map[c] ?? const {}) as Map).entries)
              e.key as String: e.value as int,
          },
      },
    );
  }

  /// The held budgets of the committed baseline.
  static Budgets load([String path = 'docs/design/CODE_HEALTH_BASELINE.json']) {
    final file = File(path);
    return file.existsSync()
        ? fromBaseline(file.readAsStringSync())
        : empty();
  }

  /// The block as JSON text: an entry per line, sorted by key, no totals
  /// among the entries (#2121).
  String render() {
    final b = StringBuffer('"budgets": {\n')
      ..write('    "partOfFiles": ${partOfFiles ?? 0}');
    for (final c in budgetCategories) {
      final keys = maps[c]!.keys.toList()..sort();
      // A blank line between entries: git conflicts on ADJACENT lines too.
      b
        ..write(',\n    ${jsonEncode(c)}: {\n')
        ..write(keys
            .map((k) => '      ${jsonEncode(k)}: ${maps[c]![k]}')
            .join(',\n\n'))
        ..write('${keys.isEmpty ? '' : '\n'}    }');
    }
    b.write('\n  }');
    return b.toString();
  }
}

/// What the tree measures right now, before any budget is applied.
class BudgetActuals {
  BudgetActuals({
    required this.partOfFiles,
    required this.lines,
    required this.setState,
    required this.repositoryInWidgets,
    required this.pairBudget,
  });

  final int partOfFiles;

  /// Every hand-written lib/ file with its line count.
  final Map<String, int> lines;

  /// Libraries with at least one call.
  final Map<String, int> setState;
  final Map<String, int> repositoryInWidgets;
  final Map<String, int> pairBudget;

  /// The measured value per key of [category].
  Map<String, int> of(String category) => switch (category) {
        'fileLength' => lines,
        'setState' => setState,
        'repositoryInWidgets' => repositoryInWidgets,
        'pairBudget' => pairBudget,
        _ => throw ArgumentError(category),
      };
}

/// Newline-byte line count, as `lineCountOf` in test/lint/lint_sources.dart.
int _lineCount(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.isEmpty) return 0;
  var count = 0;
  for (final b in bytes) {
    if (b == 0x0A) count++;
  }
  if (bytes.last != 0x0A) count++;
  return count;
}

final RegExp _setStateCall = RegExp(r'\b(setState|_update)\(');

/// `setState` calls in [file]: comment lines skipped, the declaration
/// `void _update(` is not a call.
int setStateCallsOf(String source) {
  var n = 0;
  for (final raw in source.split('\n')) {
    final l = raw.trim();
    if (l.startsWith('//')) continue;
    if (_setStateCall.hasMatch(l) && !l.contains('void _update(')) n++;
  }
  return n;
}

/// Measures the tree under lib/ (run from the repository root).
BudgetActuals measureBudgetActuals() {
  final files = layering.handWrittenDartFiles('lib').toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final partOf = RegExp(r'^part of ', multiLine: true);
  final lines = <String, int>{};
  final setState = <String, int>{};
  var partOfFiles = 0;
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    lines[path] = _lineCount(file);
    final text = file.readAsStringSync();
    if (partOf.hasMatch(text)) partOfFiles++;
    final calls = setStateCallsOf(text);
    if (calls > 0) {
      // A screen split across part files is one screen (#2386).
      final library = layering.libraryPathOf(file);
      setState[library] = (setState[library] ?? 0) + calls;
    }
  }
  final features = files.where((f) => f.path.startsWith('lib/features/'));
  final reads = layering.repositoryReadsByFeature(features);
  return BudgetActuals(
    partOfFiles: partOfFiles,
    lines: lines,
    setState: setState,
    repositoryInWidgets: {
      for (final e in reads.entries) e.key: e.value.length,
    },
    pairBudget: layering.crossFeatureImports(features),
  );
}

/// Every way [actual] breaks [held], each ending in the command to run.
/// Empty when every budget is exactly where `--baseline` would write it.
List<String> budgetFailures(Budgets held, BudgetActuals actual,
    {String? only}) {
  final out = <String>[];
  if (only == null || only == 'partOfFiles') {
    final h = held.partOfFiles;
    if (h == null || actual.partOfFiles > h) {
      out.add('partOfFiles: ${actual.partOfFiles} > ${h ?? 'no budget'} — '
          'a new `part of` file. Create a class, widget or function with '
          'its own responsibility instead.');
    } else if (actual.partOfFiles < h) {
      out.add('partOfFiles: ${actual.partOfFiles}, budget $h — run '
          '`$budgetCommand`.');
    }
  }
  for (final c in budgetCategories) {
    if (only != null && only != c) continue;
    final rule = _rules[c]!;
    final measured = actual.of(c);
    final budget = held.maps[c]!;
    for (final e in measured.entries) {
      if (e.value <= rule.floor) continue;
      final b = budget[e.key];
      if (b == null && c == 'pairBudget') continue; // _knownPairs names it
      if (b == null) {
        out.add('$c ${e.key}: ${e.value} > ${rule.floor}, no budget — '
            'bring it down (an exemption needs '
            '`--allow-new=$c:${e.key}` and a reason line in $reasonsPath).');
      } else if (e.value > b) {
        out.add('$c ${e.key}: ${e.value} > $b — bring it down; a budget '
            'is never raised.');
      }
    }
    for (final e in budget.entries) {
      final now = measured[e.key];
      if (now == null || now <= rule.floor) {
        out.add('$c ${e.key}: ${now == null ? 'gone' : '$now'} — run '
            '`$budgetCommand` (drops the entry).');
      } else if (e.value > now + rule.headroom) {
        out.add('$c ${e.key}: budget ${e.value}, measured $now — run '
            '`$budgetCommand`.');
      }
    }
  }
  return out;
}

/// The budgets `--baseline` writes, or the reasons it refuses.
({Budgets budgets, List<String> refusals}) nextBudgets(
  Budgets held,
  BudgetActuals actual, {
  Set<String> allowNew = const {},
}) {
  final refusals = <String>[];
  final h = held.partOfFiles;
  if (h != null && actual.partOfFiles > h) {
    refusals.add('partOfFiles: ${actual.partOfFiles} > $h');
  }
  final maps = <String, Map<String, int>>{};
  for (final c in budgetCategories) {
    final rule = _rules[c]!;
    final next = <String, int>{};
    for (final e in actual.of(c).entries) {
      if (e.value <= rule.floor) continue;
      final b = held.maps[c]![e.key];
      if (b == null && c == 'pairBudget') continue; // _knownPairs names it
      final headed = e.value + rule.headroom;
      if (b == null) {
        if (allowNew.contains('$c:${e.key}')) {
          next[e.key] = headed;
        } else {
          refusals.add('$c ${e.key}: ${e.value} > ${rule.floor} with no '
              'budget (--allow-new=$c:${e.key} for a deliberate one)');
        }
      } else if (e.value > b) {
        refusals.add('$c ${e.key}: ${e.value} > $b, a budget is never raised');
      } else {
        next[e.key] = headed < b ? headed : b;
      }
    }
    maps[c] = next;
  }
  final pof = h == null || actual.partOfFiles < h ? actual.partOfFiles : h;
  return (budgets: Budgets(partOfFiles: pof, maps: maps), refusals: refusals);
}

/// `category key` pairs of the reasons file; the reason is the text after
/// ` // `. Throws on a line of another shape.
Map<String, String> parseReasons(String text) {
  final out = <String, String>{};
  final line = RegExp(r'^(\w+) (.+?) // (#\d+ \S.*|\S.*)$');
  for (final raw in text.split('\n')) {
    final l = raw.trim();
    if (l.isEmpty || l.startsWith('#')) continue;
    final m = line.firstMatch(l);
    if (m == null) {
      throw FormatException(
          'reason line needs "<category> <key> // <reason>": $l');
    }
    out['${m.group(1)} ${m.group(2)}'] = m.group(3)!;
  }
  return out;
}
