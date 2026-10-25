// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/features/money/domain/expense_repartition.dart';
import 'package:deskilo/features/money/domain/expense_repository.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';

import '../money_repository.dart';

/// #2591 — the demo's expenses, schedules and repartitions, answered from one
/// space's in-memory money store ([FakeMoneyRepository]); every other port of
/// that space reads and writes the same store.
class DemoExpenses implements ExpenseRepository {
  DemoExpenses(this._m);

  final FakeMoneyRepository _m;

  @override
  Future<String> distributeExpense({
    required String workspaceId,
    required String title,
    required int amountCents,
    required RepartitionMethod method,
    required String period,
    required List<RepartitionShare> shares,
    String? sourceEventId,
  }) async {
    if (amountCents == 0) throw StateError('amount must not be zero');
    if (shares.isEmpty) throw StateError('no shares');
    if (shares.fold(0, (s, x) => s + x.amountCents) != amountCents) {
      throw StateError('shares must add up to the amount');
    }
    final id = 'rep-${_m.nextRepartitionNumber++}';
    final pending = _m.repartitionPolicyConfigured;
    if (!pending) {
      for (final share in shares) {
        _m.ledger.add(
          LedgerEntry(
            id: 'ledger-rep-$id-${share.memberId}',
            memberId: share.memberId,
            kind: amountCents > 0 ? LedgerKind.charge : LedgerKind.credit,
            category: LedgerCategory.adjustment,
            amountCents: share.amountCents.abs(),
            description: title,
            period: period,
            createdAt: kTestNow,
          ),
        );
      }
    }
    _m.repartitions.insert(
      0,
      ExpenseRepartition(
        id: id,
        title: title,
        amountCents: amountCents,
        method: method,
        period: period,
        shares: shares,
        status: pending ? 'pending' : 'confirmed',
        createdAt: kTestNow,
        appliedAt: pending ? null : kTestNow,
      ),
    );
    return id;
  }

  @override
  Future<List<ExpenseRepartition>> fetchExpenseRepartitions(
    String workspaceId,
  ) async => List.of(_m.repartitions);

  @override
  Future<List<ExpenseSchedule>> fetchExpenseSchedules(
    String workspaceId,
  ) async => List.of(_m.expenseSchedules);

  @override
  Future<String> createExpenseSchedule({
    required String workspaceId,
    required String title,
    required int amountCents,
    required DateTime startsOn,
    required ScheduleUnit unit,
    int every = 1,
    int? repeatCount,
    DateTime? endsOn,
    String description = '',
  }) async {
    _m.createdSchedules.add((
      title: title,
      amountCents: amountCents,
      unit: unit,
      every: every,
      repeatCount: repeatCount,
      endsOn: endsOn,
    ));
    final schedule = ExpenseSchedule(
      id: 'schedule-${_m.expenseSchedules.length + 1}',
      workspaceId: workspaceId,
      memberId: 'member-1',
      title: title,
      description: description,
      amountCents: amountCents,
      startsOn: startsOn,
      endsOn: endsOn,
      unit: unit,
      every: every,
      repeatCount: repeatCount,
    );
    _m.expenseSchedules.add(schedule);
    return schedule.id;
  }

  @override
  Future<void> cancelExpenseSchedule(String scheduleId) async {
    final i = _m.expenseSchedules.indexWhere((s) => s.id == scheduleId);
    if (i < 0) return;
    final s = _m.expenseSchedules[i];
    _m.expenseSchedules[i] = ExpenseSchedule(
      id: s.id,
      workspaceId: s.workspaceId,
      memberId: s.memberId,
      title: s.title,
      description: s.description,
      amountCents: s.amountCents,
      startsOn: s.startsOn,
      endsOn: s.endsOn,
      unit: s.unit,
      every: s.every,
      repeatCount: s.repeatCount,
      status: ScheduleStatus.ended,
      occurrencesDone: s.occurrencesDone,
      supplierId: s.supplierId,
    );
  }

  @override
  Future<void> setExpenseScheduleSupplier(
    String scheduleId,
    String? supplierId,
  ) async {
    final i = _m.expenseSchedules.indexWhere((s) => s.id == scheduleId);
    if (i < 0) throw StateError('unknown schedule');
    final s = _m.expenseSchedules[i];
    _m.expenseScheduleSuppliers[scheduleId] = supplierId;
    _m.expenseSchedules[i] = ExpenseSchedule(
      id: s.id,
      workspaceId: s.workspaceId,
      memberId: s.memberId,
      title: s.title,
      description: s.description,
      amountCents: s.amountCents,
      startsOn: s.startsOn,
      endsOn: s.endsOn,
      unit: s.unit,
      every: s.every,
      repeatCount: s.repeatCount,
      status: s.status,
      occurrencesDone: s.occurrencesDone,
      nextDue: s.nextDue,
      supplierId: supplierId,
    );
  }

  @override
  Future<int> sweepExpenseSchedules(String workspaceId) async {
    _m.sweptSchedules++;
    return 0;
  }

  @override
  Future<List<ExpenseOccurrence>> fetchExpenseOccurrences(
    String workspaceId,
  ) async => List.of(_m.expenseOccurrences);

  @override
  Future<void> confirmExpenseOccurrence({
    required String occurrenceId,
    required int amountCents,
    String reason = '',
    String? note,
  }) async {
    final i = _m.expenseOccurrences.indexWhere((o) => o.id == occurrenceId);
    if (i < 0) throw StateError('unknown occurrence');
    final o = _m.expenseOccurrences[i];
    final matches =
        amountCents == (o.scheduledAmountCents ?? o.amountCents) &&
        o.status == OccurrenceStatus.awaitingMember;
    if (!matches && reason.trim().isEmpty) {
      throw StateError('a different amount needs an explanation');
    }
    _m.confirmedOccurrences.add((
      occurrenceId: occurrenceId,
      amountCents: amountCents,
      reason: reason,
    ));
    _m.expenseOccurrences[i] = ExpenseOccurrence(
      id: o.id,
      scheduleId: o.scheduleId,
      workspaceId: o.workspaceId,
      memberId: o.memberId,
      dueOn: o.dueOn,
      amountCents: amountCents,
      note: note ?? o.note,
      deviationReason: reason,
      status: matches
          ? OccurrenceStatus.added
          : OccurrenceStatus.pendingValidation,
      scheduleTitle: o.scheduleTitle,
      scheduledAmountCents: o.scheduledAmountCents,
    );
  }

  @override
  Future<String> submitExpense({
    required String workspaceId,
    required int amountCents,
    required String category,
    String description = '',
    Map<String, Object?>? supply,
    Map<String, Object?>? vat,
  }) async {
    _m.submittedExpenseVat.add(vat);
    _m.submittedExpenses.add((
      amountCents: amountCents,
      category: category,
      description: description,
      supply: supply,
    ));
    return 'evt-expense-${_m.submittedExpenses.length}';
  }

  @override
  Future<void> setExpenseScheduleVat(
    String scheduleId,
    Map<String, Object?>? vat,
  ) async => _m.expenseScheduleVat[scheduleId] = vat;
}
