// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1446 — a required status context that no job emits jams every pull
// request.
//
// `scripts/branch_protection.sh` carries `TARGET_CHECKS`: the contexts
// master should require. GitHub matches a required context by its
// STRING, against the `name:` a workflow job publishes. So the two are
// one coupling with nothing holding it together — rename a job in
// `quality.yml` and the script goes on naming a context that will never
// arrive. Nobody finds out until an owner runs `apply`, and then every
// PR is unmergeable, waiting for a check that cannot report.
//
// The script's own header says as much about the first one:
//
//   it kept this name when ci.yml folded into `CI · Quality report`,
//   because the name IS the required context and a rename makes every
//   pull request unmergeable until protection is updated in lockstep.
//
// That is a comment. This is the check.
//
// It deliberately does NOT read the live settings: an API call needs a
// token, and #1446 is explicit that unreadable settings are not green
// enforcement evidence. What a test can prove offline is that the
// committed target is internally consistent — which is the half that
// breaks by accident.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The contexts `branch_protection.sh` would require.
List<String> _targetChecks() {
  final sh = File('scripts/branch_protection.sh').readAsStringSync();
  final block = RegExp(r'TARGET_CHECKS=\((.*?)\n\)', dotAll: true)
      .firstMatch(sh)
      ?.group(1);
  expect(block, isNotNull,
      reason: 'TARGET_CHECKS is the list this lint exists to guard; if it '
          'moved, the guard is measuring nothing');
  return RegExp(r'^\s*"([^"]+)"\s*$', multiLine: true)
      .allMatches(block!)
      .map((m) => m.group(1)!)
      .toList();
}

/// Every `name:` a job in [workflow] publishes.
Set<String> _jobNames(String workflow) => RegExp(r'^\s{4}name:\s*(.+?)\s*$',
        multiLine: true)
    .allMatches(File('.github/workflows/$workflow').readAsStringSync())
    .map((m) => m.group(1)!)
    .toSet();

void main() {
  test('the list this lint guards is still there and still has entries', () {
    expect(_targetChecks(), isNotEmpty,
        reason: 'an empty parse would make every assertion below vacuous');
  });

  test('every required context is a job some workflow actually emits', () {
    final emitted = <String>{
      for (final file in Directory('.github/workflows')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml')))
        ..._jobNames(file.uri.pathSegments.last),
    };

    final missing =
        _targetChecks().where((c) => !emitted.contains(c)).toList();

    expect(
      missing,
      isEmpty,
      reason: 'these contexts would be REQUIRED on master and no job '
          'publishes them:\n  ${missing.join('\n  ')}\n\n'
          'GitHub matches a required context by its exact string. A '
          'context nothing emits never reports, so every pull request '
          'waits for it forever. Rename the job and the script in the '
          'same commit, or do not rename it.',
    );
  });

  test('the one context master requires today is among them', () {
    // The branch API reports only this one as required (#1446). It is
    // the one that must never drift, because it is load-bearing right
    // now rather than aspirationally.
    expect(
      _targetChecks(),
      contains('analyze · l10n gate · test · coverage'),
      reason: 'dropping it from the target list would make `apply` '
          'REMOVE the only protection master has',
    );
  });

  test('the complete quality result is targeted, not just the code half',
      () {
    // #1446: the code job passing is not the run passing. On 2026-09-20
    // four pull requests merged with `quality · database` and
    // `quality · report` red, because only the first of the three was
    // ever applied. Dropping either from the target would make the gap
    // permanent by making it invisible.
    expect(
      _targetChecks(),
      containsAll(const ['quality · database', 'quality · report']),
      reason: 'the database replay and the report that carries the '
          'complete table must be required, or a red one merges',
    );
  });

  test('the required-check list can be applied without resetting the rest',
      () {
    // A PUT of the whole protection object sends null reviews and null
    // restrictions, so applying the check list would silently drop any
    // other protection. There has to be a command that changes only the
    // list, or nobody will dare run one.
    final sh = File('scripts/branch_protection.sh').readAsStringSync();
    expect(sh, contains('apply-checks'));
    expect(sh, contains(r'-X PATCH "${API}/required_status_checks"'),
        reason: 'apply-checks must PATCH the sub-resource; a PUT on the '
            'protection object is the blunt command it exists to avoid');
  });

  test('a required context that waits on another job is always evaluated '
      '(#1446 C2)', () {
    // A job with `needs:` and no `if: always()` is SKIPPED when a job it
    // waits on fails — and a skipped required context counts as passing.
    // So a classify job that died would have skipped the database job,
    // and a database job that died would have skipped the report: the
    // two contexts meant to catch a failure would have vanished from
    // the pull request instead of going red.
    final source = File('.github/workflows/quality.yml').readAsStringSync();
    for (final context in _targetChecks()) {
      final job = RegExp(
        '^  [a-z_]+:\n(?:    .*\n)*?    name: ${RegExp.escape(context)}\n((?:    .*\n)*?)    steps:',
        multiLine: true,
      ).firstMatch(source);
      expect(job, isNotNull, reason: '$context is not a job of quality.yml');
      final header = job!.group(1)!;
      if (!header.contains('needs:')) continue;
      expect(header, contains('if: always()'),
          reason: '`$context` has `needs:` but no `if: always()` — a '
              'failed dependency would skip it, and skipped is green');
    }
  });

  test('the check can fail — a context nothing emits is caught', () {
    // The guard on the guard: if the job-name parse silently returned
    // nothing, the test above would pass on an empty set and prove the
    // opposite of what it claims.
    final emitted = _jobNames('quality.yml');
    expect(emitted, contains('analyze · l10n gate · test · coverage'),
        reason: 'the workflow parse found no job names, so the emptiness '
            'above would have been meaningless');
    expect(emitted, isNot(contains('a context nobody emits')));
  });
}
