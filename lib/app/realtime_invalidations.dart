// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — THE table -> cached-providers map (#577), where the features are
// composed. core/realtime knows the tables and how a batch is applied; it
// does not know which feature's providers cache which table. Both freshness
// paths (realtime events and a screen's own mutation) read this one map
// through core's `invalidationLookupProvider`, so it cannot drift against
// itself. Anything not listed still refetches on the next natural
// invalidation; keep entries in step with new providers.
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/misc.dart' show Override;

import '../core/realtime/invalidation_map.dart';
import '../core/realtime/realtime_wiring.dart';
import '../features/calendar/providers/calendar_providers.dart';
import '../features/events/providers/event_providers.dart';
import '../features/members/providers/directory_providers.dart';
import '../features/money/providers/money_providers.dart';
import '../features/plan/providers/floor_plan_providers.dart';
import '../features/reservations/providers/reservation_providers.dart';
import '../features/workspace/providers/conversation_providers.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// Puts the map, the plan-cache bust and the active workspace in a scope's
/// overrides (main.dart, the demo container, the test helper).
final List<Override> realtimeWiringFromApp = [
  invalidationLookupProvider.overrideWithValue(invalidationFor),
  realtimeWorkspaceIdProvider.overrideWith(
    (ref) async => (await ref.watch(currentWorkspaceProvider.future))?.id,
  ),
  planCacheBusterProvider.overrideWith(
    (ref) => ref.read(floorPlanRepositoryProvider).invalidateCache,
  ),
];

@visibleForTesting
TableInvalidation invalidationFor(String table) => switch (table) {
      'reservations' => TableInvalidation([
          // #718 — the calendar hub renders this table too.
          calendarItemsProvider,
          reservationsForDayProvider,
          reservationsForMonthProvider,
          myUpcomingReservationsProvider,
          directoryReservationsProvider,
          targetNamesProvider,
        ]),
      'members' => TableInvalidation(
          [
            workspaceMembersProvider,
            memberNamesProvider,
            memberEmailsProvider,
            myMemberProvider,
            myMembershipsProvider,
            // #572 — see [TableInvalidation.bustsPlanCache]. Member
            // changes are rare; over-invalidation is cheap, a workspace
            // that stays blank after approval is not.
            levelsProvider,
            floorPlanProvider,
            targetNamesProvider,
            reservationsForDayProvider,
            reservationsForMonthProvider,
            myUpcomingReservationsProvider,
          ],
          bustsPlanCache: true,
        ),
      // Flags, granularity, rules and the availability config all
      // derive from the workspace row.
      'workspaces' => TableInvalidation([
          myWorkspacesProvider,
          openWeekdaysProvider,
          bookingGranularityProvider,
          workHoursProvider,
          // #1277 — a renamed word is a workspaces-row change like any
          // other; without this it reaches only the device that wrote it.
          lexiconProvider,
          invoicePdfTemplateProvider,
          dunningRulesProvider,
        ]),
      'closure_days' => TableInvalidation([closureDaysProvider]),
      kProfilePresenceSignal => TableInvalidation([memberProfilesProvider]),
      'profiles' => TableInvalidation([
          memberProfilesProvider,
          memberNamesProvider,
          // #458: the default-workspace choice rides the profile row.
          defaultWorkspaceIdProvider,
        ]),
      // #1084 — these ARE the plan. Both providers read `cacheFirst` off
      // a 10-minute disk entry, so invalidating the provider without
      // busting the cache refetches straight back into the stale bundle:
      // the editing device repaints (its mutation busts locally), every
      // other device shows the old plan until the TTL expires.
      'levels' ||
      'offices' ||
      'desks' ||
      'seats' ||
      'plan_images' =>
        TableInvalidation(
          [levelsProvider, floorPlanProvider],
          bustsPlanCache: true,
        ),
      // #702 — a MESSAGE lands live, or it does not land at all until
      // someone pulls to refresh. This mapped only the old bell feed:
      // the messaging centre's list, its unread badge and any open
      // thread all sat on caches nothing refreshed, so an incoming
      // message was invisible until the screen was rebuilt by hand.
      // That is the one thing a messenger may not do.
      'member_notes' => TableInvalidation([
          // #718 — the calendar hub renders this table too.
          calendarItemsProvider,
          myNotesProvider,
          conversationsProvider,
          // The family, so whichever thread is open repaints too.
          conversationMessagesProvider,
        ]),
      // A conversation you were just added to, and the roster of one you
      // are in: both arrive as rows on tables the client never watched.
      'conversations' || 'conversation_participants' => TableInvalidation([
          conversationsProvider,
          conversationParticipantsProvider,
        ]),
      'events' || 'event_decisions' => TableInvalidation([
          // #718 — the calendar hub renders this table too.
          calendarItemsProvider,
          eventsProvider,
          eventDecisionsProvider,
          myPendingEventCountProvider,
        ]),
      'ledger_entries' ||
      'payment_intents' ||
      'quota_extensions' =>
        TableInvalidation([
          // #718 — the calendar hub renders this table too.
          calendarItemsProvider,
          myStatementProvider,
          myLedgerProvider,
          // #512 — every money change can move the cross-month position.
          myAccountProvider,
        ]),
      'invoices' => TableInvalidation([invoicesProvider, calendarItemsProvider]),
      'services' => TableInvalidation([
          servicesProvider,
          allServicesProvider,
        ]),
      'fee_bands' => TableInvalidation([feeBandsProvider]),
      'packages' => TableInvalidation([
          packagesProvider,
          allPackagesProvider,
        ]),
      'validation_policies' =>
        TableInvalidation([validationPoliciesProvider]),
      // Seat accessory data rides the floor plan fetch — and therefore
      // the floor plan CACHE (#1084).
      'accessories' ||
      'seat_accessories' =>
        TableInvalidation([floorPlanProvider], bustsPlanCache: true),
      _ => TableInvalidation([]),
    };
