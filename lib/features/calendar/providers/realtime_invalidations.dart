// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the calendar hub caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'calendar_providers.dart';

/// #718 — the hub renders rows of all of these tables.
final calendarInvalidations = [
  InvalidationContribution(
    const [
      'reservations',
      'member_notes',
      'events',
      'event_decisions',
      'ledger_entries',
      'payment_intents',
      'quota_extensions',
      'invoices',
    ],
    [calendarItemsProvider],
  ),
];
