// SPDX-License-Identifier: 0BSD
//
// Design-token lint: inline `BorderRadius.circular(n)` is banned in feature
// code — use the AppRadius tokens (spec §14, DESIGN_SYSTEM.md).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _exempt = ['lib/core/theme/app_radius.dart'];

void main() {
  test('no inline BorderRadius.circular outside AppRadius', () {
    final violations = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_exempt.contains(f.path))
        .where((f) => !f.path.contains('lib/l10n/'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('BorderRadius.circular(')) {
          violations.add('${file.path}:${i + 1}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Inline BorderRadius in: $violations — use AppRadius tokens.',
    );
  });
}
