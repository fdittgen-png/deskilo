// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../money/providers/money_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_event_repository.dart';
import '../domain/event_decision.dart';
import '../domain/event_repository.dart';
import '../domain/validation_policy.dart';
import '../domain/workspace_event.dart';

part 'event_providers.g.dart';

@Riverpod(keepAlive: true)
EventRepository eventRepository(Ref ref) =>
    SupabaseEventRepository(Supabase.instance.client);

/// The active workspace's event feed, newest first (server-scoped by role).
@riverpod
Future<List<WorkspaceEvent>> events(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref.watch(eventRepositoryProvider).fetchEvents(workspace.id);
}

/// Per-validator audit trail for the visible feed, keyed by event id
/// (#130). Derived from [events], so invalidating the feed refreshes it.
@riverpod
Future<Map<String, List<EventDecision>>> eventDecisions(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  final all = await ref.watch(eventsProvider.future);
  if (all.isEmpty) return const {};
  return ref
      .watch(eventRepositoryProvider)
      .fetchDecisions(workspace.id, [for (final e in all) e.id]);
}

/// The workspace's quorum rules (#130); empty = pre-quorum behavior.
@riverpod
Future<List<ValidationPolicy>> validationPolicies(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(eventRepositoryProvider)
      .fetchValidationPolicies(workspace.id);
}

/// How many pending events await MY decision — drives the Events tab
/// badge. Same decider rule as the pending cards (#107, #130).
@riverpod
Future<int> myPendingEventCount(Ref ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return 0;
  final members = await ref.watch(workspaceMembersProvider.future);
  final policies = await ref.watch(validationPoliciesProvider.future);
  final decisions = await ref.watch(eventDecisionsProvider.future);
  final all = await ref.watch(eventsProvider.future);
  return all.where((e) {
    final policy = policyFor(e.type.dbName, policies);
    return e.isDecidedBy(
      member,
      policy: policy,
      hasOtherEligibleValidator: e.hasOtherEligibleValidator(members, policy),
      alreadyDecided: (decisions[e.id] ?? const [])
          .any((d) => d.memberId == member.id),
    );
  }).length;
}

/// Invalidates every provider that renders bookings or their event trail.
/// The tab shell keeps all screens alive, so a mutation on one tab must
/// invalidate the others' caches or they stay frozen pre-mutation (#111).
/// Decisions refresh too: with a quorum an event may STAY pending after my
/// accept, and only the fresh decision row moves it off my pending pile.
/// The bill refreshes as well: confirming a payment/expense/service charge
/// posts a ledger entry, so statement + ledger must refetch (#134).
void invalidateBookingData(WidgetRef ref) {
  ref
    ..invalidate(reservationsForDayProvider)
    ..invalidate(reservationsForMonthProvider)
    ..invalidate(myUpcomingReservationsProvider)
    ..invalidate(eventsProvider)
    ..invalidate(eventDecisionsProvider)
    ..invalidate(myStatementProvider)
    ..invalidate(myLedgerProvider);
}
