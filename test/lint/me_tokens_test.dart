// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3545 step 0 -- Me wears the personal theme and nothing else: no literal
// colour, font size or radius in lib/features/me/presentation. Counted at
// today's number, which only falls (the kit in presentation/kit adds none).
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';
import 'literal_ratchet.dart';

/// Ceilings (the measure of 2026-11-10; `Colors.` is transparent and friends).
const Map<String, int> _ceilings = {
  'Color(0x': 0,
  'Colors.': 6,
  'BorderRadius.circular(<number>)': 0,
  'TextStyle(fontSize:': 0,
};

void main() {
  test('Me presentation uses theme tokens, not literals (only falls)', () {
    final files = handWrittenDartFiles('lib/features/me/presentation');
    final kinds = [
      LiteralKind('Color(0x', RegExp(r'\bColor\(0x')),
      LiteralKind('Colors.', RegExp(r'\bColors\.')),
      LiteralKind(
        'BorderRadius.circular(<number>)',
        RegExp(r'BorderRadius\.circular\(\s*[0-9]'),
      ),
      LiteralKind('TextStyle(fontSize:', RegExp(r'TextStyle\(\s*fontSize:')),
    ];
    final counted = countLiterals(files, kinds);
    for (final k in kinds) {
      final perFile = counted[k.name]!;
      final actual = total(perFile);
      expect(
        actual,
        lessThanOrEqualTo(_ceilings[k.name]!),
        reason: ratchetMessage(
          rule: 'Me tokens (#3545)',
          kind: k.name,
          ceiling: _ceilings[k.name]!,
          actual: actual,
          perFile: perFile,
        ),
      );
      expect(
        actual,
        _ceilings[k.name],
        reason: 'record the win: lower the ceiling of ${k.name} to $actual',
      );
    }
  });
}
