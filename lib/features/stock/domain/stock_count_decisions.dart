// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4402 -- who may decide a count, said once and the way the server decides it (0870,
// `stock_count_decide_v1`): only a count still recorded is decided; someone who may approve stock adjustments
// applies it (not while it is stale: the stock moved since it was counted) or rejects it; it is cancelled by
// someone who may approve, or by its own author while they manage the stock. The screens offer exactly these
// decisions, so a button is never one the server refuses for who is asking.
import 'stock_reversals.dart';

class StockCountDecisions {
  const StockCountDecisions({required this.mayApprove, required this.mayManage, this.memberId});

  /// The member may approve stock adjustments.
  final bool mayApprove;

  /// The member manages the stock.
  final bool mayManage;

  /// The member who asks, when known: the author of a count may cancel it.
  final String? memberId;

  /// The decisions offered on [count], in the order they are shown.
  List<StockCountDecision> on(StockCountRow count) => count.state != StockCountState.recorded
      ? const []
      : [
          if (mayApprove && !count.stale) StockCountDecision.apply,
          if (mayApprove) StockCountDecision.reject,
          if (mayApprove || (mayManage && memberId != null && count.authorMemberId == memberId))
            StockCountDecision.cancel,
        ];
}
