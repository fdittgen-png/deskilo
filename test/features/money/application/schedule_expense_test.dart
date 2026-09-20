// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the amount decides what answering a scheduled expense MEANS,
// and the command refuses the write the rule does not allow. The card
// used to state the rule three times and check it nowhere.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/features/money/application/schedule_expense.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

ExpenseOccurrence _occurrence({
  OccurrenceStatus status = OccurrenceStatus.awaitingMember,
}) =>
    ExpenseOccurrence(
      id: 'o-1',
      scheduleId: 's-1',
      workspaceId: 'ws-1',
      memberId: 'm-1',
      dueOn: DateTime.utc(2026, 9, 1),
      amountCents: 5000,
      scheduledAmountCents: 5000,
      status: status,
    );

ExpenseSchedule _schedule(ScheduleStatus status) => ExpenseSchedule(
      id: 's-1',
      workspaceId: 'ws-1',
      memberId: 'm-1',
      title: 'Internet',
      amountCents: 5000,
      startsOn: DateTime.utc(2026, 9, 1),
      unit: ScheduleUnit.month,
      status: status,
    );

FakeMoneyRepository _repo({
  ExpenseOccurrence? occurrence,
  ExpenseSchedule? schedule,
}) {
  final repo = FakeMoneyRepository();
  if (occurrence != null) repo.expenseOccurrences.add(occurrence);
  if (schedule != null) repo.expenseSchedules.add(schedule);
  return repo;
}

void main() {
  group('answering an occurrence', () {
    test('at the validated amount it is settled on the spot', () async {
      final repo = _repo(occurrence: _occurrence());
      expect(
        await ExpenseSchedules(repo)
            .answer(occurrence: _occurrence(), amountCents: 5000, reason: ''),
        OccurrenceAnswer.settled,
      );
      expect(repo.expenseOccurrences.single.status, OccurrenceStatus.added);
    });

    test('at a different amount WITHOUT an explanation nothing is written',
        () async {
      final repo = _repo(occurrence: _occurrence());
      expect(
        await ExpenseSchedules(repo).answer(
            occurrence: _occurrence(), amountCents: 6200, reason: '   '),
        OccurrenceAnswer.explanationMissing,
      );
      expect(repo.confirmedOccurrences, isEmpty,
          reason: 'the validators would receive a changed figure with '
              'nothing to judge it by');
    });

    test('at a different amount WITH one it goes for validation', () async {
      final repo = _repo(occurrence: _occurrence());
      expect(
        await ExpenseSchedules(repo).answer(
            occurrence: _occurrence(),
            amountCents: 6200,
            reason: ' the invoice rose '),
        OccurrenceAnswer.forValidation,
      );
      expect(repo.confirmedOccurrences.single.reason, 'the invoice rose');
      expect(repo.expenseOccurrences.single.status,
          OccurrenceStatus.pendingValidation);
    });

    test('a rejected one is a resend, so even the validated amount needs '
        'an explanation', () async {
      final rejected = _occurrence(status: OccurrenceStatus.rejected);
      final repo = _repo(occurrence: rejected);
      expect(
        await ExpenseSchedules(repo)
            .answer(occurrence: rejected, amountCents: 5000, reason: ''),
        OccurrenceAnswer.explanationMissing,
      );
      expect(repo.confirmedOccurrences, isEmpty);
    });

    test('no amount asks nothing, so nothing is written', () async {
      final repo = _repo(occurrence: _occurrence());
      expect(
        await ExpenseSchedules(repo)
            .answer(occurrence: _occurrence(), amountCents: null, reason: ''),
        OccurrenceAnswer.noAmount,
      );
      expect(repo.confirmedOccurrences, isEmpty);
    });
  });

  group('ending a schedule', () {
    test('an active one can be stopped', () async {
      final repo = _repo(schedule: _schedule(ScheduleStatus.active));
      expect(
        await ExpenseSchedules(repo).end(_schedule(ScheduleStatus.active)),
        isTrue,
      );
      expect(repo.expenseSchedules.single.status, ScheduleStatus.ended);
    });

    test('an ended one has nothing left to stop', () async {
      final repo = _repo(schedule: _schedule(ScheduleStatus.ended));
      expect(
        await ExpenseSchedules(repo).end(_schedule(ScheduleStatus.ended)),
        isFalse,
      );
      expect(repo.createdSchedules, isEmpty);
    });
  });

  group('scheduling', () {
    test('a nameless or zero schedule is refused, and writes nothing',
        () async {
      final repo = FakeMoneyRepository();
      expect(await _schedules(repo, title: '  ', cents: 900), isFalse);
      expect(await _schedules(repo, title: 'Internet', cents: 0), isFalse);
      expect(await _schedules(repo, title: 'Internet', cents: null), isFalse);
      expect(repo.createdSchedules, isEmpty);
    });

    test('a named one with an amount is scheduled', () async {
      final repo = FakeMoneyRepository();
      expect(await _schedules(repo, title: ' Internet ', cents: 900), isTrue);
      expect(repo.createdSchedules.single.title, 'Internet');
    });
  });
}

Future<bool> _schedules(
  FakeMoneyRepository repo, {
  required String title,
  required int? cents,
}) =>
    ExpenseSchedules(repo).schedule(
      workspaceId: 'ws-1',
      title: title,
      amountCents: cents,
      startsOn: DateTime.utc(2026, 9, 1),
      unit: ScheduleUnit.month,
    );
