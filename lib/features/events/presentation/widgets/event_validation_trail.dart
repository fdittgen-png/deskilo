// SPDX-License-Identifier: 0BSD
//
// #841 — the trail, fetched for one event and shown on the document that
// raised it: an invoice, a booking, a pending position on the bill.
//
// The feed carries the newest hundred events, so a document older than
// that could never say who released it. This resolves the event by id
// instead, and stays silent when there is nothing to tell — an event
// nobody had to decide has no trail to show.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import '../../providers/event_providers.dart';
import 'validation_trail.dart';

/// The decision trail of [eventId], resolved from the repository.
class EventValidationTrail extends ConsumerWidget {
  const EventValidationTrail({
    super.key,
    required this.eventId,
    this.showTitle = true,
  });

  final String eventId;

  /// A document says what the block is; a row inside a card does not.
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (eventId.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final trail = ref.watch(eventTrailProvider(eventId)).value;
    final event = trail?.event;
    if (trail == null || event == null) return const SizedBox.shrink();

    final names = ref.watch(memberNamesProvider).value ?? const {};
    final policies =
        ref.watch(validationPoliciesProvider).value ?? const <ValidationPolicy>[];
    final policy = policyFor(event.type.dbName, policies);
    final pending = event.status == EventStatus.pending;

    // Nothing was ever asked of anyone: no trail, no empty heading.
    if (trail.decisions.isEmpty && !pending) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ValidationTrail(
        key: ValueKey('event-trail-$eventId'),
        decisions: trail.decisions,
        names: names,
        requiredCount: policy.requiredCount,
        pending: pending,
        sequential: policy.sequential,
        title: showTitle
            ? (l10n?.validationTrailTitle ?? 'Validation trail')
            : null,
      ),
    );
  }
}

/// The most recent event that governs the booking [reservationId]: its
/// own creation, which 0007 records on `events.reservation_id`, or a
/// deletion request, which 0097 deliberately keeps OFF that column (a
/// reject there would cancel the booking) and carries in the payload.
/// Null when nothing was ever asked about it.
String? reservationEventId(WidgetRef ref, String reservationId) {
  final events = ref.watch(eventsProvider).value ?? const <WorkspaceEvent>[];
  WorkspaceEvent? best;
  for (final event in events) {
    final mine = event.reservationId == reservationId ||
        event.payload['reservation_id'] == reservationId;
    if (!mine) continue;
    if (best == null || event.createdAt.isAfter(best.createdAt)) best = event;
  }
  return best?.id;
}
