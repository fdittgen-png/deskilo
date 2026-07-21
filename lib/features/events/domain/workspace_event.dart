// SPDX-License-Identifier: 0BSD
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../workspace/domain/member.dart';
import 'validation_policy.dart';

part 'workspace_event.freezed.dart';

/// Event kinds and lifecycle (spec §3/§8). Persisted by [dbName] — never
/// rename a stored value.
enum EventType {
  reservation,
  payment,
  expense,
  adjustment,
  serviceCharge('service_charge'),

  /// A member's request for extra half-days beyond their subscription
  /// entitlement (migration 0031). Always self-initiated; validators
  /// decide per the owner's policy.
  quota,

  /// An owner-initiated admin promotion/demotion (migration 0035),
  /// confirmed through the validation quorum before it applies.
  roleChange('role_change');

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

  /// Expenses, self-recorded payments, self-reported service charges and
  /// quota requests are decided by ANOTHER admin (spec §9
  /// no-self-approval, #129; 0031); everything else by the subject
  /// (§8.2).
  bool get needsAdminDecider =>
      type == EventType.expense ||
      type == EventType.quota ||
      type == EventType.roleChange ||
      ((type == EventType.payment || type == EventType.serviceCharge) &&
          actorIsSubject);

  /// Whether the server would accept a decision from [me] right now
  /// (#107, #130 quorum). Mirrors respond_to_event (migration 0017):
  ///  - the subject of an admin-initiated event decides (and must accept);
  ///  - owners always validate; admins per [policy] eligibility;
  ///  - never the actor or subject — except the solo escape hatch (#107):
  ///    when no other eligible validator exists, the actor self-decides;
  ///  - never someone who [alreadyDecided] (one decision per validator).
  bool isDecidedBy(
    Member me, {
    required ValidationPolicy policy,
    required bool hasOtherEligibleValidator,
    bool alreadyDecided = false,
  }) {
    if (!isPending || alreadyDecided) return false;
    if (me.status != MemberStatus.active) return false;
    // (a) subject of an admin-initiated event.
    if (!needsAdminDecider && subjectMemberId == me.id) return true;
    // (b) owners always, (c) admins per policy.
    final eligibleAdmin = me.isAdmin &&
        policy.adminsMayValidate &&
        (policy.eligibleAdminIds.isEmpty ||
            policy.eligibleAdminIds.contains(me.id));
    if (!me.isOwner && !eligibleAdmin) return false;
    // The subject never validates what someone else did to them (their
    // say is rule (a) above, when they have one).
    if (me.id == subjectMemberId && me.id != actorMemberId) return false;
    // No self-approval — unless the pool collapses to the actor (#107).
    if (me.id == actorMemberId) return !hasOtherEligibleValidator;
    return true;
  }

  /// Whether any eligible validator besides the actor/subject exists among
  /// [members] — the pool respond_to_event sizes for the #107 escape hatch.
  bool hasOtherEligibleValidator(
    List<Member> members,
    ValidationPolicy policy,
  ) =>
      members.any(
        (m) =>
            m.status == MemberStatus.active &&
            m.id != actorMemberId &&
            m.id != subjectMemberId &&
            (m.isOwner ||
                (m.isAdmin &&
                    policy.adminsMayValidate &&
                    (policy.eligibleAdminIds.isEmpty ||
                        policy.eligibleAdminIds.contains(m.id)))),
      );

  DateTime? get payloadStart => payload['starts_at'] == null
      ? null
      : DateTime.parse(payload['starts_at'] as String);

  DateTime? get payloadEnd => payload['ends_at'] == null
      ? null
      : DateTime.parse(payload['ends_at'] as String);

  String? get payloadTargetId =>
      (payload['seat_id'] ?? payload['office_id']) as String?;
}
