// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';

/// #2380 — a payment credit booked on the wrong member, moved to the right
/// one (0688): the original stays, the wrong member gets a reversal and the
/// right one a new credit, both in the credit's month.
class CreditMove {
  const CreditMove({
    required this.id,
    required this.reversalId,
    required this.creditId,
    this.replayed = false,
  });

  factory CreditMove.fromJson(Map<String, Object?> json) {
    final r = JsonReader(json, context: 'credit move');
    return CreditMove(
      id: r.string('id'),
      reversalId: r.string('reversal_id'),
      creditId: r.string('credit_id'),
      replayed: r.boolOr('replayed', fallback: false),
    );
  }

  final String id;

  /// The charge that takes the credit back from the wrong member.
  final String reversalId;

  /// The credit the right member now holds.
  final String creditId;

  /// The same request answered before: nothing was moved again.
  final bool replayed;
}

/// Moves a payment credit; the server checks the right, the credit, the
/// member and the books, and says why not in a refusal.
abstract interface class CreditMoveRepository {
  /// The same [requestId] again answers the same move.
  Future<CreditMove> moveCredit({
    required String creditId,
    required String toMemberId,
    required String reason,
    required String requestId,
  });
}

/// The longest reason the server keeps (0688).
const creditMoveReasonWidth = 300;
