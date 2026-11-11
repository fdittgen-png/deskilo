// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3094 — CI supply chain and workflow hygiene, as ratchets: each count may
// only fall, and a new workflow or step may not add to it.
//
//   * a third-party action (not `actions/*`, not local) pinned by tag or
//     branch instead of a full commit SHA (G2): a tag can be moved;
//   * a workflow with no top-level `permissions:` (G4): it runs with the
//     repository's default token rights;
//   * an input or branch-ref expression inside a `run:` block: the value is
//     pasted into the script, so a crafted value is a command.
//
// Lower the number when you fix one; never raise it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Third-party actions not yet pinned by SHA.
const int _unpinnedThirdPartyActions = 0;

/// Workflows without a top-level `permissions:` block.
const int _workflowsWithoutPermissions = 0;

/// Lines with an input or branch-ref expression inside a `run:` block.
const int _untrustedInsideRun = 0;

List<File> _workflowFiles() => filesWithExtension('.github/workflows', '.yml');

List<File> _allActionFiles() => [
  ..._workflowFiles(),
  for (final f in filesWithExtension('.github/actions', '.yml', recursive: true))
    if (f.path.endsWith('action.yml')) f,
];

void main() {
  test('third-party actions pinned by SHA only fall', () {
    var unpinned = 0;
    final uses = RegExp(r'^\s*-?\s*uses:\s*([^\s#]+)', multiLine: true);
    for (final f in _allActionFiles()) {
      for (final m in uses.allMatches(f.readAsStringSync())) {
        final ref = m.group(1)!;
        if (ref.startsWith('./') || ref.startsWith('actions/')) continue;
        if (!RegExp(r'@[0-9a-f]{40}$').hasMatch(ref)) unpinned++;
      }
    }
    expect(
      unpinned,
      lessThanOrEqualTo(_unpinnedThirdPartyActions),
      reason: 'a new third-party action must be pinned by its full commit '
          'SHA; $unpinned unpinned > $_unpinnedThirdPartyActions',
    );
  });

  test('workflows without top-level permissions only fall', () {
    final without = [
      for (final f in _workflowFiles())
        if (!RegExp(r'^permissions:', multiLine: true)
            .hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(
      without.length,
      lessThanOrEqualTo(_workflowsWithoutPermissions),
      reason: 'add a top-level `permissions:` (contents: read at least): '
          '$without',
    );
  });

  test('inputs and branch refs pasted into a run block only fall', () {
    var hits = 0;
    final run = RegExp(r'^(\s*)(-\s*)?run:\s*(.*)$');
    final input = RegExp(
      r'\$\{\{\s*((github\.event\.)?inputs\.|github\.(base_ref|head_ref)\b)',
    );
    for (final f in _workflowFiles()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final m = run.firstMatch(lines[i]);
        if (m == null) continue;
        final indent = m.group(1)!.length + (m.group(2) != null ? 2 : 0);
        final body = [m.group(3)!];
        var j = i + 1;
        while (j < lines.length &&
            (lines[j].trim().isEmpty ||
                lines[j].length - lines[j].trimLeft().length > indent)) {
          body.add(lines[j]);
          j++;
        }
        for (final b in body) {
          if (b.trimLeft().startsWith('#')) continue;
          if (input.hasMatch(b)) hits++;
        }
        i = j - 1;
      }
    }
    expect(
      hits,
      lessThanOrEqualTo(_untrustedInsideRun),
      reason: 'pass inputs and branch refs through `env:` as "\$NAME": '
          '$hits > $_untrustedInsideRun',
    );
  });
}
