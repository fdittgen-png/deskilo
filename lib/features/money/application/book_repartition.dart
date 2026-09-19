// SPDX-License-Identifier: 0BSD
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
