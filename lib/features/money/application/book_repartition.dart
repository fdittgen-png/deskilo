// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1532 / #1449 — sharing a cost is two writes, and their ORDER is the
// decision.
//
// The wizard distributed the expense and then, if the owner ticked
// "remember", saved the rule. The two cannot be merged: the rule is
// workspace configuration, the distribution is a ledger line per member
// and its own validation event. So one of them can always be left
// behind, and the only question is which.
//
// Booking first was the wrong answer. A failure to save the rule left
// the expense ALREADY DISTRIBUTED, with the sheet still open on the same
// amounts and a message saying it had gone wrong — press Book again and
// every member is charged twice.
//
// The rule goes first. Its leftover is a remembered preference, which is
// what the owner asked for anyway, and the money is still unbooked, so
// pressing Book again books it exactly once.
//
// ADR 0024's shape, like `record_payment.dart`: pure Dart with the
// repository handed in, because the order is the whole behaviour and a
// rule that only a widget can exercise is a rule nothing checks.
import '../domain/expense_repartition.dart';
import '../domain/money_repository.dart';
import '../domain/workspace_status.dart';

/// What happened to a cost somebody tried to share.
sealed class BookRepartitionOutcome {
  const BookRepartitionOutcome();
}

/// Distributed. [id] is the repartition; [ruleRemembered] says whether
/// the rule was also saved for next time.
class RepartitionBooked extends BookRepartitionOutcome {
  const RepartitionBooked({required this.id, required this.ruleRemembered});
  final String id;
  final bool ruleRemembered;
}

/// Nothing was written at all, because the rule could not be saved.
///
/// Its own outcome rather than a rethrow: "nothing happened" is the
/// thing the caller has to be able to say, and it is only true because
/// the rule is written first.
class RepartitionNotBooked extends BookRepartitionOutcome {
  const RepartitionNotBooked(this.error);
  final Object error;
}

/// Saves [rule] when [remember], then distributes [amountCents] across
/// [shares].
///
/// Throws whatever the distribution throws: by then the money is the
/// caller's problem to report, and the rule — if any — is a harmless
/// leftover. Only the rule's own failure is folded into an outcome,
/// because that is the one that must leave nothing behind.
/// Sharing a cost, as the decisions behind it.
///
/// A class behind a provider rather than a free function (#1449): the
/// free form left every caller resolving the repository to hand it over,
/// so the widgets stayed counted and the point of the extraction was
/// only half made.
class Repartitions {
  const Repartitions(this._money);

  final MoneyRepository _money;

  /// Distributes [shares], then says whether they BOOKED or were merely
  /// FILED awaiting a validation rule.
  ///
  /// The second half is a decision and not a formality: the server
  /// answers one of two things, and which one changes what the person
  /// is told — *shares booked, they appear on the next usage invoice*
  /// against *shares filed, they book once validated*. The sheet
  /// discovered it by re-reading what it had just written, which is
  /// exactly the derivation that belongs with the rule rather than in a
  /// widget.
  Future<DistributedExpense> distribute({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
  }) async {
    final id = await _money.distributeExpense(
      workspaceId: workspaceId,
      title: title,
      amountCents: amountCents,
      method: method,
      period: period,
      shares: shares,
    );
    final filed = (await _money.fetchExpenseRepartitions(workspaceId))
        .where((r) => r.id == id)
        .firstOrNull;
    return DistributedExpense(id: id, pending: filed?.isPending ?? false);
  }

  /// The wizard's path: remember the rule, then move the money.
  Future<BookRepartitionOutcome> book({
    required String workspaceId,
    required String title,
    required int amountCents,
    required String period,
    required RepartitionRule rule,
    required List<RepartitionShare> shares,
    bool remember = true,
  }) =>
      bookRepartition(
        _money,
        workspaceId: workspaceId,
        title: title,
        amountCents: amountCents,
        period: period,
        rule: rule,
        shares: shares,
        remember: remember,
      );
}

/// A cost that reached the ledger, and whether it is waiting on a
/// validation rule before it counts.
class DistributedExpense {
  const DistributedExpense({required this.id, required this.pending});

  final String id;

  /// True when a validation policy holds the shares until somebody
  /// decides. The words a person reads depend on it.
  final bool pending;
}

Future<BookRepartitionOutcome> bookRepartition(
  MoneyRepository repository, {
  required String workspaceId,
  required String title,
  required int amountCents,
  required String period,
  required RepartitionRule rule,
  required List<RepartitionShare> shares,
  bool remember = true,
}) async {
  if (remember) {
    try {
      await repository.setRepartitionRule(workspaceId, rule);
      // ignore: catch_no_st
    } catch (e) {
      // trace-exempt: the error is carried out in the outcome and the
      // caller reports it; catching here is the point — nothing has
      // been distributed, so nothing is half-done.
      return RepartitionNotBooked(e);
    }
  }
  final id = await repository.distributeExpense(
    workspaceId: workspaceId,
    title: title,
    amountCents: amountCents,
    method: rule.method,
    period: period,
    shares: shares,
  );
  return RepartitionBooked(id: id, ruleRemembered: remember);
}
