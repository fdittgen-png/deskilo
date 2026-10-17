// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what reservations cache, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'reservation_providers.dart';

final reservationsInvalidations = [
  // Member changes are rare; over-invalidation is cheap, a workspace that
  // stays blank after approval is not.
  InvalidationContribution(
    const ['reservations', 'members'],
    [
      reservationsForDayProvider,
      reservationsForMonthProvider,
      myUpcomingReservationsProvider,
    ],
  ),
  InvalidationContribution(
    const ['members', 'profiles'],
    [memberNamesProvider],
  ),
];
