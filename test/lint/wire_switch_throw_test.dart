// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3884 -- the other spellings of the defect `wire_enum_test.dart` finds: a
// wire reader whose `switch` default arm (`_ => throw`) or `firstWhere`
// `orElse: () => throw` fails the WHOLE list for ONE value a newer server
// sends. A reader leaves the row out and says so (`UnreadableRows`) or reads
// the safe value and traces (`enumOr`).
//
// The readers below that still throw are counted, not excused: the ceiling
// only falls. Lowering it is the whole job of the next reader converted;
// raising it is a new defect.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The readers (data, domain, the money kernel; demo data excluded) that
/// still throw on a value they do not know. #3884 converted the reservation
/// status, the book chart, the postings and the personal references; #3913
/// the bank lines and statements; the rest are listed in its hand-over.
const int _throwingReaders = 7;

void main() {
  test('wire readers that throw on an unknown value only get fewer', () {
    bool inScope(String path) {
      final p = path.replaceAll('\\', '/');
      return !p.contains('lib/core/demo/') &&
          (p.contains('/data/') ||
              p.contains('/domain/') ||
              p.contains('deskilo_money_kernel/lib/'));
    }

    final hits = scanLines(
      [
        ...handWrittenDartFiles('lib').where((f) => inScope(f.path)),
        ...handWrittenDartFiles('packages/deskilo_money_kernel/lib'),
      ],
      (line) =>
          RegExp(r'_ => \(?throw\b').hasMatch(line) ||
          RegExp(r'orElse: \(\) => \(?throw\b').hasMatch(line),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_throwingReaders),
      reason:
          'a new reader that throws on an unknown wire value fails a whole '
          'list: leave the row out and count it (lib/core/data/'
          'unreadable_rows.dart) or read the safe value (enumOr):\n'
          '${hits.join('\n')}',
    );
    expect(
      hits.length,
      _throwingReaders,
      reason: 'a reader was converted: lower _throwingReaders to ${hits.length}',
    );
  });
}
