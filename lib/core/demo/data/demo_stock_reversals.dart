// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4172 (B) -- the Demo's returns, corrections and counts, behind the same
// port as the server's and on the Demo's ONE ledger: a part of a sale comes
// back from the customer to a real place (#4173), a part of a delivery goes
// back to its supplier or is undone by a correction, each bounded by the
// movement it reverses; a count records what was observed and waits for an
// approval, which applies exactly its difference and only if the stock has not
// moved since. A logical return or count sent again answers what it recorded;
// other content under the same identity is refused. What a command refuses, it
// refuses whole and moves nothing. Nothing leaves the process.
import 'package:deskilo/features/stock/domain/stock_reversal_book.dart';
import 'package:deskilo/features/stock/domain/stock_reversals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../codes/dk_code.dart';
import 'demo_stock_ledger.dart';

const _owner = 'demo-member-owner';

/// The in-memory returns and counts of the reference business: the rules are the domain ledger's (#4403). A
/// refusal leaves as the server's own (its code and message), as the real adapter reads it.
class DemoStockReversals implements StockReversals {
  DemoStockReversals(this._ledger) : _book = StockReversalBook(_ledger.core);

  final DemoStockLedger _ledger;
  final StockReversalBook _book;
  final Map<String, StockReturnResult> _answers = {};

  T _run<T>(String workspaceId, String code, String message, T Function(StockReversalBook book) run) {
    if (!_ledger.mine(workspaceId)) throw PostgrestException(message: message, code: code);
    try {
      return run(_book);
    } on StockCodeRefused catch (e, st) {
      Error.throwWithStackTrace(PostgrestException(message: e.message, code: e.code), st);
    }
  }

  @override
  Future<Map<String, StockReversible>> reversible(String workspaceId, List<String> movementIds) async =>
      _ledger.mine(workspaceId) ? _book.reversible(movementIds) : const {};

  @override
  Future<StockReturnResult> makeReturn(
    String workspaceId,
    String returnId,
    StockReturnKind kind,
    List<StockReturnLineDraft> lines,
    String requestId,
  ) async =>
      _answers[requestId] ??= _run(workspaceId, DkCode.dkg07, 'a return has lines', (book) => book.makeReturn(returnId, kind, lines));

  @override
  Future<List<StockCountRow>> counts(String workspaceId) async => _ledger.mine(workspaceId) ? _book.counts : const [];

  @override
  Future<void> recordCount(String workspaceId, StockCountDraft draft) async =>
      _run(workspaceId, DkCode.dkg07, 'a count has an identity and a scope', (book) => book.recordCount(draft, author: _owner));

  @override
  Future<void> decideCount(
    String workspaceId,
    String countId,
    StockCountDecision decision,
    String requestId, {
    String note = '',
  }) async =>
      _run(workspaceId, DkCode.dkg04, 'not a count of this business', (book) => book.decideCount(countId, decision, decider: _owner));
}
