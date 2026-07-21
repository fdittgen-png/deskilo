// SPDX-License-Identifier: 0BSD
import 'event_decision.dart';
import 'validation_policy.dart';
import 'workspace_event.dart';

/// Events boundary. Fetching also triggers the lazy timeout sweep
/// (spec §8.2) until Epic #9 adds a scheduled runner.
abstract class EventRepository {
  Future<List<WorkspaceEvent>> fetchEvents(String workspaceId, {int limit});

  /// Validator decision on a pending event (#130: possibly one of several
  /// before the quorum confirms); rejecting voids what the event would
  /// have applied (e.g. the tentative reservation).
  Future<void> respond(String eventId, {required bool accept});

  /// Per-validator audit trail for [eventIds], grouped by event id
  /// (#130). Batched so the events screen loads one query per feed.
  Future<Map<String, List<EventDecision>>> fetchDecisions(
    String workspaceId,
    List<String> eventIds,
  );

  Future<List<ValidationPolicy>> fetchValidationPolicies(String workspaceId);

  /// Request [halfDays] extra half-days for [period] ('YYYY-MM') beyond
  /// the subscription entitlement (0031). Lands as a pending 'quota'
  /// event that owners/admins validate per policy; returns the event id.
  Future<String> requestQuotaExtension(
    String workspaceId, {
    required String period,
    required int halfDays,
  });

  /// Insert-or-update on (workspace_id, event_type) — owner-only per RLS.
  Future<void> upsertValidationPolicy(ValidationPolicy policy);
}
