// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3329 -- code moved into a package must not silently leave CI: every
// package with a test/ folder is run by quality.yml, either by a step that
// names it or by the jurisdiction loop.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('every packages/* with tests is run by quality.yml', () {
    final workflow = File('.github/workflows/quality.yml').readAsStringSync();
    final loop = workflow.contains('packages/deskilo_jurisdiction_*/');
    final unrun = <String>[];
    for (final name in directoryNames('packages')) {
      if (!directoryAt('packages/$name/test').existsSync()) continue;
      final named = workflow.contains('working-directory: packages/$name');
      final looped = loop && name.startsWith('deskilo_jurisdiction_');
      if (!named && !looped) unrun.add(name);
    }
    expect(
      unrun,
      isEmpty,
      reason: 'packages with tests that no quality.yml step runs',
    );
  });

  test('the specialist workflows watch the jurisdiction packages', () {
    for (final f in [
      'vat-filing-validate',
      'einvoice-validate',
      'saft-validate',
    ]) {
      final text = File('.github/workflows/$f.yml').readAsStringSync();
      expect(
        text,
        contains("'packages/deskilo_jurisdiction_*/**'"),
        reason: '$f.yml must trigger on a change to a jurisdiction package',
      );
    }
  });
}
