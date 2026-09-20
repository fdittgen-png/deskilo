// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — answering a recurring expense, where the AMOUNT decides what
// the write means.
//
// At the amount the validators already approved, the occurrence is born
// settled. At any other amount it is a new claim: an explanation is
// mandatory and it goes back through the expense validation. A rejected
// occurrence is always a resend, so it always needs one.
//
// All of that lived in a card widget: `differs` was computed in
// `build`, the refusal was a snackbar inside `_confirm`, and the
// sentence the person reads afterwards was chosen from the same boolean
// re-derived a second time. Which means the rule was stated three times
// and checked nowhere — and the missing-explanation branch never
// reached the repository only because the widget remembered to return.
// Here the COMMAND refuses, so the write cannot happen without the
// reason whatever a future caller forgets.
import '../domain/expense_schedule.dart';
import '../domain/money_repository.dart';

/// What answering an occurrence at a given amount means.
enum OccurrenceAnswer {
  /// No amount to answer with: nothing was asked, so nothing is written.
  noAmount,

  /// A different amount, and no explanation. REFUSED — the validators
  /// would receive a changed figure with nothing to judge it by.
  explanationMissing,

  /// A different amount with its explanation: filed, and it counts once
  /// the validators confirm.
  forValidation,

  /// The validated amount: settled on the spot.
  settled,
}

/// Whether answering [occurrence] with [amountCents] needs one.
///
/// The card asks this to decide whether to SHOW the explanation field,
/// the command asks it to decide whether to write — one sentence read
/// twice rather than two conditions that can drift apart.
bool needsExplanation(ExpenseOccurrence occurrence, int? amountCents) {
  if (occurrence.status == OccurrenceStatus.rejected) return true;
  final scheduled = occurrence.scheduledAmountCents;
  return scheduled != null && amountCents != null && amountCents != scheduled;
}

/// What answering [occurrence] with [amountCents] and [reason] means.
OccurrenceAnswer occurrenceAnswer({
  required ExpenseOccurrence occurrence,
  required int? amountCents,
  required String reason,
}) {
  if (amountCents == null || amountCents <= 0) return OccurrenceAnswer.noAmount;
  if (!needsExplanation(occurrence, amountCents)) {
    return OccurrenceAnswer.settled;
  }
  return reason.trim().isEmpty
      ? OccurrenceAnswer.explanationMissing
      : OccurrenceAnswer.forValidation;
}

/// Whether a schedule may still be ended.
///
/// A rejected or already-ended schedule has nothing left to stop, and
/// the button that offers it and the write that performs it read the
/// same sentence here rather than each their own condition.
bool canEndSchedule(ScheduleStatus status) =>
    status == ScheduleStatus.pending || status == ScheduleStatus.active;

/// A schedule needs a name and an amount above zero.
///
/// Not a formality: a nameless recurring line reappears every month with
/// nothing to recognise it by, and a zero amount schedules nothing.
bool isSchedulable({required String title, required int? amountCents}) =>
    title.trim().isNotEmpty && amountCents != null && amountCents > 0;

/// Recurring expenses, as the decisions behind them.
class ExpenseSchedules {
  const ExpenseSchedules(this._money);

  final MoneyRepository _money;

  /// Schedules a recurring expense; false when it was refused and
  /// NOTHING was written.
  Future<bool> schedule({
    required String workspaceId,
    required String title,
    required int? amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    if (!isSchedulable(title: title, amountCents: amountCents)) return false;
    await _money.createExpenseSchedule(
      workspaceId: workspaceId,
      title: title.trim(),
      amountCents: amountCents!,
      startsOn: startsOn,
      unit: unit,
      every: every,
      repeatCount: repeatCount,
      endsOn: endsOn,
      description: description,
    );
    return true;
  }

  /// Ends [schedule]; false when there was nothing left to end.
  Future<bool> end(ExpenseSchedule schedule) async {
    if (!canEndSchedule(schedule.status)) return false;
    await _money.cancelExpenseSchedule(schedule.id);
    return true;
  }

  /// Answers [occurrence], and says which answer it was.
  ///
  /// Nothing is written for [OccurrenceAnswer.noAmount] or
  /// [OccurrenceAnswer.explanationMissing]: the refusal is the command's,
  /// not the widget's.
  Future<OccurrenceAnswer> answer({
    required ExpenseOccurrence occurrence,
    required int? amountCents,
    required String reason,
  }) async {
    final answer = occurrenceAnswer(
      occurrence: occurrence,
      amountCents: amountCents,
      reason: reason,
    );
    if (answer == OccurrenceAnswer.noAmount ||
        answer == OccurrenceAnswer.explanationMissing) {
      return answer;
    }
    await _money.confirmExpenseOccurrence(
      occurrenceId: occurrence.id,
      amountCents: amountCents!,
      reason: reason.trim(),
    );
    return answer;
  }
}
