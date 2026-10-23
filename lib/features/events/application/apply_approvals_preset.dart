// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The approvals step of the setup guide writes the workspace's default
// validation rule through the same write as the validation rules screen.
// A count the people cannot reach is refused here as well as on the
// step, so no surface that reuses the command can store a rule that
// holds its requests forever.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/approvals_preset.dart';
import '../domain/event_repository.dart';
import '../domain/validation_policy.dart';
import '../providers/event_providers.dart';

part 'apply_approvals_preset.g.dart';

class ApplyApprovalsPreset {
  const ApplyApprovalsPreset(this._events);
  final EventRepository _events;

  /// Stores [preset]'s default rule over [stored]. Throws [ArgumentError]
  /// when [requiredCount] is out of the people's reach, and whatever the
  /// repository throws.
  Future<void> apply(
    String workspaceId,
    ApprovalsPreset preset, {
    required ValidationPolicy? stored,
    required int requiredCount,
  }) {
    if (!preset.reachable(requiredCount)) {
      throw ArgumentError.value(
        requiredCount,
        'requiredCount',
        'more approvals than people who can approve (${preset.people})',
      );
    }
    return _events.upsertValidationPolicy(
      preset.defaultRule(workspaceId, stored, requiredCount),
    );
  }
}

/// The approvals step's write of the default rule.
@riverpod
ApplyApprovalsPreset applyApprovalsPreset(Ref ref) =>
    ApplyApprovalsPreset(ref.watch(eventRepositoryProvider));
