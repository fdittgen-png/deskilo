// SPDX-License-Identifier: MIT
import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_policy.freezed.dart';

/// Owner-configured quorum rule for pending events (#130, ADR 0008).
/// A null [eventType] row is the workspace default; absent rows behave
/// exactly like the pre-quorum protocol (see [ValidationPolicy.defaults]).
@freezed
sealed class ValidationPolicy with _$ValidationPolicy {
  const ValidationPolicy._();

  const factory ValidationPolicy({
    /// Null until persisted (defaults are never stored).
    String? id,
    required String workspaceId,
    /// events.type db value; null = workspace default for types without
    /// their own row.
    String? eventType,
    required int requiredCount,
    required bool adminsMayValidate,
    /// Empty = every admin may validate (owners always may).
    required List<String> eligibleAdminIds,
    required bool ownerRequired,
  }) = _ValidationPolicy;

  /// Pre-quorum behavior for workspaces/types without a stored row:
  /// one decision, all admins eligible, owner not required.
  factory ValidationPolicy.defaults(String workspaceId, String? eventType) =>
      ValidationPolicy(
        workspaceId: workspaceId,
        eventType: eventType,
        requiredCount: 1,
        adminsMayValidate: true,
        eligibleAdminIds: const [],
        ownerRequired: false,
      );
}

/// The policy governing [eventType] (an events.type db value): the exact
/// type row wins, else the workspace-default (null type) row, else the
/// pre-quorum [ValidationPolicy.defaults]. Mirrors respond_to_event's
/// lookup order (migration 0017).
ValidationPolicy policyFor(
  String eventType,
  List<ValidationPolicy> policies,
) {
  for (final policy in policies) {
    if (policy.eventType == eventType) return policy;
  }
  for (final policy in policies) {
    if (policy.eventType == null) return policy;
  }
  return ValidationPolicy.defaults(
    policies.firstOrNull?.workspaceId ?? '',
    eventType,
  );
}
