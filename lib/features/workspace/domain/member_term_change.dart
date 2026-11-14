// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3858 — a dated change of a member's plan share or status, as the server
// stores it (`member_term_changes`, 0766): scheduled for a date, or written
// at once; applied on its date, refused with its reason, cancelled, or
// waiting for an approval. The money rules of this version, stated once: a
// change is in force from its date; an invoiced month keeps the terms its
// invoice was computed with; a month paused on its first day owes no
// subscription fee — nothing is prorated.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// What a change changes.
enum MemberTermKind { share, status }

/// How a change stands.
enum MemberTermState {
  /// Held by a validation policy until it is approved.
  pending,

  /// Waiting for its day.
  scheduled,

  /// In force from its date.
  applied,

  /// Refused, with [MemberTermChange.reason].
  refused,

  /// Cancelled before its day.
  cancelled;

  static MemberTermState fromWire(String? s) =>
      values.asNameMap()[s] ?? MemberTermState.refused;
}

class MemberTermChange implements SystemStamped {
  const MemberTermChange({
    required this.id,
    required this.memberId,
    required this.kind,
    required this.dueOn,
    required this.state,
    this.toPct,
    this.toStatus,
    this.reason = '',
    this.groupId,
    this.scheduled = true,
    this.system = SystemColumns.none,
  });

  final String id;
  final String memberId;
  final MemberTermKind kind;

  /// The share it sets ([MemberTermKind.share]).
  final int? toPct;

  /// The status it sets ([MemberTermKind.status]): 'paused' or 'active' for a
  /// scheduled pause; any status for one written at once.
  final String? toStatus;

  /// The date it is in force from.
  final DateTime dueOn;
  final MemberTermState state;
  final String reason;

  /// The pause it belongs to: its start and its end share it.
  final String? groupId;

  /// Scheduled for a date, rather than written at once by a command.
  final bool scheduled;

  @override
  final SystemColumns system;

  /// Still to come: waiting for its day or for an approval.
  bool get upcoming =>
      state == MemberTermState.scheduled || state == MemberTermState.pending;

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
        state: MemberTermState.fromWire(row['state'] as String?),
        reason: row['reason'] as String? ?? '',
        groupId: row['group_id'] as String?,
        scheduled: row['source'] == 'scheduled',
        system: SystemColumns.fromRow(row),
      );
}

DateTime _nextMonth(DateTime m) => DateTime(m.year, m.month + 1);

/// The first day of the first period a change dated [on] counts for: the
/// day itself when it is a month's first, else the next month's first —
/// past the months already invoiced ([invoiced], their first days), which
/// keep the terms they were invoiced with.
DateTime firstPeriodOf(DateTime on, {Set<DateTime> invoiced = const {}}) {
  var m = on.day == 1 ? DateTime(on.year, on.month) : _nextMonth(on);
  while (invoiced.contains(m)) {
    m = _nextMonth(m);
  }
  return m;
}

/// What a pause from [from] until [until] (null: until resumed) costs, the
/// server's rule: the months that stay charged in full (the month it starts
/// in unless it starts on the 1st, and every month already [invoiced]) and
/// the months it frees (those whose first day it covers, not invoiced) —
/// for an open pause, the first one only.
({List<DateTime> charged, List<DateTime> free}) pauseMoneyOf(
  DateTime from,
  DateTime? until, {
  Set<DateTime> invoiced = const {},
}) {
  final charged = <DateTime>[];
  final free = <DateTime>[];
  var m = DateTime(from.year, from.month);
  if (from.day != 1) {
    charged.add(m);
    m = _nextMonth(m);
  }
  final end = until == null
      ? null
      : DateTime(until.year, until.month, until.day);
  final stop = DateTime(from.year, from.month + 24);
  while ((end == null || m.isBefore(end)) && m.isBefore(stop)) {
    if (invoiced.contains(m)) {
      charged.add(m);
    } else {
      free.add(m);
      if (end == null) break;
    }
    m = _nextMonth(m);
  }
  return (charged: charged, free: free);
}

/// One line of a member's dated terms: a share change, or a pause with the
/// change that ends it ([until]).
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

/// The dated terms of [memberId] in [all], in date order: each share change
/// and each pause with its end — scheduled ones, and a share written at once
/// that waits for the first period not yet invoiced. Changes applied at once
/// are not listed: they are the plan as it stands.
List<MemberTermEntry> memberTermEntries(
  String memberId,
  List<MemberTermChange> all,
) {
  final mine = [
    for (final c in all)
      if (c.memberId == memberId && (c.scheduled || c.upcoming)) c,
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

/// The day [memberId]'s current pause began, when it is recorded: the last
/// status change in force, when it is a pause.
DateTime? pausedSince(String memberId, List<MemberTermChange> all) {
  MemberTermChange? last;
  for (final c in all) {
    if (c.memberId != memberId ||
        c.state != MemberTermState.applied ||
        c.kind != MemberTermKind.status) {
      continue;
    }
    if (last == null || !c.dueOn.isBefore(last.dueOn)) last = c;
  }
  return last?.toStatus == 'paused' ? last!.dueOn : null;
}
