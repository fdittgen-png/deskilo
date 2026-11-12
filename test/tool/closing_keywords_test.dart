// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3675 -- scripts/closing_keywords.sh, which scripts/merge_check.sh uses to
// refuse a pull request whose BODY closes an issue its TITLE does not. #3802
// referred to #3675 in its title and said in its body that "the second pull
// request ... closes #3675"; GitHub closed #3675 at the merge.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The issues [body] closes that [title] does not, as the script answers.
List<String> strayCloses(String title, String body) {
  final result = Process.runSync('bash', [
    '-c',
    'source scripts/closing_keywords.sh && stray_closes "\$1" "\$2"',
    'closing_keywords',
    title,
    body,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return [
    for (final line in '${result.stdout}'.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
}

void main() {
  test(
    'the #3802 slip: a body sentence closes an issue the title only refers to',
    () {
      expect(
        strayCloses(
          'feat(badges): a business enrols its kiosks (Refs #3675)',
          'The second pull request brings the screens. It closes #3675.\n\nRefs #3675',
        ),
        ['3675'],
      );
    },
  );

  test('a body that closes what the title closes is fine', () {
    expect(
      strayCloses(
        'feat(payments): the settlements are read hourly (Closes #3510)',
        'What it does.\n\nCloses #3510',
      ),
      isEmpty,
    );
  });

  test('every keyword GitHub reads, in any case and with a colon, is seen', () {
    for (final keyword in [
      'close',
      'closes',
      'closed',
      'fix',
      'fixes',
      'fixed',
      'resolve',
      'resolves',
      'resolved',
      'CLOSES',
      'Fixes:',
    ]) {
      expect(strayCloses('docs: a note (Refs #1)', '$keyword #42'), [
        '42',
      ], reason: keyword);
    }
  });

  test('a reference without a closing keyword closes nothing', () {
    expect(
      strayCloses('docs: a note (Refs #1)', 'Refs #42. See #43; follows #44.'),
      isEmpty,
    );
  });

  test('only the issues the title does not close are named', () {
    expect(
      strayCloses(
        'fix: two things (Closes #10, Closes #11)',
        'Closes #10\nCloses #11\nFixes #12',
      ),
      ['12'],
    );
  });
}
