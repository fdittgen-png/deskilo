// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 - the host side of replay revalidation. A guide step is not a
// permission: before a command step is attempted, Deskilo asks again, now,
// who the person is in which workspace, and whether they may still do it.
// The command itself (the booking review, its price and validation flow)
// still asks its own confirmation; the guide never confirms for anyone.

import 'package:deskilo_task_recording/deskilo_task_recording.dart';

import '../../../core/cache/cache_scope.dart' show cacheDigest;
import '../domain/action_registry.dart';

/// What the authorizer reads, taken fresh on every question.
class GuideReplayFacts {
  const GuideReplayFacts({
    required this.accountDigest,
    required this.workspaceId,
    required this.featureOn,
    required this.activeMember,
    required this.actsForReservations,
  });

  /// The recorder scope's digest (account on this installation).
  final String accountDigest;

  /// The active workspace; null in Me or while loading.
  final String? workspaceId;

  /// The workspace lets its people use the task recorder.
  final bool featureOn;

  /// I am an active member of that workspace.
  final bool activeMember;

  /// I act for reservations as staff (book for others).
  final bool actsForReservations;
}

class DeskiloReplayAuthorizer implements ReplayAuthorizer {
  const DeskiloReplayAuthorizer(this.facts);

  /// The current facts, or null when signed out.
  final GuideReplayFacts? Function() facts;

  @override
  ReplayScope? currentScope() {
    final f = facts();
    if (f == null) return null;
    return ReplayScope(
      cacheDigest('guide-replay-scope-v1', [
        f.accountDigest,
        f.workspaceId ?? '-',
      ], 32),
    );
  }

  @override
  ReplayDecision authorizeNow(ReplayRequest request, ReplayScope scope) {
    final f = facts();
    if (f == null || currentScope() != scope) {
      return const ReplayDecision.refused(ReplayRefusal.scopeChanged);
    }
    if (!f.featureOn) return const ReplayDecision.refused();
    final spec = recorderRegistry.action(request.action);
    if (spec == null || !spec.isCommand) return const ReplayDecision.allowed();
    // In a workspace a command acts as an active member of it; in Me it
    // acts for the person alone.
    if (f.workspaceId != null && !f.activeMember) {
      return const ReplayDecision.refused();
    }
    // A booking recorded "for another member" needs the staff right today,
    // whatever the role was when it was recorded.
    if (request.payload['for_whom'] == 'other_member' &&
        !f.actsForReservations) {
      return const ReplayDecision.refused();
    }
    return const ReplayDecision.allowed();
  }
}
