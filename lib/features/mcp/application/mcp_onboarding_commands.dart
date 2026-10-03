// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the changes a person makes to get assistants working, through
// the 0358–0360 RPCs: a workspace offers assistants (against the value
// read), the operator checks the deployed endpoint, allows desktop and
// command-line assistants, approves access for a bounded time, and reads
// the installation notices. The refusals those RPCs raise are named here
// so the screens can say what to do instead of "try again".
import '../../../core/data/server_error.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/mcp_onboarding.dart';

enum WorkspaceSwitchOutcome { switched, stale }

/// The refusals the console's changes can meet.
enum InstanceRefusal {
  grantNeedsGoogle,
  grantDays,
  grantReason,
  otherAdministrator,
  noIdentity,
  endpointNotConfirmed,
}

InstanceRefusal? instanceRefusalOf(Object error) {
  final m = (serverErrorMessage(error) ?? '').toLowerCase();
  if (m.contains('sign in with google to grant')) {
    return InstanceRefusal.grantNeedsGoogle;
  }
  if (m.contains('lasts 1 to 30 days')) return InstanceRefusal.grantDays;
  if (m.contains('name the reason')) return InstanceRefusal.grantReason;
  if (m.contains('another database administrator decides')) {
    return InstanceRefusal.otherAdministrator;
  }
  if (m.contains('no verified identity binding')) {
    return InstanceRefusal.noIdentity;
  }
  if (m.contains('endpoint_not_deployed')) {
    return InstanceRefusal.endpointNotConfirmed;
  }
  return null;
}

class McpOnboardingCommands {
  const McpOnboardingCommands(
    this._repository, {
    this.probeSettle = const Duration(seconds: 2),
  });

  final McpOnboardingRepository _repository;

  /// pg_net answers the probe asynchronously; the settled one is read
  /// this long after asking.
  final Duration probeSettle;

  /// Turns assistants on for [workspaceId], which was read as off. A
  /// change in between (DK409) is reported, never overwritten.
  Future<WorkspaceSwitchOutcome> offerAssistants(String workspaceId) async {
    try {
      await _repository.setWorkspaceMcpAccess(
        workspaceId,
        enabled: true,
        expected: false,
      );
      return WorkspaceSwitchOutcome.switched;
    } catch (e, st) {
      if (serverErrorCode(e) != 'DK409') rethrow;
      TraceLogger.instance.warn(
        'mcp',
        'mcpAccess changed meanwhile',
        error: e,
        stackTrace: st,
      );
      return WorkspaceSwitchOutcome.stale;
    }
  }

  Future<EndpointProbe> checkServer() async {
    await _repository.probeEndpoint();
    await Future<void>.delayed(probeSettle);
    return _repository.checkEndpoint();
  }

  Future<DateTime?> grant({
    required String subjectId,
    required String reason,
    required int days,
  }) => _repository.grantEligibility(
    subjectId: subjectId,
    reason: reason,
    days: days,
  );

  Future<bool> allowLoopbackClients(bool allowed) =>
      _repository.setLoopbackClients(allowed: allowed);

  Future<int> markNoticesRead() => _repository.markNoticeRead();
}
