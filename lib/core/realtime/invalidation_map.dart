// SPDX-License-Identifier: 0BSD
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../features/calendar/providers/calendar_providers.dart';
import '../../features/events/providers/event_providers.dart';
import '../../features/members/providers/directory_providers.dart';
import '../../features/money/providers/money_providers.dart';
import '../../features/plan/providers/floor_plan_providers.dart';
import '../../features/reservations/providers/reservation_providers.dart';
import '../../features/workspace/providers/conversation_providers.dart';
import '../../features/workspace/providers/workspace_providers.dart';

/// THE table → cached-providers map (#577). Both freshness paths read it:
/// realtime events (RealtimeInvalidator) and local mutations
/// (invalidateBookingData) — before #577 each kept its own copy and they
/// drifted (a money mutation refreshed [myAccount] locally but a remote
/// one did not). One map cannot drift against itself.
///
/// Anything not listed still refetches on the next natural invalidation;
/// listed tables repaint live. Keep entries in step with new providers.
class TableInvalidation {
  TableInvalidation(this.providers, {this.bustsPlanCache = false});

  /// The providers whose caches render rows of this table.
  final List<ProviderOrFamily> providers;

  /// Whether the floor-plan DISK cache must be busted too (#572 — a
  /// members change can be this user's approval, which widens what RLS
  /// lets them read; everything fetched under the old horizon is stale).
  final bool bustsPlanCache;
}

/// Emitted by the sync layer instead of a table name when events may
/// have been MISSED (channel re-joined after an error, app resumed):
/// the receiver refreshes every mapped table instead of one.
const kResyncSignal = '*';

/// All tables with a live mapping — the resync sweep iterates these.
const mappedTables = [
  'reservations',
  'members',
  'workspaces',
  'closure_days',
  'profiles',
  'levels',
  'member_notes',
  'conversations',
  'conversation_participants',
  'events',
  'ledger_entries',
  'invoices',
  'services',
  'fee_bands',
  'packages',
  'validation_policies',
  'accessories',
];

/// The tables a booking/decision/money mutation touches server-side —
/// what a screen invalidates after ITS OWN write (#111: the tab shell
/// keeps every screen alive, so a mutation on one tab must refresh the
/// others or they stay frozen pre-mutation).
const bookingMutationTables = [
  'reservations',
  'events',
  'ledger_entries',
];

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
          invoicePdfTemplateProvider,
          dunningRulesProvider,
        ]),
      'closure_days' => TableInvalidation([closureDaysProvider]),
      'profiles' => TableInvalidation([
          memberProfilesProvider,
          memberNamesProvider,
          // #458: the default-workspace choice rides the profile row.
          defaultWorkspaceIdProvider,
        ]),
      'levels' ||
      'offices' ||
      'desks' ||
      'seats' ||
      'plan_images' =>
        TableInvalidation([levelsProvider, floorPlanProvider]),
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
      // Seat accessory data rides the floor plan fetch.
      'accessories' ||
      'seat_accessories' =>
        TableInvalidation([floorPlanProvider]),
      _ => TableInvalidation([]),
    };
