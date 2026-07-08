// SPDX-License-Identifier: MIT
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../data/supabase_event_repository.dart';
import '../domain/event_repository.dart';
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

/// How many pending events I must decide — drives the Events tab badge.
/// Same decider rule as the pending cards (#107).
@riverpod
Future<int> myPendingEventCount(Ref ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return 0;
  final members = await ref.watch(workspaceMembersProvider.future);
  final hasOtherActiveAdmin =
      members.any((m) => m.id != member.id && m.canAdminister);
  final all = await ref.watch(eventsProvider.future);
  return all
      .where((e) =>
          e.isDecidedBy(member, hasOtherActiveAdmin: hasOtherActiveAdmin))
      .length;
}

/// Invalidates every provider that renders bookings or their event trail.
/// The tab shell keeps all screens alive, so a mutation on one tab must
/// invalidate the others' caches or they stay frozen pre-mutation (#111).
void invalidateBookingData(WidgetRef ref) {
  ref
    ..invalidate(reservationsForDayProvider)
    ..invalidate(reservationsForMonthProvider)
    ..invalidate(myUpcomingReservationsProvider)
    ..invalidate(eventsProvider);
}
