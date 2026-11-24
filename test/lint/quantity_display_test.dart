// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4424 -- a quantity a member reads is formatted by `AppFormat.quantity`
// (`1,5 kg` in French, `1.5 kg` in English), not printed as the canonical
// dot-decimal `ExactQuantity.text`. The `.text` of a quantity getter in a
// screen is counted: some are still displays to sweep, some are the exact text
// a screen sends or prefills, and the count only falls. The counts screen and
// the stock lists show none.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// Recorded on the day the quantity format landed (51 before its first sweep).
const _ceiling = 45;

final _quantityText = LiteralKind(
  'quantity .text',
  RegExp(
    r'\b(onHand|observed|baseline|difference|remaining|reversed|reorderPoint|'
    r'targetQuantity|reorderQuantity|quantity|enteredQuantity|expected|counted)'
    r'!?\??\.text\b',
  ),
);

void main() {
  final files = filesUnder(['lib/features'])
      .where((f) => f.path.contains('/presentation/'));
  final perFile = countLiterals(files, [_quantityText])[_quantityText.name]!;

  test('the canonical text of a quantity in a screen only falls', () {
    expect(
      total(perFile),
      lessThanOrEqualTo(_ceiling),
      reason: ratchetMessage(
        rule: 'quantities (#4424): show AppFormat.quantity(q, unit: u), send q.text',
        kind: _quantityText.name,
        ceiling: _ceiling,
        actual: total(perFile),
        perFile: perFile,
      ),
    );
  });

  test('the stock list and the counts show no canonical quantity', () {
    expect(
      perFile['lib/features/stock/presentation/stock_screen.dart'] ?? 0,
      0,
    );
    // what remains there is the exact text the count sends
    expect(
      perFile['lib/features/stock/presentation/stock_counts_screen.dart'] ?? 0,
      1,
    );
  });

  test('the pattern sees a quantity getter and not a text field', () {
    expect(
      _quantityText.pattern.hasMatch(r"'${count.observed.text} $unit'"),
      isTrue,
    );
    expect(_quantityText.pattern.hasMatch('point?.reorderPoint.text'), isTrue);
    expect(_quantityText.pattern.hasMatch('fields.text(field)'), isFalse);
  });
}
