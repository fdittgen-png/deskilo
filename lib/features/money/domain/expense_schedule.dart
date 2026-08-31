// SPDX-License-Identifier: 0BSD

/// #767 — a scheduled (recurring) expense: internet, phone, electricity…
/// Any member schedules it; the SCHEDULE goes through the validation
/// rules (domain `expense_schedule`). Once active, the server sweep
/// materialises an [ExpenseOccurrence] per due date, which the member
/// answers: at the validated amount the expense is born settled; at a
/// different amount a mandatory explanation sends it through the normal
/// expense validation, and a reject hands it back for a resend.
library;

enum ScheduleUnit {
  day,
  week,
  month,
  year;

  static ScheduleUnit fromDb(String value) =>
      values.firstWhere((u) => u.name == value, orElse: () => month);
}

enum ScheduleStatus {
  pending,
  active,
  rejected,
  ended;

  static ScheduleStatus fromDb(String value) =>
      values.firstWhere((s) => s.name == value, orElse: () => pending);
}

enum OccurrenceStatus {
  awaitingMember('awaiting_member'),
  pendingValidation('pending_validation'),
  added('added'),
  rejected('rejected');

  const OccurrenceStatus(this.dbValue);
  final String dbValue;

  static OccurrenceStatus fromDb(String value) => values
      .firstWhere((s) => s.dbValue == value, orElse: () => awaitingMember);
}

class ExpenseSchedule {
  const ExpenseSchedule({
    required this.id,
    required this.workspaceId,
    required this.memberId,
    required this.title,
    required this.amountCents,
    required this.startsOn,
    required this.unit,
    this.description = '',
    this.endsOn,
    this.every = 1,
    this.repeatCount,
    this.status = ScheduleStatus.pending,
    this.occurrencesDone = 0,
    this.nextDue,
  });

  final String id;
  final String workspaceId;
  final String memberId;
  final String title;
  final String description;
  final int amountCents;
  final DateTime startsOn;
  final DateTime? endsOn;
  final ScheduleUnit unit;
  final int every;

  /// The rule applies this many times — or until [endsOn]; whichever
  /// comes first ends the schedule. Both null: until cancelled.
  final int? repeatCount;
  final ScheduleStatus status;
  final int occurrencesDone;
  final DateTime? nextDue;

  factory ExpenseSchedule.fromDb(Map<String, dynamic> row) => ExpenseSchedule(
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        memberId: row['member_id'] as String,
        title: row['title'] as String? ?? '',
        description: row['description'] as String? ?? '',
        amountCents: (row['amount_cents'] as num?)?.toInt() ?? 0,
        startsOn: DateTime.parse(row['starts_on'] as String),
        endsOn: row['ends_on'] == null
            ? null
            : DateTime.parse(row['ends_on'] as String),
        unit: ScheduleUnit.fromDb(row['unit'] as String? ?? 'month'),
        every: (row['every'] as num?)?.toInt() ?? 1,
        repeatCount: (row['repeat_count'] as num?)?.toInt(),
        status: ScheduleStatus.fromDb(row['status'] as String? ?? 'pending'),
        occurrencesDone: (row['occurrences_done'] as num?)?.toInt() ?? 0,
        nextDue: row['next_due'] == null
            ? null
            : DateTime.parse(row['next_due'] as String),
      );
}

class ExpenseOccurrence {
  const ExpenseOccurrence({
    required this.id,
    required this.scheduleId,
    required this.workspaceId,
    required this.memberId,
    required this.dueOn,
    required this.amountCents,
    this.note = '',
    this.deviationReason = '',
    this.status = OccurrenceStatus.awaitingMember,
    this.scheduleTitle = '',
    this.scheduledAmountCents,
  });

  final String id;
  final String scheduleId;
  final String workspaceId;
  final String memberId;
  final DateTime dueOn;
  final int amountCents;
  final String note;
  final String deviationReason;
  final OccurrenceStatus status;

  /// Joined from the schedule for display (title + the validated amount
  /// the deviation is measured against).
  final String scheduleTitle;
  final int? scheduledAmountCents;

  factory ExpenseOccurrence.fromDb(Map<String, dynamic> row) {
    final schedule = row['expense_schedules'] as Map<String, dynamic>?;
    return ExpenseOccurrence(
      id: row['id'] as String,
      scheduleId: row['schedule_id'] as String,
      workspaceId: row['workspace_id'] as String,
      memberId: row['member_id'] as String,
      dueOn: DateTime.parse(row['due_on'] as String),
      amountCents: (row['amount_cents'] as num?)?.toInt() ?? 0,
      note: row['note'] as String? ?? '',
      deviationReason: row['deviation_reason'] as String? ?? '',
      status:
          OccurrenceStatus.fromDb(row['status'] as String? ?? 'awaiting_member'),
      scheduleTitle: schedule?['title'] as String? ?? '',
      scheduledAmountCents: (schedule?['amount_cents'] as num?)?.toInt(),
    );
  }
}
