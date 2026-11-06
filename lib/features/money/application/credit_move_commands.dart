// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — a payment credit booked on the wrong member is moved, never
// edited. This refuses only what cannot be right before anything is sent;
// the server decides the rest (a matched credit, an invoiced month, a
// closed period) and says why in its refusal.
import '../domain/credit_move.dart';
import '../domain/ledger_entry.dart';

class CreditMoveCommands {
  const CreditMoveCommands(this._repository);

  final CreditMoveRepository _repository;

  /// Whether [entry] is a credit this action may move at all.
  static bool movable(LedgerEntry entry) =>
      entry.kind == LedgerKind.credit &&
      entry.category == LedgerCategory.payment;

  /// Moves [credit] to [toMemberId] for [reason] under [requestId]; null
  /// when nothing was sent: not a payment credit, the same member, or no
  /// reason. A reason longer than the server keeps is cut to it.
  Future<CreditMove?> move(
    LedgerEntry credit, {
    required String toMemberId,
    required String reason,
    required String requestId,
  }) async {
    final why = reason.trim();
    if (!movable(credit) ||
        toMemberId.isEmpty ||
        toMemberId == credit.memberId ||
        why.isEmpty) {
      return null;
    }
    return _repository.moveCredit(
      creditId: credit.id,
      toMemberId: toMemberId,
      reason: why.length <= creditMoveReasonWidth
          ? why
          : why.substring(0, creditMoveReasonWidth),
      requestId: requestId,
    );
  }

  /// #3349 — the credits already moved off a member, which no match may
  /// offer or take again.
  Future<Set<String>> movedCreditIds(String workspaceId) =>
      _repository.fetchMovedCreditIds(workspaceId);
}
