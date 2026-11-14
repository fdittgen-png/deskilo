// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — a change of plan, a pause or a resume for a selection of members,
// as the decision on #3618 settles it: member by member through the
// existing commands, each member read again and checked before it is
// changed. Every member gets an outcome; one that cannot be changed
// (pending, exited, a kiosk, a rule the share breaks, a refusal) is named
// with its reason and left as it was, never skipped silently. There is no
// all-or-nothing bulk command.
// #3858 — a share and a pause carry their date: a share from a month's
// first day (or as soon as possible: the first day after the last invoiced
// month), a pause from a day and until a day or until resumed. The answer of
// each member says the date, and for a pause what stays charged, what is
// freed and the bookings that fall in it; a date the server refuses names
// the earliest it can take.
import '../../core/trace/trace_logger.dart';
import '../../features/workspace/application/set_member_subscription.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/member_term_answer.dart';
import '../../features/workspace/domain/member_term_change.dart';

/// What a selection asks for.
sealed class MemberChange {
  const MemberChange();
}

/// Moves each member to the share [pct] (0 = no subscription) from [on], a
/// month's first day; null: as soon as possible.
final class ChangePlan extends MemberChange {
  const ChangePlan(this.pct, {this.on});
  final int pct;
  final DateTime? on;
}

/// Pauses each active member from [from] (null: today) until [until] (the
/// member is active again that day; null: until resumed).
final class PauseMembers extends MemberChange {
  const PauseMembers({this.from, this.until});
  final DateTime? from;
  final DateTime? until;
}

/// Makes each paused member active again, today.
final class ResumeMembers extends MemberChange {
  const ResumeMembers();
}

/// What became of one member of a selection.
enum MemberChangeOutcome {
  /// Changed.
  applied,

  /// Waits for its date: [MemberChangeResult.answer] names it.
  scheduled,

  /// Held by a validation policy until it is approved.
  held,

  /// The date is refused: [MemberChangeResult.earliest] is the first it can
  /// take. Nothing was changed.
  dateRefused,

  /// Already so: nothing was sent.
  unchanged,

  /// Waits for the space to accept them: nothing was sent.
  pending,

  /// Left the space: nothing was sent.
  exited,

  /// A kiosk is a device, not a paying member: nothing was sent.
  kiosk,

  /// A pause or a resume does not fit their status (a resume of an active
  /// member, a pause of a paused one is [unchanged]): nothing was sent.
  wrongStatus,

  /// The share breaks the rule (outside 0–100, or none with pay-as-you-go),
  /// or the change was refused on its day: nothing was changed.
  ruleRefused,

  /// No longer a member of the space when read again.
  gone,

  /// The server refused or did not answer: it was not changed, as far as
  /// the app knows.
  failed,
}

/// One member's outcome, with what the server answered.
class MemberChangeResult {
  const MemberChangeResult(this.outcome, {this.answer, this.earliest});

  final MemberChangeOutcome outcome;

  /// The dated command's answer, when one was sent.
  final MemberTermAnswer? answer;

  /// [MemberChangeOutcome.dateRefused]: the first date it can take.
  final DateTime? earliest;
}

/// The commands a selection runs through: the same as one member's.
abstract interface class MemberChangeCommands {
  /// The members of the space, read now.
  Future<List<Member>> members();

  /// Sets one member's status, today.
  Future<void> setStatus(Member member, MemberStatus status);

  /// Sets one member's share from [on] (null: as soon as possible).
  Future<MemberTermAnswer> setShare(Member member, int pct, {DateTime? on});

  /// Pauses one member from [from] (null: today) until [until].
  Future<MemberTermAnswer> pause(
    Member member, {
    DateTime? from,
    DateTime? until,
  });
}

/// Applies [change] to the members of [ids], one by one, and says what
/// became of each. The members are read again first: the rules are checked
/// on what the space holds now, not on the row that was selected.
Future<Map<String, MemberChangeResult>> applyMemberChange(
  MemberChangeCommands commands,
  List<String> ids,
  MemberChange change,
) async {
  final now = {for (final m in await commands.members()) m.id: m};
  final results = <String, MemberChangeResult>{};
  for (final id in ids) {
    final member = now[id];
    results[id] = member == null
        ? const MemberChangeResult(MemberChangeOutcome.gone)
        : await _one(commands, member, change);
  }
  return Map.unmodifiable(results);
}

/// Why [member] cannot take [change], or null when it may be sent.
MemberChangeOutcome? _refusal(Member member, MemberChange change) {
  if (member.status == MemberStatus.pending) return MemberChangeOutcome.pending;
  if (member.status == MemberStatus.exited) return MemberChangeOutcome.exited;
  if (member.isKiosk) return MemberChangeOutcome.kiosk;
  return switch (change) {
    ChangePlan(:final pct) => switch (subscriptionChange(member, pct)) {
      SubscriptionChange.unchanged => MemberChangeOutcome.unchanged,
      SubscriptionChange.saved => null,
      _ => MemberChangeOutcome.ruleRefused,
    },
    PauseMembers() =>
      member.status == MemberStatus.paused
          ? MemberChangeOutcome.unchanged
          : null,
    ResumeMembers() =>
      member.status == MemberStatus.active
          ? MemberChangeOutcome.unchanged
          : member.status == MemberStatus.paused
          ? null
          : MemberChangeOutcome.wrongStatus,
  };
}

/// The outcome a dated command's [answer] means.
MemberChangeResult _answered(MemberTermAnswer answer) => MemberChangeResult(
  switch (answer.state) {
    MemberTermState.applied => MemberChangeOutcome.applied,
    MemberTermState.scheduled => MemberChangeOutcome.scheduled,
    MemberTermState.pending => MemberChangeOutcome.held,
    MemberTermState.refused ||
    MemberTermState.cancelled => MemberChangeOutcome.ruleRefused,
  },
  answer: answer,
);

Future<MemberChangeResult> _one(
  MemberChangeCommands commands,
  Member member,
  MemberChange change,
) async {
  final refusal = _refusal(member, change);
  if (refusal != null) return MemberChangeResult(refusal);
  try {
    switch (change) {
      case ChangePlan(:final pct, :final on):
        return _answered(await commands.setShare(member, pct, on: on));
      case PauseMembers(:final from, :final until):
        return _answered(
          await commands.pause(member, from: from, until: until),
        );
      case ResumeMembers():
        await commands.setStatus(member, MemberStatus.active);
        return const MemberChangeResult(MemberChangeOutcome.applied);
    }
  } on MemberTermDateRefused catch (e, st) {
    // a refused date is an outcome, named with the earliest it can take
    TraceLogger.instance.log(
      TraceLevel.info,
      'members',
      'a date of a selection was refused',
      error: e,
      stackTrace: st,
    );
    return MemberChangeResult(
      MemberChangeOutcome.dateRefused,
      earliest: e.earliest,
    );
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'members',
      'a member of a selection was not changed',
      error: e,
      stackTrace: st,
    );
    return const MemberChangeResult(MemberChangeOutcome.failed);
  }
}
