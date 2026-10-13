// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2491 (C1 of #2490) — the code-health ratchet holds IDENTIFIED functions.
//
// A count of functions over a limit can be gamed by moving the problem: make
// one function better, another worse, and the count stays. The baseline
// (docs/design/CODE_HEALTH_BASELINE.json) therefore names every function at
// or over a limit, by file + enclosing type + name + parameter signature, with
// its cognitive and cyclomatic complexity, length and parameter count:
//
//  * a held function may only stay or fall, in each measure;
//  * a function the baseline does not hold — new, renamed, moved, extracted,
//    re-signed — is judged as new: under every limit, or in the reviewed
//    test/lint/code_health_exceptions.txt;
//  * when a function falls or goes, its baseline line falls with it in the
//    same change; the failure prints the line to write.
//
// The second group proves the rules on synthetic functions, so the gate
// cannot rot into a presence check. The generated summary has a drift test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/code_health.dart';

/// `void <name>() { if (a) { if (a) { ... } } }` nested [depth] deep:
/// cognitive complexity depth * (depth + 1) / 2, cyclomatic depth + 1.
String _nested(String name, int depth) {
  final open = List.filled(depth, '  if (a) {\n').join();
  final close = List.filled(depth, '  }\n').join();
  return 'void $name(bool a) {\n$open$close}\n';
}

List<FunctionHealth> _measure(String source) =>
    measureSource('lib/x.dart', source).functions;

Map<String, BaselineFunction> _baselineOf(List<FunctionHealth> fns) =>
    baselineFunctions(baselineJson([
      FileHealth(
          path: 'lib/x.dart',
          loc: 0,
          isPart: false,
          functions: fns,
          errors: const []),
    ]));

