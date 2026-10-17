// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the member directory caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_map.dart'
    show kProfilePresenceSignal;
import '../../../core/realtime/invalidation_registry.dart';
import 'directory_providers.dart';

final membersInvalidations = [
  InvalidationContribution(
    const ['reservations'],
    [directoryReservationsProvider],
  ),
  // The presence signal refreshes the directory's profiles and nothing else.
  InvalidationContribution(
    const ['profiles', kProfilePresenceSignal],
    [memberProfilesProvider],
  ),
];
