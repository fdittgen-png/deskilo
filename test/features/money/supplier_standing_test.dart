// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3070 — what a supplier cost this year and its last bill: approved bills
// add, credit notes take away, receipts and other states never count, and a
// second currency is not added to the first.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/supplier_standing.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseSummary _doc(
  String id, {
  required String supplier,
  required int cents,
  required DateTime on,
  PurchaseKind kind = PurchaseKind.bill,
  PurchaseState state = PurchaseState.approved,
  String currency = 'EUR',
}) => PurchaseSummary(
  id: id,
  kind: kind,
  state: state,
  category: '',
  reference: id,
  currency: currency,
  grossCents: cents,
  receivedOn: on,
  supplierId: supplier,
);

void main() {
  final standings = supplierStandings([
    _doc('a', supplier: 's1', cents: 10000, on: DateTime(2026, 3, 1)),
    _doc('b', supplier: 's1', cents: 5000, on: DateTime(2026, 9, 10)),
    _doc(
      'c',
      supplier: 's1',
      cents: 2000,
      on: DateTime(2026, 9, 20),
      kind: PurchaseKind.creditNote,
    ),
    _doc('d', supplier: 's1', cents: 9999, on: DateTime(2025, 12, 30)),
    _doc(
      'e',
      supplier: 's1',
      cents: 7777,
      on: DateTime(2026, 10, 1),
      state: PurchaseState.draft,
    ),
    _doc(
      'f',
      supplier: 's1',
      cents: 100,
      on: DateTime(2026, 10, 2),
      kind: PurchaseKind.memberReceipt,
    ),
    _doc(
      'g',
      supplier: 's1',
      cents: 400,
      on: DateTime(2026, 2, 1),
      currency: 'CHF',
    ),
    _doc('h', supplier: 's2', cents: 300, on: DateTime(2026, 1, 5)),
  ], year: 2026);

  test('a supplier\'s year is its bills less its credit notes', () {
    expect(standings['s1']!.yearGrossCents, 13000);
    expect(standings['s1']!.currency, 'EUR');
  });

  test('the last bill is the newest approved bill, not a credit note', () {
    expect(standings['s1']!.lastBillOn, DateTime(2026, 9, 10));
  });

  test('another supplier is its own line', () {
    expect(standings['s2']!.yearGrossCents, 300);
    expect(standings['s2']!.lastBillOn, DateTime(2026, 1, 5));
  });

  test('a document with no supplier is nobody\'s', () {
    expect(
      supplierStandings([
        PurchaseSummary(
          id: 'x',
          kind: PurchaseKind.bill,
          state: PurchaseState.approved,
          category: '',
          reference: 'x',
          currency: 'EUR',
          grossCents: 1,
          receivedOn: DateTime(2026, 1, 1),
        ),
      ], year: 2026),
      isEmpty,
    );
  });
}