void main() {
  late List<FileHealth> tree;
  late Map<String, BaselineFunction> baseline;
  late Map<String, String> exceptions;

  setUpAll(() {
    tree = measureTree('lib');
    baseline = baselineFunctions(
        File('docs/design/CODE_HEALTH_BASELINE.json').readAsStringSync());
    exceptions = parseExceptions(
        File('test/lint/code_health_exceptions.txt').readAsStringSync());
  });

  group('the tree', () {
    test('parses whole: a file the parser rejects is a failure, not noise', () {
      final errors = [for (final f in tree) ...f.errors];
      expect(errors, isEmpty);
    });

    test('no function got worse, no new function is over a limit, and every '
        'improvement lowered its baseline line (run: dart run '
        'tool/code_health.dart --hotspots for where to look)', () {
      final failures = ratchetFailures(
        baseline: baseline,
        current: [for (final f in tree) ...f.functions],
        exceptions: exceptions,
      );
      expect(failures, isEmpty,
          reason: '\n${failures.join('\n')}\n\nThe baseline may only fall. '
              'Lower or delete the line named above; to take a function '
              'over a limit anyway, list it in '
              'test/lint/code_health_exceptions.txt with an issue and a '
              'reason.');
    });

    test('the counts over each limit, per file, may only fall', () {
      final failures = aggregateFailures(
          baseline: baseline, current: tree, exceptions: exceptions);
      expect(failures, isEmpty);
    });

    test('the limits the baseline records are the tool\'s', () {
      final header = (jsonDecode(
              File('docs/design/CODE_HEALTH_BASELINE.json').readAsStringSync())
          as Map<String, Object?>)['thresholds'];
      expect(header, thresholdsJson());
    });

    test('docs/design/CODE_HEALTH.md is what the tool writes from the '
        'baseline (run: dart run tool/code_health.dart --baseline)', () {
      final text = File('docs/design/CODE_HEALTH_BASELINE.json')
          .readAsStringSync();
      expect(File('docs/design/CODE_HEALTH.md').readAsStringSync(),
          summaryOf(jsonDecode(text) as Map<String, Object?>));
    });
  });

  group('the ratchet cannot be gamed by moving the problem', () {
    final big = _nested('big', 8); // cognitive 36
    final bigger = _nested('big', 9); // cognitive 45

    test('the fixtures are what they say', () {
      expect(_measure(big).single.cognitive, 36);
      expect(_measure(bigger).single.cognitive, 45);
    });

    test('1. raising one function while another is simplified, the count '
        'unchanged, FAILS', () {
      final before = _measure('${_nested('big', 8)}${_nested('other', 9)}');
      final after = _measure('${_nested('big', 9)}${_nested('other', 8)}');
      expect(after.where((f) => f.overLimit).length,
          before.where((f) => f.overLimit).length,
          reason: 'the file\'s count of functions over 30 is unchanged');
      final failures =
          ratchetFailures(baseline: _baselineOf(before), current: after);
      expect(failures.where((f) => f.startsWith('WORSE')),
          [contains('lib/x.dart#big(bool a)')]);
      expect(failures.where((f) => f.startsWith('IMPROVED')),
          [contains('lib/x.dart#other(bool a)')]);
    });

    test('2. renaming an over-limit function without improving it FAILS', () {
      final failures = ratchetFailures(
          baseline: _baselineOf(_measure(big)),
          current: _measure(_nested('renamed', 8)));
      expect(failures.any((f) => f.startsWith('NEW over a limit') &&
          f.contains('#renamed(bool a)')), isTrue);
      expect(failures.any((f) => f.startsWith('GONE') &&
          f.contains('#big(bool a)')), isTrue);
    });

    test('3. extracting a new over-limit helper FAILS', () {
      final failures = ratchetFailures(
          baseline: _baselineOf(_measure(big)),
          current: _measure('$big${_nested('helper', 8)}'));
      expect(failures.single, startsWith('NEW over a limit'));
      expect(failures.single, contains('#helper(bool a)'));
    });

    test('3b. a changed signature is a new function', () {
      final failures = ratchetFailures(
          baseline: _baselineOf(_measure(big)),
          current: _measure(big.replaceFirst('(bool a)', '(bool a, int b)')));
      expect(failures.any((f) => f.startsWith('NEW over a limit')), isTrue);
    });

    test('4. improving a function without lowering its baseline entry FAILS '
        'and prints the line to write', () {
      final failures = ratchetFailures(
          baseline: _baselineOf(_measure(bigger)), current: _measure(big));
      expect(failures.single, startsWith('IMPROVED'));
      final entry = baselineEntry(_measure(big).single);
      expect(failures.single, contains(jsonEncode(entry)));
      // Lowering the baseline after a real improvement passes.
      expect(
          ratchetFailures(
              baseline: _baselineOf(_measure(big)), current: _measure(big)),
          isEmpty);
    });

    test('4b. an improvement below every limit says to delete the line', () {
      final failures = ratchetFailures(
          baseline: _baselineOf(_measure(big)),
          current: _measure(_nested('big', 3)));
      expect(failures.single, contains('delete its line'));
    });

    test('a held function that stays as it is passes', () {
      expect(
          ratchetFailures(
              baseline: _baselineOf(_measure(big)), current: _measure(big)),
          isEmpty);
    });

    test('a synthetic function over EACH limit fails', () {
      final over = {
        'cognitive': _nested('f', 8), // 36 / 9
        'cyclomatic': 'void f(bool a) {\n${'  if (a) {}\n' * 24}}\n',
        'length': 'void f() {\n${'  print(1);\n' * 150}}\n',
        'parameters': 'void f(${List.generate(7, (i) => 'int p$i').join(', ')}) {}\n',
      };
      for (final entry in over.entries) {
        final fns = _measure(entry.value);
        expect(fns.single.overLimit, isTrue, reason: entry.key);
        expect(ratchetFailures(baseline: const {}, current: fns), isNotEmpty,
            reason: '${entry.key} over its limit must fail');
      }
    });

    test('a function just under every limit passes', () {
      final under = {
        'cognitive': _nested('f', 7), // 28
        'cyclomatic': 'void f(bool a) {\n${'  if (a) {}\n' * 23}}\n',
        'length': 'void f() {\n${'  print(1);\n' * 147}}\n',
        'parameters': 'void f(${List.generate(6, (i) => 'int p$i').join(', ')}) {}\n',
      };
      for (final entry in under.entries) {
        final fns = _measure(entry.value);
        expect(fns.single.overLimit, isFalse, reason: entry.key);
        expect(ratchetFailures(baseline: const {}, current: fns), isEmpty,
            reason: entry.key);
      }
    });

    test('a reviewed exception admits a new function; a stale one fails', () {
      final fns = _measure(big);
      final id = fns.single.id;
      expect(
          ratchetFailures(
              baseline: const {},
              current: fns,
              exceptions: {id: '#1 because'}),
          isEmpty);
      final stale = ratchetFailures(
          baseline: const {},
          current: _measure(_nested('big', 2)),
          exceptions: {_measure(_nested('big', 2)).single.id: '#1 because'});
      expect(stale.single, startsWith('STALE exception'));
      expect(
          ratchetFailures(
              baseline: const {},
              current: fns,
              exceptions: {id: '#1 z', 'x#y()': '#1 z'}).single,
          startsWith('STALE exception, no such function'));
    });

    test('the exceptions file needs an issue and a reason on every line', () {
      expect(parseExceptions('# c\n\na#b() | #12 | why\n'),
          {'a#b()': '#12 why'});
      expect(() => parseExceptions('a#b() | no issue | why'),
          throwsFormatException);
      expect(() => parseExceptions('a#b() | #12 |'), throwsFormatException);
    });

    test('per-file counts may only fall', () {
      final held = baselineFunctions(baselineJson([
        FileHealth(
            path: 'lib/x.dart',
            loc: 0,
            isPart: false,
            functions: _measure(big),
            errors: const []),
      ]));
      expect(
          aggregateFailures(
              baseline: held,
              current: [measureSource('lib/x.dart', '$big${_nested('h', 8)}')]),
          isNotEmpty);
      expect(
          aggregateFailures(
              baseline: held, current: [measureSource('lib/x.dart', big)]),
          isEmpty);
    });
  });
}
