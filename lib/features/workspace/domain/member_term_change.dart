// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — a dated change of a member's plan share or status, as the server
// stores it (`member_term_changes`, 0766): scheduled for a date, or written
// at once; applied, refused with its reason, cancelled, or waiting for an
// approval. The money rule of this version, stated once: a change counts for
// every period whose first day is on or after its date, and a month paused on
// its first day owes no subscription fee — nothing is prorated.

/// What a change changes.
enum MemberTermKind { share, status }

/// How a change stands.
enum MemberTermState {
  /// Held by a validation policy until it is approved.
  pending,

  /// Waiting for its day.
  scheduled,

  /// Took effect ([MemberTermChange.effectiveOn]).
  applied,

  /// Refused on its day, with [MemberTermChange.reason].
  refused,

  /// Cancelled before its day.
  cancelled;

  static MemberTermState fromWire(String? s) =>
      values.asNameMap()[s] ?? MemberTermState.refused;
}

class MemberTermChange {
  const MemberTermChange({
    required this.id,
    required this.memberId,
    required this.kind,
    required this.dueOn,
    required this.state,
    this.toPct,
    this.toStatus,
    this.effectiveOn,
    this.reason = '',
    this.groupId,
    this.scheduled = true,
  });

  final String id;
  final String memberId;
  final MemberTermKind kind;

  /// The share it sets ([MemberTermKind.share]).
  final int? toPct;

  /// The status it sets ([MemberTermKind.status]): 'paused' or 'active' for a
  /// scheduled pause; any status for one written at once.
  final String? toStatus;
  final DateTime dueOn;
  final DateTime? effectiveOn;
  final MemberTermState state;
  final String reason;

  /// The pause it belongs to: its start and its end share it.
  final String? groupId;

  /// Scheduled for a date, rather than written at once by a command.
  final bool scheduled;

  /// Still to come: waiting for its day or for an approval.
  bool get upcoming =>
      state == MemberTermState.scheduled || state == MemberTermState.pending;

  /// Applied later than its date: its first period was already invoiced.
  bool get late =>
      state == MemberTermState.applied &&
      effectiveOn != null &&
      effectiveOn != dueOn;

  factory MemberTermChange.fromRow(Map<String, dynamic> row) =>
      MemberTermChange(
        id: row['id'] as String,
        memberId: row['member_id'] as String,
        kind: row['kind'] == 'status'
            ? MemberTermKind.status
            : MemberTermKind.share,
        toPct: row['to_pct'] as int?,
        toStatus: row['to_status'] as String?,
        dueOn: DateTime.parse(row['due_on'] as String),
        effectiveOn: row['effective_on'] == null
            ? null
            : DateTime.parse(row['effective_on'] as String),
        state: MemberTermState.fromWire(row['state'] as String?),
        reason: row['reason'] as String? ?? '',
        groupId: row['group_id'] as String?,
        scheduled: row['source'] != 'immediate',
      );
}

/// The first day of the first period a change dated [on] counts for: the
/// day itself when it is a month's first, else the next month's first.
DateTime firstPeriodOf(DateTime on) => on.day == 1
    ? DateTime(on.year, on.month)
    : DateTime(on.year, on.month + 1);

/// The months a pause from [from] until [until] (null: until resumed) owes no
/// subscription fee for: those whose first day falls inside it. Lists at most
/// [max] months for an open pause.
List<DateTime> freeMonthsOfPause(
  DateTime from,
  DateTime? until, {
  int max = 1,
}) {
  final months = <DateTime>[];
  var m = firstPeriodOf(from);
  while ((until == null && months.length < max) ||
      (until != null && m.isBefore(DateTime(until.year, until.month, until.day)))) {
    months.add(m);
    m = DateTime(m.year, m.month + 1);
  }
  return months;
}

/// One line of a member's dated terms: a scheduled share change, or a
/// scheduled pause with the change that ends it ([until]).
class MemberTermEntry {
  const MemberTermEntry(this.change, {this.until});

  final MemberTermChange change;

  /// The resumption that ends a pause, when one is dated.
  final MemberTermChange? until;

  bool get isPause => change.kind == MemberTermKind.status;

  /// The date this entry next acts on, while something of it is to come.
  DateTime? get nextOn => change.upcoming
      ? change.dueOn
      : (until?.upcoming ?? false)
      ? until!.dueOn
      : null;
}

/// The scheduled terms of [memberId] in [all], in date order: each share
/// change, and each pause with its end. Changes written at once are not
/// listed: they are the plan as it stands.
List<MemberTermEntry> memberTermEntries(
  String memberId,
  List<MemberTermChange> all,
) {
  final mine = [
    for (final c in all)
      if (c.memberId == memberId && c.scheduled) c,
  ];
  final ends = {
    for (final c in mine)
      if (c.groupId != null && c.toStatus == 'active') c.groupId!: c,
  };
  return [
    for (final c in mine)
      if (c.kind == MemberTermKind.share || c.toStatus == 'paused')
        MemberTermEntry(c, until: ends[c.groupId]),
  ];
}

/// The first entry of [memberId] still to act, or null.
MemberTermEntry? nextTermEntry(String memberId, List<MemberTermChange> all) {
  MemberTermEntry? next;
  for (final e in memberTermEntries(memberId, all)) {
    final on = e.nextOn;
    if (on != null && (next == null || on.isBefore(next.nextOn!))) next = e;
  }
  return next;
}

/// The day [memberId]'s current pause took effect, when it is recorded.
DateTime? pausedSince(String memberId, List<MemberTermChange> all) {
  MemberTermChange? last;
  DateTime on(MemberTermChange c) => c.effectiveOn ?? c.dueOn;
  for (final c in all) {
    if (c.memberId != memberId ||
        c.state != MemberTermState.applied ||
        c.kind != MemberTermKind.status) {
      continue;
    }
    if (last == null || !on(c).isBefore(on(last))) last = c;
  }
  return last?.toStatus == 'paused' ? on(last!) : null;
}
