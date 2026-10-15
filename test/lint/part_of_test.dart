// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2491 — `part of` does not grow.
//
// A `part` split makes a smaller file, not a smaller responsibility: the
// pieces share one library, one namespace and one reading order, and the
// metrics treat each as a file of its own. A split must create a class, a
// widget or a function with its own responsibility. The count may fall (a
// part that becomes a real file lowers it, and the failure says to write
// the new number) and never rise.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// `part of` files under lib/ (2026-10-13).
const int _partOfFiles = 76;

void main() {
  test('the number of `part of` files under lib/ only falls (#2491)', () {
    final partOf = RegExp(r'^part of ', multiLine: true);
    final files = [
      for (final f in handWrittenDartFiles('lib'))
        if (partOf.hasMatch(f.readAsStringSync())) f.path,
    ]..sort();
    expect(files.length, lessThanOrEqualTo(_partOfFiles),
        reason: 'a new `part of` file. Create a class, widget or function '
            'with its own responsibility instead. Files now: '
            '${files.length}, ceiling $_partOfFiles.');
    expect(files.length, _partOfFiles,
        reason: 'fewer `part of` files than the ceiling: set _partOfFiles '
            'to ${files.length} in test/lint/part_of_test.dart');
  });
}
