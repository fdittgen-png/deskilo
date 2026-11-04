// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — what the personal data admin does: reads the requests addressed to
// the space, records one received elsewhere, extends or closes it, and
// records a privacy incident. The decisions (who may, the deadline, the
// outcome's shape) are the server's (0327, 0666); this is the one door the
// screen uses. It talks to the host that holds the space (#2564), never to
// the root session.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/server_error.dart';
import '../domain/profile_repository.dart';
import '../domain/rights_request.dart';
import '../providers/profile_providers.dart';

// What the personal data admin's screen needs from this feature, through one
// door: the request model and the space it acts on.
export '../domain/rights_request.dart';
export '../providers/profile_providers.dart'
    show PrivacyAdminSpace, privacyAdminSpaceProvider;

/// The words of a failed command: the server's own message when it gave one,
/// else the error's text without its class prefix.
String commandFailureReason(Object error) =>
    serverErrorMessage(error) ??
    error.toString().replaceFirst(RegExp(r'^(Bad state|Exception): '), '');

/// The requests addressed to [workspaceId]'s controller, newest first.
final workspaceRightsRequestsProvider = FutureProvider.autoDispose
    .family<List<RightsRequest>, String>((ref, workspaceId) {
  return ref
      .watch(memberProfileRepositoryProvider)
      .fetchWorkspaceRightsRequests(workspaceId);
});

/// The commands of the privacy admin's screen.
class PrivacyAdminCommands {
  PrivacyAdminCommands(this._repository, this._refresh);

  final ProfileRepository _repository;

  /// Reloads the list once a command changed it.
  final void Function(String workspaceId) _refresh;

  Future<RightsRequest> record({
    required String workspaceId,
    required String memberId,
    required String kind,
    required String details,
    required DateTime receivedAt,
  }) async {
    final request = await _repository.recordRightsRequest(
      workspaceId: workspaceId,
      memberId: memberId,
      kind: kind,
      details: details,
      receivedAt: receivedAt,
    );
    _refresh(workspaceId);
    return request;
  }

  Future<RightsRequest> extend(
    RightsRequest request, {
    required String reason,
  }) async {
    final updated = await _repository.extendRightsRequest(
      requestId: request.id,
      reason: reason,
    );
    _refresh(request.workspaceId ?? '');
    return updated;
  }

  Future<RightsRequest> complete(
    RightsRequest request, {
    required Map<String, Object?> outcome,
  }) async {
    final updated = await _repository.completeRightsRequest(
      requestId: request.id,
      outcome: outcome,
    );
    _refresh(request.workspaceId ?? '');
    return updated;
  }

  Future<RightsRequest> refuse(
    RightsRequest request, {
    required String reason,
  }) async {
    final updated = await _repository.completeRightsRequest(
      requestId: request.id,
      refusalReason: reason,
    );
    _refresh(request.workspaceId ?? '');
    return updated;
  }

  /// Records a privacy incident; returns how many people it told.
  Future<int> recordIncident({
    required String workspaceId,
    required String kind,
    required String note,
  }) => _repository.recordPrivacyIncident(
    workspaceId: workspaceId,
    kind: kind,
    note: note,
  );
}

final privacyAdminCommandsProvider = Provider<PrivacyAdminCommands>((ref) {
  return PrivacyAdminCommands(
    ref.watch(memberProfileRepositoryProvider),
    (workspaceId) => ref.invalidate(workspaceRightsRequestsProvider(workspaceId)),
  );
});
