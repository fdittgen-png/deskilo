// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2522 (F3 of #2519) — the feature structure is proved from the code, and
// the findings may only leave.
//
// `tool/feature_audit.dart` finds the dead flags, the server gates on keys
// the registry does not have, the nested double gates and the gates whose
// every surface sits inside screens another feature owns (both a hypothesis
// that one feature should `requires` the other, never a verdict). Those
// findings are pinned in docs/design/FEATURE_AUDIT_BASELINE.json, each with a
// reviewed reason: a NEW finding fails here until it is fixed or reviewed,
// and a finding that is gone fails until its line is deleted, so the baseline
// equals the tool's output at every commit.
//
// The first groups prove each finding type on synthetic input, so the gate
// cannot rot into a presence check.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/feature_audit.dart';

const _fixtures = 'test/fixtures/feature_audit';

AuditReport _synthetic() {
  final gates = gatesOfSource(
    'lib/x.dart',
    File('$_fixtures/nested_gates.dart.fixture').readAsStringSync(),
  );
  final sql = serverGates([
    MapEntry(
      '0001.sql',
      File('$_fixtures/server_gates.sql').readAsStringSync(),
    ),
  ]);
  return audit(
    registry: const AuditRegistry({
      'alpha': null,
      'beta': null,
      'gamma': null,
      'delta': null,
      'epsilon': null,
      'zeta': null,
      'parent': null,
      'child': 'parent',
      'dead': null,
    }),
    files: [gates],
    serverByFunction: sql.byFunction,
    serverOutside: sql.outside,
  );
}

/// The files of [fixture], split at its `// ==> path` lines.
List<FileGates> _sources(String fixture) {
  final text = File('$_fixtures/$fixture').readAsStringSync();
  final parts = text.split(RegExp(r'^// ==> ', multiLine: true)).skip(1);
  return [
    for (final part in parts)
      gatesOfSource(
        part.substring(0, part.indexOf('\n')).trim(),
        part.substring(part.indexOf('\n') + 1),
      ),
  ];
}

const _screenRegistry = AuditRegistry({
  'host': null,
  'child': 'host',
  'nav': null,
  'guest': null,
  'shared': null,
  'sheetOnly': null,
  'inPart': null,
  'door': null,
  'knob': null,
  'acct': null,
  'acctTip': null,
});

void main() {
  group('a gate inside screens another feature owns (screenGates)', () {
    late List<FileGates> files;
    setUpAll(() => files = _sources('screen_owners.dart.fixture'));

    test('the fixture parses whole', () {
      expect([for (final f in files) ...f.errors], isEmpty);
    });

    test('the route map comes from the guards, parents included, and only '
        'workspace routes count', () {
      expect(routeOwners(_screenRegistry, files), {
        '/door': ['door'],
        '/open': <String>[],
        '/owned': ['host'],
        '/owned/detail': ['host'],
        '/thread': ['host'],
      });
    });

    test('a gate whose every surface sits in screens of another feature '
        'is a candidate', () {
      expect(screenGates(_screenRegistry, files), [
        'door>knob', // an `if (!featureEnabled(door)) return` redirect
        'host>guest', // imported presentation code, a domain list aside
        'host>inPart', // a child route in a part file inherits the guard
        'host>nav', // an import that only names the page is a way there
      ]);
    });

    test('a surface outside, a requires chain, a sheet used elsewhere and '
        'an account route are not candidates', () {
      final found = screenGates(_screenRegistry, files).join(' ');
      for (final quiet in ['shared', 'child', 'sheetOnly', 'acctTip']) {
        expect(found, isNot(contains('>$quiet')), reason: quiet);
      }
    });

    test('the report carries them as a ratcheted finding', () {
      final report = audit(
        registry: _screenRegistry,
        files: files,
        serverByFunction: const {},
        serverOutside: const {},
      );
      expect(
        report.findings['screenGates'],
        screenGates(_screenRegistry, files),
      );
    });
  });

  group('the tool finds each finding type', () {
    late AuditReport report;
    setUpAll(() => report = _synthetic());

    test('a dead flag is a registered key nothing gates on', () {
      expect(report.deadFlags, ['dead']);
    });

    test('a nested double gate is an if inside an if, or an &&', () {
      expect(report.doubleGates, [
        'alpha>beta@lib/x.dart',
        'gamma>delta@lib/x.dart',
      ]);
    });

    test(
      'a negated guard does not nest, and a requires chain is not a candidate',
      () {
        expect(report.doubleGates.join(), isNot(contains('zeta')));
        expect(report.doubleGates.join(), isNot(contains('child')));
      },
    );

    test('a server gate on an unregistered key is a finding; the latest '
        'definition of a function wins', () {
      expect(report.unregisteredServerKeys, ['unregistered']);
      expect(report.serverGates.keys, isNot(contains('oldKey')));
      expect(report.serverGates['alpha'], ['gate_old']);
      expect(report.serverGates.keys, contains('beta')); // a policy
    });

    test('a file the parser rejects is reported, not audited as whole', () {
      final broken = gatesOfSource('lib/y.dart', 'void f( {');
      expect(broken.errors, isNotEmpty);
    });
  });

  group('the baseline holds the findings of the tree', () {
    late AuditReport report;
    late Map<String, Map<String, String>> baseline;

    setUpAll(() {
      report = auditTree()!;
      baseline = readBaseline(File(baselinePath).readAsStringSync());
    });

    test('the tool is deterministic', () {
      expect(jsonEncode(auditTree()!.toJson()), jsonEncode(report.toJson()));
    });

    test('docs/design/FEATURE_AUDIT_BASELINE.json equals the tool output, '
        'every entry with a reviewed reason', () {
      expect(baselineDrift(report.findings, baseline), isEmpty);
    });

    test('a dead flag added to the tree fails the gate', () {
      final drift = baselineDrift({
        ...report.findings,
        'deadFlags': [...report.deadFlags, 'tempDeadFlag'],
      }, baseline);
      expect(drift.single, contains('deadFlags: NEW tempDeadFlag'));
    });

    test('a new screen gate fails the gate, and one that is gone must '
        'leave the baseline', () {
      final added = baselineDrift({
        ...report.findings,
        'screenGates': [...report.screenGates, 'memberPage>tempScreenGate'],
      }, baseline);
      expect(
        added.single,
        contains('screenGates: NEW memberPage>tempScreenGate'),
      );
      final gone = baselineDrift({
        ...report.findings,
        'screenGates': const <String>[],
      }, baseline);
      expect(gone, hasLength(baseline['screenGates']!.length));
      expect(gone.join('\n'), contains('GONE memberPage>vatCounterparty'));
    });

    test('a finding that is gone must leave the baseline', () {
      final drift = baselineDrift({
        ...report.findings,
        'deadFlags': const <String>[],
      }, baseline);
      // Every dead flag in the baseline is gone from this tree: one line each.
      expect(drift, hasLength(1));
      expect(drift.join('\n'), contains('GONE siteDocuments'));
    });
  });
}
