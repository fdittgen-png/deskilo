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
}
