// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../workspace/domain/member.dart';

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

  /// Expenses and self-recorded payments are decided by ANOTHER admin
  /// (spec §9 no-self-approval); everything else by the subject (§8.2).
  bool get needsAdminDecider =>
      type == EventType.expense ||
      (type == EventType.payment && actorIsSubject);

  /// Whether [me] is the one who must accept/decline this pending event.
  /// Mirrors respond_to_event exactly (#107), incl. the solo-admin escape
  /// hatch: when no other active admin exists, the actor may self-decide.
  bool isDecidedBy(Member me, {required bool hasOtherActiveAdmin}) {
    if (!isPending) return false;
    if (needsAdminDecider) {
      if (!me.canAdminister) return false;
      if (actorMemberId != me.id) return true;
      return !hasOtherActiveAdmin;
    }
    return subjectMemberId == me.id;
  }

  DateTime? get payloadStart => payload['starts_at'] == null
      ? null
      : DateTime.parse(payload['starts_at'] as String);

  DateTime? get payloadEnd => payload['ends_at'] == null
      ? null
      : DateTime.parse(payload['ends_at'] as String);

  String? get payloadTargetId =>
      (payload['seat_id'] ?? payload['office_id']) as String?;
}
