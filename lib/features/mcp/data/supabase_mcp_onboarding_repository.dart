// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/schema_version.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/mcp_onboarding.dart';

/// #2145 — the 0354 RPCs. The server checks the caller on every call: the
/// consent status only for the person's own pending authorization, the
/// endpoint only for a member of an mcpAccess workspace or the operator,
/// the notices only for their recipient, the endpoint change only for the
/// instance operator at aal2.
class SupabaseMcpOnboardingRepository implements McpOnboardingRepository {
  const SupabaseMcpOnboardingRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<ConsentStatus> consentStatus(String authorizationId) async =>
      ConsentStatus.fromJson(
        await _client.rpc<Object?>(
          'mcp_consent_options',
          params: {'p_authorization_id': authorizationId},
        ),
      );

  @override
  Future<McpEndpointInfo> endpoint() async {
    try {
      return McpEndpointInfo.fromJson(
        await _client.rpc<Object?>('mcp_endpoint'),
      );
    } on PostgrestException catch (e, st) {
      // A server before 0354: the app computes the URL as it always did.
      if (!isMissingFunction(e)) rethrow;
      TraceLogger.instance.warn(
        'mcp',
        'no published endpoint here',
        error: e,
        stackTrace: st,
      );
      return const McpEndpointInfo(source: McpEndpointSource.unknown);
    }
  }

  @override
  Future<InstanceNotices> notices() async {
    try {
      return InstanceNotices.fromJson(
        await _client.rpc<Object?>('my_instance_notices'),
      );
    } on PostgrestException catch (e, st) {
      if (!isMissingFunction(e)) rethrow;
      TraceLogger.instance.warn(
        'mcp',
        'no installation notices here',
        error: e,
        stackTrace: st,
      );
      return InstanceNotices.empty;
    }
  }

  @override
  Future<int> markNoticeRead([String? id]) async {
    final r = await _client.rpc<Object?>(
      'mark_instance_notice_read',
      params: {'p_id': id},
    );
    return r is Map && r['count'] is int ? r['count'] as int : 0;
  }

  @override
  Future<McpEndpointInfo> setEndpoint(String? url) async =>
      McpEndpointInfo.fromJson(
        await _client.rpc<Object?>(
          'instance_set_mcp_endpoint',
          params: {'p_url': url},
        ),
      );

  @override
  Future<bool> setLoopbackClients({required bool allowed}) async {
    final r = await _client.rpc<Object?>(
      'instance_set_mcp_loopback_clients',
      params: {'p_enabled': allowed},
    );
    return r is Map && r['allow_loopback_clients'] == true;
  }

  @override
  Future<EndpointProbe> probeEndpoint() async => EndpointProbe.fromJson(
    await _client.rpc<Object?>('instance_probe_mcp_endpoint'),
  );

  @override
  Future<EndpointProbe> checkEndpoint() async => EndpointProbe.fromJson(
    await _client.rpc<Object?>('instance_mcp_endpoint_check'),
  );

  @override
  Future<DateTime?> grantEligibility({
    required String subjectId,
    required String reason,
    required int days,
  }) async {
    final r = await _client.rpc<Object?>(
      'instance_grant_mcp_eligibility',
      params: {'p_subject': subjectId, 'p_reason': reason, 'p_days': days},
    );
    return r is Map && r['status'] == 'granted'
        ? DateTime.tryParse('${r['expires_at']}')
        : null;
  }

  @override
  Future<bool> setWorkspaceMcpAccess(
    String workspaceId, {
    required bool enabled,
    bool? expected,
  }) async {
    final r = await _client.rpc<Object?>(
      'set_workspace_mcp_access',
      params: {
        'p_workspace_id': workspaceId,
        'p_enabled': enabled,
        'p_expected': expected,
      },
    );
    return r is Map && r['mcp_access'] == true;
  }
}
