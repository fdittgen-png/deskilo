// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1632 — the MCP coverage gate holds for the committed map, and FAILS,
// naming the defect, for each fault the conformance issue requires it to
// catch: a new unclassified tool, a tool covered by nothing, a missing
// required test, a reference that never names its tool, a map reviewed
// against another contract, a zero or missing report, a skipped, failed
// or never-run required file, and evidence from another commit. The CLI
// exits nonzero on a broken report: the gate reads the process.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mcp_coverage/coverage.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String? _read(String path) {
  final f = File(path);
  return f.existsSync() ? f.readAsStringSync() : null;
}

String get _sha => contractFingerprint(File(contractPath).readAsBytesSync());

/// A deep copy, so a fault never leaks into the next case.
Map<String, dynamic> _copy(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

/// A pg_prove report where every required file passed, at [sha].
String _report(Map<String, dynamic> coverage, {String sha = 'abc1234'}) => [
  '# source $sha',
  for (final f in requiredPgtap(coverage))
    '/work/supabase/tests/database/$f ......... ok',
  'All tests successful.',
  'Result: PASS',
].join('\n');

void main() {
  final coverage = _json(coveragePath);
  final contract = _json(contractPath);

  test('the committed map covers every implemented tool, and holds', () {
    expect(validateCoverage(coverage, contract, _sha, _read), isEmpty);
    expect(
      (coverage['operations'] as Map).keys.toSet(),
      implementedOperations(contract).keys.toSet(),
    );
  });

  test('a report where every required file passed is evidence', () {
    expect(checkPgtapEvidence(coverage, _report(coverage), 'abc1234'), isEmpty);
  });

  group('controlled faults fail the gate, each by name', () {
    test('a new implemented tool the map does not name', () {
      final c = _copy(contract);
      (c['operations'] as List).add({
        'id': 'delete_everything',
        'handler': true,
        'mutation': 'write',
      });
      expect(
        validateCoverage(coverage, c, _sha, _read),
        contains('delete_everything is implemented but has no coverage entry'),
      );
    });

    test('a covered name the contract does not implement', () {
      final m = _copy(coverage);
      (m['operations'] as Map)['ghost_tool'] = {
        'positive': ['test/tool/mcp_contract_test.dart'],
      };
      expect(
        validateCoverage(m, contract, _sha, _read),
        contains(
          'ghost_tool is covered but the contract implements no such tool',
        ),
      );
    });

    test('a state-changing tool without its state regression', () {
      final m = _copy(coverage);
      ((m['operations'] as Map)['create_reservation'] as Map).remove('state');
      expect(
        validateCoverage(m, contract, _sha, _read),
        contains('create_reservation: no state test'),
      );
    });

    test('a reference to a test that does not exist', () {
      final m = _copy(coverage);
      ((m['operations'] as Map)['check_out'] as Map)['denial'] = [
        'supabase/tests/database/99_gone.sql',
      ];
      expect(
        validateCoverage(m, contract, _sha, _read),
        contains(
          'check_out: denial `supabase/tests/database/99_gone.sql` is not an '
          'existing test file',
        ),
      );
    });

    test('a reference that never names the tool it claims to cover', () {
      final m = _copy(coverage);
      ((m['operations'] as Map)['request_refund'] as Map)['positive'] = [
        'supabase/tests/database/00_schema_guarantees.sql',
      ];
      expect(
        validateCoverage(m, contract, _sha, _read),
        contains(
          'request_refund: positive '
          '`supabase/tests/database/00_schema_guarantees.sql` never names '
          'request_refund',
        ),
      );
    });

    test('a new output field (any contract change) forces a review', () {
      final changed = utf8.encode(
        File(contractPath).readAsStringSync().replaceFirst(
          '"output_fields": {',
          '"output_fields": {\n  "private_note": {"class": "operational"},',
        ),
      );
      final problems = validateCoverage(
        coverage,
        contract,
        contractFingerprint(changed),
        _read,
      );
      expect(
        problems.single,
        startsWith(
          'coverage.json was reviewed against '
          'another operations.json',
        ),
      );
    });

    test('a missing or empty report: nothing was executed', () {
      for (final r in [null, '', '  \n']) {
        expect(checkPgtapEvidence(coverage, r, 'abc1234'), [
          'the pgTAP report is missing or empty: nothing was executed',
        ]);
      }
    });

    test('a report that ran no file at all', () {
      expect(
        checkPgtapEvidence(
          coverage,
          '# source abc1234\nResult: PASS',
          'abc1234',
        ),
        containsAll([
          'the pgTAP report ran no file',
          '97_mcp_conformance_journey.sql never ran',
        ]),
      );
    });

    test('a required file skipped, failed or dubious', () {
      for (final (verdict, word) in [
        ('skipped: no pgtap', 'skipped'),
        ('Failed 2/79 subtests', 'Failed'),
        ('Dubious, test returned 1', 'Dubious'),
        ('ok (3 skipped)', 'skipped'),
      ]) {
        final report = _report(coverage).replaceFirst(
          '97_mcp_conformance_journey.sql ......... ok',
          '97_mcp_conformance_journey.sql ......... $verdict',
        );
        expect(checkPgtapEvidence(coverage, report, 'abc1234'), [
          contains('97_mcp_conformance_journey.sql did not pass: '),
        ], reason: word);
      }
    });

    test('the verdict printed after diagnostics still counts', () {
      final report = _report(coverage).replaceFirst(
        '97_mcp_conformance_journey.sql ......... ok',
        '97_mcp_conformance_journey.sql ......... \n# note\nFailed 1/79 subtests',
      );
      expect(checkPgtapEvidence(coverage, report, 'abc1234'), [
        '97_mcp_conformance_journey.sql did not pass: Failed 1/79 subtests',
      ]);
    });

    test('evidence from another commit is stale', () {
      expect(
        checkPgtapEvidence(
          coverage,
          _report(coverage, sha: 'fedcba9'),
          'abc1234',
        ),
        ['the pgTAP report is for fedcba9, not abc1234: stale evidence'],
      );
    });
  });

  test('the CLI exits 1 over a failing report and 0 over a passing one', () {
    final dir = Directory.systemTemp.createTempSync('mcp-coverage');
    addTearDown(() => dir.deleteSync(recursive: true));
    final good = File('${dir.path}/good.log')
      ..writeAsStringSync(_report(coverage));
    final stale = File('${dir.path}/stale.log')
      ..writeAsStringSync(_report(coverage, sha: 'fedcba9'));
    ProcessResult cli(File log) => Process.runSync('dart', [
      'run',
      'tool/mcp_coverage.dart',
      '--pgtap',
      log.path,
      '--sha',
      'abc1234',
    ]);
    expect(cli(good).exitCode, 0, reason: '${cli(good).stderr}');
    final r = cli(stale);
    expect(r.exitCode, 1);
    expect('${r.stderr}', contains('stale evidence'));
  });
}
