// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_event.freezed.dart';

/// Event kinds and lifecycle (spec §3/§8). Persisted by name — never rename.
enum EventType { reservation, payment, expense, adjustment }

enum EventAction { created, modified, cancelled, submitted, approved, rejected }

enum EventStatus { applied, pending, confirmed, rejected, expired }

/// The unifying auditable record of the Events space (spec §8). When actor
/// and subject differ the event runs through the confirmation protocol.
@freezed
sealed class WorkspaceEvent with _$WorkspaceEvent {
  const WorkspaceEvent._();

  const factory WorkspaceEvent({
    required String id,
    required String workspaceId,
    required EventType type,
    required EventAction action,
    required String actorMemberId,
    required String subjectMemberId,
    String? reservationId,
    required Map<String, dynamic> payload,
    required EventStatus status,
    required DateTime createdAt,
    DateTime? decidedAt,
  }) = _WorkspaceEvent;

  bool get isPending => status == EventStatus.pending;

  bool get actorIsSubject => actorMemberId == subjectMemberId;

  DateTime? get payloadStart => payload['starts_at'] == null
      ? null
      : DateTime.parse(payload['starts_at'] as String);

  DateTime? get payloadEnd => payload['ends_at'] == null
      ? null
      : DateTime.parse(payload['ends_at'] as String);

  String? get payloadTargetId =>
      (payload['seat_id'] ?? payload['office_id']) as String?;
}
