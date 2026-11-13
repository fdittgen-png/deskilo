// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3618 — a change of plan, a pause or a resume for a selection of members,
// as the decision on #3618 settles it: it applies from today (nothing dated
// is stored, #3858), member by member through the existing commands, each
// member read again and checked before it is changed. Every member gets an
// outcome; one that cannot be changed (pending, exited, a kiosk, a rule the
// share breaks, a refusal) is named with its reason and left as it was,
// never skipped silently. There is no all-or-nothing bulk command.
import '../../core/trace/trace_logger.dart';
import '../../features/workspace/application/set_member_subscription.dart';
import '../../features/workspace/domain/member.dart';

/// What a selection asks for.
sealed class MemberChange {
  const MemberChange();
}

/// Moves each member to the share [pct] (0 = no subscription).
final class ChangePlan extends MemberChange {
  const ChangePlan(this.pct);
  final int pct;
}

/// Pauses each active member.
final class PauseMembers extends MemberChange {
  const PauseMembers();
}

/// Makes each paused member active again.
final class ResumeMembers extends MemberChange {
  const ResumeMembers();
}

/// What became of one member of a selection.
enum MemberChangeOutcome {
  /// Changed.
  applied,

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

  /// The share breaks the rule (outside 0–100, or none with pay-as-you-go):
  /// nothing was sent.
  ruleRefused,

  /// No longer a member of the space when read again.
  gone,

  /// The server refused or did not answer: it was not changed, as far as
  /// the app knows.
  failed,
}

/// The commands a selection runs through: the same as one member's.
abstract interface class MemberChangeCommands {
  /// The members of the space, read now.
  Future<List<Member>> members();

  /// Sets one member's status.
  Future<void> setStatus(Member member, MemberStatus status);

  /// Sets one member's share; the rule decides first.
  Future<SubscriptionChange> setShare(Member member, int pct);
}

/// Applies [change] to the members of [ids], one by one, and says what
/// became of each. The members are read again first: the rules are checked
/// on what the space holds now, not on the row that was selected.
Future<Map<String, MemberChangeOutcome>> applyMemberChange(
  MemberChangeCommands commands,
  List<String> ids,
  MemberChange change,
) async {
  final now = {for (final m in await commands.members()) m.id: m};
  final outcomes = <String, MemberChangeOutcome>{};
  for (final id in ids) {
    final member = now[id];
    outcomes[id] = member == null
        ? MemberChangeOutcome.gone
        : await _one(commands, member, change);
  }
  return Map.unmodifiable(outcomes);
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

Future<MemberChangeOutcome> _one(
  MemberChangeCommands commands,
  Member member,
  MemberChange change,
) async {
  final refusal = _refusal(member, change);
  if (refusal != null) return refusal;
  try {
    switch (change) {
      case ChangePlan(:final pct):
        final result = await commands.setShare(member, pct);
        return result == SubscriptionChange.saved
            ? MemberChangeOutcome.applied
            : MemberChangeOutcome.ruleRefused;
      case PauseMembers():
        await commands.setStatus(member, MemberStatus.paused);
      case ResumeMembers():
        await commands.setStatus(member, MemberStatus.active);
    }
    return MemberChangeOutcome.applied;
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'members',
      'a member of a selection was not changed',
      error: e,
      stackTrace: st,
    );
    return MemberChangeOutcome.failed;
  }
}
