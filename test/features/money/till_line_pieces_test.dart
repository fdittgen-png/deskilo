// SPDX-License-Identifier: AGPL-3.0-or-later
// #4373 review of #4366/#4436 -- a till line keeps its scanned pieces only while its quantity is exactly their number: a tap on the
// item's key or a typed quantity must not leave a line whose pieces the server refuses (DKG25) after the cash was taken.
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const plain = TillLine(itemId: 'cheese', name: 'Cheese', quantity: '0', unit: 'piece');

  test('scanning a piece names it and counts it', () {
    final line = plain.withPiece('T1').withPiece('T2');
    expect(line.pieces, ['T1', 'T2']);
    expect(line.quantity, '2');
  });

  test('the same quantity as the pieces keeps them', () {
    final line = plain.withPiece('T1').withPiece('T2');
    expect(line.withQuantity('2').pieces, ['T1', 'T2']);
  });

  test('another quantity (one more by the key, or a typed one) leaves a plain quantity, never pieces that do not add up', () {
    final line = plain.withPiece('T1').withPiece('T2');
    final more = line.withQuantity('3');
    expect(more.pieces, isEmpty);
    expect(more.quantity, '3');
    expect(line.withQuantity('1').pieces, isEmpty);
    expect(line.withQuantity('2.5').pieces, isEmpty);
  });
}
