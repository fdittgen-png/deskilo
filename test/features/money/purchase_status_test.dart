// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C2 — approval, settlement and qualification of a purchase are three
// answers, never one: the issue's cleaning receipt of 1.20 is approved and
// owed, then settled by the credit on the member's account (never "paid");
// a document nobody is owed anything for says so.
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/purchase_status.dart';
import 'package:flutter_test/flutter_test.dart';

PurchaseDetail _detail({
  PurchaseState state = PurchaseState.approved,
  List<PurchaseObligation> owed = const [],
  List<PurchaseLine>? lines,
  bool legacy = false,
}) => PurchaseDetail(
  summary: PurchaseSummary(
    id: 'p-1',
    kind: PurchaseKind.memberReceipt,
    state: state,
    category: 'Cleaning',
    reference: '',
    currency: 'EUR',
    grossCents: 120,
    legacy: legacy,
  ),
  revision: 1,
  lines:
      lines ??
      const [
        PurchaseLine(
          lineNo: 1,
          description: 'Cleaning',
          grossCents: 120,
          netCents: 100,
          taxCents: 20,
          recoverableTaxCents: 20,
          recognitionKind: 'operating',
        ),
      ],
  sources: const [],
  obligations: owed,
);

PurchaseObligation _owed(int remaining) => PurchaseObligation(
  id: 'o-1',
  purchaseId: 'p-1',
  creditorKind: CreditorKind.member,
  creditorId: 'm-1',
  amountCents: 120,
  currency: 'EUR',
  appliedCents: 120 - remaining,
  remainingCents: remaining,
);

void main() {
  test('a receipt waiting for a decision owes nothing yet', () {
    final s = purchaseStatusOf(
      _detail(state: PurchaseState.pending, owed: [_owed(120)]),
    );
    expect(s.approval, PurchaseApproval.waiting);
    expect(s.settlement, PurchaseSettlement.nothingOwed);
  });

  test('approved and owed: unpaid, then partly, then settled — never '
      '"paid" because the member was credited', () {
    expect(
      purchaseStatusOf(_detail(owed: [_owed(120)])).settlement,
      PurchaseSettlement.unpaid,
    );
    expect(
      purchaseStatusOf(_detail(owed: [_owed(20)])).settlement,
      PurchaseSettlement.partlySettled,
    );
    expect(
      purchaseStatusOf(_detail(owed: [_owed(0)])).settlement,
      PurchaseSettlement.settled,
    );
    expect(
      purchaseStatusOf(_detail()).settlement,
      PurchaseSettlement.nothingOwed,
      reason: 'the space paid at once: nobody is owed',
    );
  });

  test('qualification: unverified, then an unclassified line, then an '
      'unstated recoverable share, else qualified', () {
    expect(
      purchaseStatusOf(_detail()).qualification,
      PurchaseQualification.qualified,
    );
    expect(
      purchaseStatusOf(_detail(legacy: true)).qualification,
      PurchaseQualification.unverified,
    );
    expect(
      purchaseStatusOf(
        _detail(
          lines: const [
            PurchaseLine(lineNo: 1, description: 'Box', grossCents: 120),
          ],
        ),
      ).qualification,
      PurchaseQualification.needsReview,
    );
    expect(
      purchaseStatusOf(
        _detail(
          lines: const [
            PurchaseLine(
              lineNo: 1,
              description: 'Cleaning',
              grossCents: 120,
              netCents: 100,
              taxCents: 20,
              recognitionKind: 'operating',
            ),
          ],
        ),
      ).qualification,
      PurchaseQualification.taxNotQualified,
    );
  });
}
