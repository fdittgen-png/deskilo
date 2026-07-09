// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../workspace/domain/member.dart';

part 'workspace_event.freezed.dart';

/// Event kinds and lifecycle (spec §3/§8). Persisted by [dbName] — never
/// rename a stored value.
enum EventType {
  reservation,
  payment,
  expense,
  adjustment,
  serviceCharge('service_charge');

  const EventType([String? dbName]) : _dbName = dbName;

  final String? _dbName;

  /// The value stored in events.type (snake_case where Dart camelCases).
  String get dbName => _dbName ?? name;

  static EventType fromDb(String value) =>
      values.firstWhere((t) => t.dbName == value);
}

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

  /// Expenses, self-recorded payments and self-reported service charges
  /// are decided by ANOTHER admin (spec §9 no-self-approval, #129);
  /// everything else by the subject (§8.2).
  bool get needsAdminDecider =>
      type == EventType.expense ||
      ((type == EventType.payment || type == EventType.serviceCharge) &&
          actorIsSubject);

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
