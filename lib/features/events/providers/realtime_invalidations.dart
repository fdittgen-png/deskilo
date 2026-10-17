// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the events feature caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'event_providers.dart';

final eventsInvalidations = [
  InvalidationContribution(
    const ['events', 'event_decisions'],
    [eventsProvider, eventDecisionsProvider, myPendingEventCountProvider],
  ),
  InvalidationContribution(
    const ['validation_policies'],
    [validationPoliciesProvider],
  ),
];
