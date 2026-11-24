// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4424 -- a quantity a member reads is formatted by `AppFormat.quantity`
// (`1,5 kg` in French, `1.5 kg` in English), not printed as the canonical
// dot-decimal `ExactQuantity.text`, and a field is prefilled in the member's
// format too (`AppFormat.quantity(q, grouped: false)`). The `.text` of a
// quantity getter in a screen is refused; the exact text a command's draft
// takes (a named argument) is what the server reads and stays.
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// 51 before the first sweep, 0 since #4424's.
const _ceiling = 0;

/// The canonical text of a quantity getter, unless it is the value of a named
/// argument (`quantity: q.text`): the text a command's draft takes.
final _quantityText = LiteralKind(
  'quantity .text',
  RegExp(
    r'(?<!\b\w+:\s{0,4})'
    r'\b(onHand|observed|baseline|difference|remaining|reversed|reorderPoint|'
    r'targetQuantity|reorderQuantity|quantity|enteredQuantity|expected|counted|putAway)'
    r'!?\??\.text\b',
  ),
);

void main() {
  final files = filesUnder(['lib/features'])
      .where((f) => f.path.contains('/presentation/'));
  final perFile = countLiterals(files, [_quantityText])[_quantityText.name]!;

  test('no screen shows the canonical text of a quantity', () {
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

  test('the pattern sees a quantity getter and not a text field', () {
    expect(
      _quantityText.pattern.hasMatch(r"'${count.observed.text} $unit'"),
      isTrue,
    );
    expect(_quantityText.pattern.hasMatch('point?.reorderPoint.text'), isTrue);
    expect(_quantityText.pattern.hasMatch('fields.text(field)'), isFalse);
    expect(_quantityText.pattern.hasMatch('quantity: quantity!.text,'), isFalse, reason: 'a draft takes the exact text');
  });
}
