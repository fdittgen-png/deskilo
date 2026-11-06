// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../features/money/domain/credit_move.dart';
import '../../../../features/money/domain/ledger_entry.dart';
import '../money_repository.dart';

/// #2380 — move_payment_credit_v1 (0688) in the demo: over one space's
/// in-memory ledger, the original credit stays, the wrong member gets a
/// reversal and the right one a new credit in the same month; a credit is
/// moved once, and the same request id answers the same move.
class DemoCreditMoves implements CreditMoveRepository {
  DemoCreditMoves(this._m);

  final FakeMoneyRepository _m;
  final _done = <String, ({String creditId, CreditMove move})>{};

  static PostgrestException _refusal(String message) =>
      PostgrestException(message: message, code: '22023');

  @override
  Future<CreditMove> moveCredit({
    required String creditId,
    required String toMemberId,
    required String reason,
    required String requestId,
  }) async {
    final earlier = _done[requestId];
    if (earlier != null) {
      if (earlier.creditId != creditId) {
        throw _refusal(
          'this request id was already used for a different request',
        );
      }
      return CreditMove(
        id: earlier.move.id,
        reversalId: earlier.move.reversalId,
        creditId: earlier.move.creditId,
        replayed: true,
      );
    }
    if (reason.trim().isEmpty) throw _refusal('a reason is required');
    final credit = _m.ledger.where((e) => e.id == creditId).firstOrNull;
    if (credit == null ||
        credit.kind != LedgerKind.credit ||
        credit.category != LedgerCategory.payment) {
      throw _refusal('only a payment credit is moved');
    }
    if (_done.values.any((d) => d.creditId == creditId)) {
      throw _refusal('this credit was already moved');
    }
    if (credit.memberId == toMemberId) {
      throw _refusal('the credit is already on this member');
    }
    final n = _done.length + 1;
    final reversal = credit.copyWith(
      id: 'demo-move-reversal-$n',
      kind: LedgerKind.charge,
      category: LedgerCategory.adjustment,
      amountCents: credit.amountCents.abs(),
      description: reason.trim(),
    );
    final moved = credit.copyWith(
      id: 'demo-move-credit-$n',
      memberId: toMemberId,
    );
    _m.ledger.addAll([reversal, moved]);
    final move = CreditMove(
      id: 'demo-move-$n',
      reversalId: reversal.id,
      creditId: moved.id,
    );
    _done[requestId] = (creditId: creditId, move: move);
    return move;
  }

  @override
  Future<Set<String>> fetchMovedCreditIds(String workspaceId) async => {
    for (final d in _done.values) ...[d.creditId, d.move.reversalId],
  };
}
