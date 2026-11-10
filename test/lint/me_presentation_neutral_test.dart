// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3548 -- Me is neutral to the business type: its presentation reads
// `PersonalCommitment`, never a reservation, a floor plan or the editor. The
// one seam is `lib/features/me/application/personal_commitments.dart`.
// Counted, pinned at 0.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

void main() {
  test('Me presentation imports nothing from reservations, plan or editor', () {
    final hits = scanLines(
      handWrittenDartFiles('lib/features/me/presentation'),
      (line) =>
          line.trimLeft().startsWith('import') &&
          RegExp(r"/(reservations|plan|editor)/").hasMatch(line),
    );
    expect(
      hits,
      isEmpty,
      reason: 'Me reads commitments through application/personal_commitments.dart '
          '(#3548):\n${hits.join('\n')}',
    );
  });
}
