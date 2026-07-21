// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/event_repository.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';

/// In-memory [EventRepository] mimicking respond_to_event semantics
/// (incl. the #130 quorum: an accept below required_count stays pending).
class FakeEventRepository implements EventRepository {
  final events = <WorkspaceEvent>[];
  final decisions = <EventDecision>[];
  final policies = <ValidationPolicy>[];

  /// Whose decision [respond] records — the signed-in viewer's member id.
  String respondingMemberId = 'member-1';

  var _nextDecisionId = 1;

  @override
  Future<List<WorkspaceEvent>> fetchEvents(
    String workspaceId, {
    int limit = 100,
  }) async {
    return events.where((e) => e.workspaceId == workspaceId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> respond(String eventId, {required bool accept}) async {
    final i = events.indexWhere((e) => e.id == eventId);
    if (i < 0) throw StateError('unknown event');
    final event = events[i];
    if (event.status != EventStatus.pending) {
      throw StateError('already decided');
    }
    if (decisions.any(
      (d) => d.eventId == eventId && d.memberId == respondingMemberId,
    )) {
      throw StateError('you already decided this event');
    }
    decisions.add(
      EventDecision(
        id: 'dec-${_nextDecisionId++}',
        eventId: eventId,
        memberId: respondingMemberId,
        accept: accept,
        decidedBySystem: false,
        decidedAt: DateTime.now(),
      ),
    );
    if (!accept) {
      events[i] = event.copyWith(
        status: EventStatus.rejected,
        decidedAt: DateTime.now(),
      );
      return;
    }
    final required = policyFor(event.type.dbName, policies).requiredCount;
    final accepts =
        decisions.where((d) => d.eventId == eventId && d.accept).length;
    if (accepts >= required) {
      events[i] = event.copyWith(
        status: EventStatus.confirmed,
        decidedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<Map<String, List<EventDecision>>> fetchDecisions(
    String workspaceId,
    List<String> eventIds,
  ) async {
    final grouped = <String, List<EventDecision>>{};
    for (final decision in decisions) {
      if (!eventIds.contains(decision.eventId)) continue;
      grouped.putIfAbsent(decision.eventId, () => []).add(decision);
    }
    return grouped;
  }

  @override
  Future<List<ValidationPolicy>> fetchValidationPolicies(
    String workspaceId,
  ) async =>
      policies.where((p) => p.workspaceId == workspaceId).toList();

  var _nextEventId = 1;

  @override
  Future<String> requestQuotaExtension(
    String workspaceId, {
    required String period,
    required int halfDays,
  }) async {
    // Mirrors request_quota_extension (0031): a pending self-initiated
    // 'quota' event that validators decide.
    final event = WorkspaceEvent(
      id: 'quota-${_nextEventId++}',
      workspaceId: workspaceId,
      type: EventType.quota,
      action: EventAction.submitted,
      actorMemberId: respondingMemberId,
      subjectMemberId: respondingMemberId,
      payload: {'period': period, 'half_days': halfDays},
      status: EventStatus.pending,
      createdAt: DateTime.now(),
    );
    events.add(event);
    return event.id;
  }

  @override
  Future<void> upsertValidationPolicy(ValidationPolicy policy) async {
    final i = policies.indexWhere(
      (p) =>
          p.workspaceId == policy.workspaceId &&
          p.eventType == policy.eventType,
    );
    if (i >= 0) {
      policies[i] = policy;
    } else {
      policies.add(policy);
    }
  }
}
