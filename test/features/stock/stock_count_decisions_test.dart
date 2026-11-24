// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402 -- the decisions a count offers are the ones the server takes from who asks (0870): an approver applies
// a count that is not stale, rejects it and cancels it; its author cancels it while they manage the stock; a
// stock manager who did not count it decides nothing; a count already decided offers nothing.
import 'package:deskilo/features/stock/domain/stock_count_decisions.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter_test/flutter_test.dart';

StockCountRow _count({StockCountState state = StockCountState.recorded, bool stale = false}) => StockCountRow(
  countId: 'c-1',
  itemId: 'i-1',
  locationId: 'p-1',
  observed: ExactQuantity.parse('9'),
  baseline: ExactQuantity.parse('10'),
  state: state,
  authorMemberId: 'm-author',
  stale: stale,
);

void main() {
  test('an approver applies, rejects and cancels; a stale count is not applied', () {
    const approver = StockCountDecisions(mayApprove: true, mayManage: true, memberId: 'm-other');
    expect(approver.on(_count()), [StockCountDecision.apply, StockCountDecision.reject, StockCountDecision.cancel]);
    expect(approver.on(_count(stale: true)), [StockCountDecision.reject, StockCountDecision.cancel]);
  });

  test('the author cancels their own count; another stock manager decides nothing', () {
    expect(const StockCountDecisions(mayApprove: false, mayManage: true, memberId: 'm-author').on(_count()), [
      StockCountDecision.cancel,
    ]);
    expect(const StockCountDecisions(mayApprove: false, mayManage: true, memberId: 'm-other').on(_count()), isEmpty);
    expect(
      const StockCountDecisions(mayApprove: false, mayManage: true).on(_count()),
      isEmpty,
      reason: 'who asks is not known yet',
    );
    expect(
      const StockCountDecisions(mayApprove: false, mayManage: false, memberId: 'm-author').on(_count()),
      isEmpty,
      reason: 'an author who no longer manages the stock',
    );
  });

  test('a count already decided offers nothing', () {
    const approver = StockCountDecisions(mayApprove: true, mayManage: true, memberId: 'm-author');
    for (final s in [
      StockCountState.applied,
      StockCountState.rejected,
      StockCountState.cancelled,
      StockCountState.unknown,
    ]) {
      expect(approver.on(_count(state: s)), isEmpty, reason: '$s');
    }
  });
}
