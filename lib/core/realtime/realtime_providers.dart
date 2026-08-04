// SPDX-License-Identifier: 0BSD
import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../features/events/providers/event_providers.dart';
import '../../features/members/providers/directory_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import 'realtime_sync.dart';

part 'realtime_providers.g.dart';

@Riverpod(keepAlive: true)
RealtimeSync realtimeSync(Ref ref) =>
    SupabaseRealtimeSync(Supabase.instance.client);

/// How long changes are coalesced before invalidating (#413): a burst
/// (a series booking writes dozens of rows) becomes one refetch.
const kRealtimeDebounce = Duration(milliseconds: 300);

/// Subscribes to the active workspace's change feed and invalidates
/// exactly the providers that cache each table — so every device,
/// INCLUDING the one that made the change, repaints without restarts or
/// manual refreshes (#413). Watched from the shell, alive with the app.
@Riverpod(keepAlive: true)
class RealtimeInvalidator extends _$RealtimeInvalidator {
  StreamSubscription<String>? _sub;
  Timer? _debounce;
  final _pending = <String>{};

  @override
  Future<void> build() async {
    _sub?.cancel();
    _debounce?.cancel();
    ref.onDispose(() {
      _sub?.cancel();
      _debounce?.cancel();
    });
    final workspace = await ref.watch(currentWorkspaceProvider.future);
    if (workspace == null) return;
    _sub = ref
        .read(realtimeSyncProvider)
        .watch(workspace.id)
        .listen((table) {
      _pending.add(table);
      _debounce ??= Timer(kRealtimeDebounce, _flush);
    });
  }

  void _flush() {
    _debounce = null;
    final tables = Set.of(_pending);
    _pending.clear();
    if (!ref.mounted) return;
    for (final table in tables) {
      _invalidateFor(table);
    }
  }

  /// The table → cached-providers map. Anything not listed still
  /// refetches on the next natural invalidation; listed tables repaint
  /// live. Keep entries in step with new providers.
  void _invalidateFor(String table) {
    switch (table) {
      case 'reservations':
        ref
          ..invalidate(reservationsForDayProvider)
          ..invalidate(reservationsForMonthProvider)
          ..invalidate(myUpcomingReservationsProvider)
          ..invalidate(directoryReservationsProvider)
          ..invalidate(targetNamesProvider);
      case 'members':
        ref
          ..invalidate(workspaceMembersProvider)
          ..invalidate(memberNamesProvider)
          ..invalidate(memberEmailsProvider)
          ..invalidate(myMemberProvider)
          ..invalidate(myMembershipsProvider);
      case 'workspaces':
        // Flags, granularity, rules and the availability config all
        // derive from the workspace row.
        ref
          ..invalidate(myWorkspacesProvider)
          ..invalidate(openWeekdaysProvider)
          ..invalidate(bookingGranularityProvider)
          ..invalidate(workHoursProvider)
          ..invalidate(invoicePdfTemplateProvider);
      case 'closure_days':
        ref.invalidate(closureDaysProvider);
      case 'profiles':
        ref
          ..invalidate(memberProfilesProvider)
          ..invalidate(memberNamesProvider)
          // #458: the default-workspace choice rides the profile row.
          ..invalidate(defaultWorkspaceIdProvider);
      case 'levels' || 'offices' || 'desks' || 'seats' || 'plan_images':
        ref
          ..invalidate(levelsProvider)
          ..invalidate(floorPlanProvider);
      case 'member_notes':
        ref.invalidate(myNotesProvider);
      case 'events' || 'event_decisions':
        ref
          ..invalidate(eventsProvider)
          ..invalidate(eventDecisionsProvider)
          ..invalidate(myPendingEventCountProvider);
      case 'ledger_entries' || 'payment_intents' || 'quota_extensions':
        ref
          ..invalidate(myStatementProvider)
          ..invalidate(myLedgerProvider);
      case 'invoices':
        ref.invalidate(invoicesProvider);
      case 'services':
        ref
          ..invalidate(servicesProvider)
          ..invalidate(allServicesProvider);
      case 'fee_bands':
        ref.invalidate(feeBandsProvider);
      case 'packages':
        ref
          ..invalidate(packagesProvider)
          ..invalidate(allPackagesProvider);
      case 'validation_policies':
        ref.invalidate(validationPoliciesProvider);
      case 'accessories' || 'seat_accessories':
        // Seat accessory data rides the floor plan fetch.
        ref.invalidate(floorPlanProvider);
    }
  }
}
