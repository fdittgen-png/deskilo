// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/mcp/domain/mcp_onboarding.dart';

/// #2145 — in-memory onboarding answers for tests and Demo. Demo connects
/// no assistant: no client, no published endpoint, no notices.
class FakeMcpOnboardingRepository implements McpOnboardingRepository {
  FakeMcpOnboardingRepository({
    this.status = const ConsentStatus(eligibility: 'not_requested'),
    this.published = const McpEndpointInfo(source: McpEndpointSource.unknown),
    this.inbox = InstanceNotices.empty,
  });

  ConsentStatus status;
  McpEndpointInfo published;
  InstanceNotices inbox;
  bool loopbackAllowed = false;

  /// The next workspace switch is refused as stale (DK409).
  Object? workspaceSwitchError;
  EndpointProbe probe = EndpointProbe.missing;
  Object? grantError;
  final calls = <String>[];

  @override
  Future<ConsentStatus> consentStatus(String authorizationId) async {
    calls.add('consentStatus:$authorizationId');
    return status;
  }

  @override
  Future<McpEndpointInfo> endpoint() async => published;

  @override
  Future<InstanceNotices> notices() async => inbox;

  @override
  Future<int> markNoticeRead([String? id]) async {
    calls.add('markNoticeRead:${id ?? 'all'}');
    final unread = inbox.notices.where((n) => n.unread).length;
    inbox = InstanceNotices(
      unread: id == null ? 0 : (inbox.unread - 1).clamp(0, 1 << 16),
      notices: inbox.notices,
    );
    return id == null ? unread : 1;
  }

  @override
  Future<McpEndpointInfo> setEndpoint(String? url) async {
    calls.add('setEndpoint:$url');
    published = McpEndpointInfo(
      resource: url,
      source: url == null
          ? McpEndpointSource.derived
          : McpEndpointSource.configured,
    );
    return published;
  }

  @override
  Future<bool> setLoopbackClients({required bool allowed}) async {
    calls.add('setLoopbackClients:$allowed');
    return loopbackAllowed = allowed;
  }

  @override
  Future<EndpointProbe> probeEndpoint() async {
    calls.add('probeEndpoint');
    return const EndpointProbe(state: EndpointProbeState.pending);
  }

  @override
  Future<EndpointProbe> checkEndpoint() async {
    calls.add('checkEndpoint');
    return probe;
  }

  @override
  Future<DateTime?> grantEligibility({
    required String subjectId,
    required String reason,
    required int days,
  }) async {
    calls.add('grantEligibility:$subjectId:$days:$reason');
    if (grantError case final e?) throw e;
    return DateTime.utc(2026, 11, 2);
  }

  @override
  Future<bool> setWorkspaceMcpAccess(
    String workspaceId, {
    required bool enabled,
    bool? expected,
  }) async {
    calls.add('setWorkspaceMcpAccess:$workspaceId:$enabled:$expected');
    if (workspaceSwitchError case final e?) throw e;
    return enabled;
  }
}
