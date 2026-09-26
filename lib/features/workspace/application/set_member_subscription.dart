// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 A4 — changing a member's subscription share.
//
// The picker decided in three places: a disabled chip for "none" under
// pay-as-you-go, a silent return for a custom value outside 1-100, and
// a comparison with the current value that skipped the write. Here the
// rule is stated once and the command refuses what it does not allow;
// the server enforces the same pair (0 with pay-as-you-go) itself.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/member.dart';
import '../domain/overage_policy.dart';
import '../domain/workspace_repository.dart';
import '../providers/workspace_providers.dart';

part 'set_member_subscription.g.dart';

enum SubscriptionChange {
  /// The same share: nothing to write.
  unchanged,

  /// Not 0 and not within 1-100.
  outOfRange,

  /// No subscription while overage is pay-as-you-go would book for free.
  noneWithPayg,

  /// Written.
  saved,
}

/// Whether [member] may be set to [pct].
SubscriptionChange subscriptionChange(Member member, int pct) {
  if (pct == member.subscriptionPct) return SubscriptionChange.unchanged;
  if (pct < 0 || pct > 100) return SubscriptionChange.outOfRange;
  if (pct == 0 && member.overagePolicy == OveragePolicy.payg) {
    return SubscriptionChange.noneWithPayg;
  }
  return SubscriptionChange.saved;
}

/// Whether [text], typed as a custom share, is one (1-100).
int? customShare(String text) {
  final value = int.tryParse(text.trim());
  return value == null || value < 1 || value > 100 ? null : value;
}

class MemberSubscriptions {
  const MemberSubscriptions(this._workspaces);
  final WorkspaceRepository _workspaces;

  /// Sets [member]'s share to [pct] when the rule allows; a server refusal
  /// propagates, so no success is reported.
  Future<SubscriptionChange> set(Member member, int pct) async {
    final change = subscriptionChange(member, pct);
    if (change != SubscriptionChange.saved) return change;
    await _workspaces.updateMemberSubscription(member.id, pct);
    return change;
  }
}

/// #1449 A4 — a member's subscription share, and whether it may be set.
@riverpod
MemberSubscriptions memberSubscriptions(Ref ref) =>
    MemberSubscriptions(ref.watch(workspaceRepositoryProvider));
