// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

/// What one table invalidates (#577). The map itself lives in
/// lib/app/realtime_invalidations.dart (#2495): it names the providers of
/// many features, so it belongs where they are composed.
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

/// #2019 C — a profile change that moved only presence (`last_seen_at`):
/// refreshes the presence consumer, not names or the default workspace.
const kProfilePresenceSignal = 'profiles:presence';

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
