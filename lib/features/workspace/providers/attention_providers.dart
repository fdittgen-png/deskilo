// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1247 — the decision surface's data, from the providers that already
// compute each signal.
//
// `docs/ux/DECISION_SURFACE.md` inventoried every candidate and put
// eight in and four out. The rule it applies is the whole design:
//
//   A line appears here only when a person must decide or act. A number
//   nobody can act on is information, and information belongs to the
//   screen that owns it.
//
// So nothing here fetches anything new: occupancy, balances and unread
// counts stay where they are precisely because none of them is a
// decision. What this assembles is the subset of the inventory whose
// sources are already providers, and the ranking lives in
// `domain/attention.dart` so the ORDER can be argued with in a unit
// test rather than read off a screen.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/time/clock.dart';
import '../../events/domain/workspace_event.dart';
import '../../events/providers/event_providers.dart';
import '../../money/providers/money_providers.dart';
import '../domain/attention.dart';
import '../domain/member.dart';
import 'workspace_providers.dart';

part 'attention_providers.g.dart';

/// Whether [type] is somebody's money leaving rather than somebody
/// waiting.
///
/// A payment awaiting confirmation delays cash; a join request delays a
/// person. Both are decisions, and the design ranks them differently
/// because what the delay costs is different.
bool isMoneyEvent(EventType type) => const {
      EventType.payment,
      EventType.invoicePayment,
      EventType.expense,
      EventType.adjustment,
      EventType.serviceCharge,
    }.contains(type);

/// Everything waiting on this person, in the order they should meet it.
///
/// Three of the inventory's eight signals so far — the events awaiting
/// my decision (split by what the delay costs), the join requests, and
/// the month's members with billable data and no invoice. The rest —
/// reminders due, a schema behind the app, doctor findings, a
/// capability held back by a prerequisite — have providers of their own
/// and are the next checkpoint; each is one more entry in this list,
/// not a change to the ranking.
@riverpod
Future<List<Attention>> attention(Ref ref) async {
  final items = <Attention>[];
  final now = ref.watch(clockProvider).now();

  // Events awaiting MY decision. `myPendingEventsProvider` already
  // applies the validation policy and the caller's own permissions, so
  // nothing is trimmed twice.
  for (final event in await ref.watch(myPendingEventsProvider.future)) {
    items.add(
      Attention(
        kind:
            isMoneyEvent(event.type) ? AttentionKind.money : AttentionKind.person,
        subject: event.type.dbName,
        decision: 'decide',
        waitingSince: event.createdAt,
      ),
    );
  }

  // Join requests: somebody is blocked on an answer.
  final members = await ref.watch(workspaceMembersProvider.future);
  final pending =
      members.where((m) => m.status == MemberStatus.pending).toList();
  if (pending.isNotEmpty) {
    items.add(
      Attention(
        kind: AttentionKind.person,
        subject: 'members',
        decision: 'admit',
        // The oldest of them, so the line's age is the wait that has
        // gone on longest rather than the most recent arrival.
        // `joinedAt` is null until the join is confirmed, which is
        // exactly the state these are in — so an unknown wait reads as
        // "now" rather than sorting to the top of its rank on a null.
        waitingSince: pending
            .map<DateTime>((m) => m.joinedAt ?? now)
            .reduce((a, b) => a.isBefore(b) ? a : b),
        count: pending.length,
      ),
    );
  }

  // The month's members with billable data and no invoice yet. ONE line
  // for the decision, not one per member: *issue for 7 members*.
  final overview = await ref.watch(invoicingOverviewProvider.future);
  if (overview.toInvoice.isNotEmpty) {
    items.add(
      Attention(
        kind: AttentionKind.month,
        subject: 'invoicing',
        decision: 'issue',
        waitingSince: now,
        count: overview.toInvoice.length,
      ),
    );
  }

  return rankAttention(items);
}
