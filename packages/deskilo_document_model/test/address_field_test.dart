// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3981 — the address field is a function of the paper: A4 keeps the DIN
// 5008 / French millimetres, US Letter has the #10 window envelope's.
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:test/test.dart';

void main() {
  test('A4 keeps its millimetres', () {
    final left = AddressWindow.left.fieldOn(Paper.a4);
    expect(
      [
        left.leftMm,
        left.topMm,
        left.widthMm,
        left.heightMm,
        left.senderLimitMm,
        left.flowResumeMm,
      ],
      [20, 45, 85, 40, 45, 90],
    );
    expect(AddressWindow.right.fieldOn(Paper.a4).leftMm, 110);
  });

  test('Letter has one field, whatever side the design chose', () {
    for (final window in [AddressWindow.left, AddressWindow.right]) {
      final f = window.fieldOn(Paper.letter);
      expect(
        [
          f.leftMm,
          f.topMm,
          f.widthMm,
          f.heightMm,
          f.senderLimitMm,
          f.flowResumeMm,
        ],
        [25.4, 56, 83, 21, 50, 93],
      );
      expect(f.rightMm, closeTo(108.4, 1e-9));
      expect(f.bottomMm, 77);
    }
  });
}
